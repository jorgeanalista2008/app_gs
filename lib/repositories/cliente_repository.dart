import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/env.dart';
import '../models/cliente_model.dart';
import '../services/database_helper.dart';
import '../services/sync_queue_service.dart';
import '../services/image_upload_service.dart';
import 'generic_repository.dart';

class ClienteRepository {
  final GenericRepository _repo = GenericRepository.instance;
  final DatabaseHelper _db = DatabaseHelper.instance;
  static const _uuid = Uuid();
  static const String entityType = 'customer';

  /// Registra handler en cola para mapear server_id tras éxito.
  /// Llamar UNA VEZ en main.dart al arrancar.
  static void registerSyncHandlers() {
    SyncQueueService.instance.registerSuccessHandler(
      entityType,
      _onCustomerPushSuccess,
    );
  }

  static Future<void> _onCustomerPushSuccess(
    Map<String, dynamic> operation,
    String responseBody,
  ) async {
    final localId = operation['entity_local_id']?.toString();
    if (localId == null) return;
    try {
      final decoded = jsonDecode(responseBody);
      String? serverId;
      DateTime? updatedAt;
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;
        serverId = data['id']?.toString();
        final ua = data['updated_at']?.toString() ?? data['created_at']?.toString();
        if (ua != null) {
          try {
            updatedAt = DateTime.parse(ua);
          } catch (_) {}
        }
      }
      if (serverId == null) {
        print('⚠️ [Cliente] respuesta sin id servidor para $localId');
        return;
      }
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'clientes',
        {
          'server_id': serverId,
          'sincronizado': 1,
          'fecha_sync': DateTime.now().toIso8601String(),
          'server_updated_at':
              (updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [localId],
      );
      await DatabaseHelper.instance.registrarIdMapping(
        entityType: entityType,
        localId: localId,
        serverId: serverId,
      );
      print('🔗 [Cliente] mapeado $localId → $serverId');

      // El DTO de creación de prospecto no acepta fotos; se suben aparte
      // ahora que ya existe un id de servidor para asociarlas, y luego se
      // vinculan explícitamente vía POST /salesperson/auth/prospects/:id/update
      // (photo_1_id/photo_2_id) para que queden con FK real en dbo.prospects.
      final localRow = await db.query('clientes', where: 'id = ?', whereArgs: [localId], limit: 1);
      if (localRow.isNotEmpty) {
        final photo1 = localRow.first['photo_1']?.toString();
        final photo2 = localRow.first['photo_2']?.toString();
        int? photo1Id;
        int? photo2Id;
        if (photo1 != null && photo1.isNotEmpty) {
          photo1Id = await ImageUploadService.instance.subirFoto(
            localPath: photo1,
            ownerType: 'customer',
            ownerId: serverId,
          );
        }
        if (photo2 != null && photo2.isNotEmpty) {
          photo2Id = await ImageUploadService.instance.subirFoto(
            localPath: photo2,
            ownerType: 'customer',
            ownerId: serverId,
          );
        }
        if (photo1Id != null || photo2Id != null) {
          await _linkProspectPhotos(
            operation: operation,
            serverId: serverId,
            photo1Id: photo1Id,
            photo2Id: photo2Id,
          );
        }
      }
    } catch (e) {
      print('❌ [Cliente] error procesando éxito push: $e');
    }
  }

  /// Asocia photo_1_id/photo_2_id al prospecto ya creado en el backend,
  /// reutilizando las credenciales (email/password) del payload original
  /// que se envió al crearlo.
  static Future<void> _linkProspectPhotos({
    required Map<String, dynamic> operation,
    required String serverId,
    int? photo1Id,
    int? photo2Id,
  }) async {
    try {
      final payloadJson = operation['payload_json'] as String?;
      if (payloadJson == null) return;
      final originalPayload = jsonDecode(payloadJson) as Map<String, dynamic>;
      final email = originalPayload['email'];
      final password = originalPayload['password'];
      if (email == null || password == null) return;

      await GenericRepository.instance.postOnline<Map<String, dynamic>>(
        path: '/salesperson/auth/prospects/$serverId/update',
        body: {
          'email': email,
          'password': password,
          if (photo1Id != null) 'photo_1_id': photo1Id,
          if (photo2Id != null) 'photo_2_id': photo2Id,
        },
        fromJson: (json) => json,
      );
      print('🔗 [Cliente] fotos vinculadas al prospecto $serverId (photo_1_id=$photo1Id, photo_2_id=$photo2Id)');
    } catch (e) {
      print('❌ [Cliente] error vinculando fotos de prospecto $serverId: $e');
    }
  }

  /// Obtiene clientes locales desde SQLite
  Future<List<ClienteModel>> getClientesLocales() async {
    return _repo.getListLocal<ClienteModel>(
      table: 'clientes',
      orderBy: 'name ASC',
      fromJson: (json) => ClienteModel.fromJson(json),
    );
  }

  /// Lista solo prospectos (clientes creados offline aún no oficializados).
  Future<List<ClienteModel>> getProspectos() async {
    return _repo.getListLocal<ClienteModel>(
      table: 'clientes',
      where: 'is_prospect = 1',
      orderBy: 'updated_at DESC',
      fromJson: (json) => ClienteModel.fromJson(json),
    );
  }

  /// Crea prospecto offline: insert local + enqueue POST /customer.
  /// Devuelve el [ClienteModel] insertado con UUID local generado.
  Future<ClienteModel> crearProspecto({
    required String name,
    String taxId = '',
    String telefono = '',
    String email = '',
    String direccion = '',
    String notes = '',
    double? lat,
    double? lng,
    String? contactName,
    String? city,
    String? zoneCode,
    String? nextFollowupDate,
    String? photo1,
    String? photo2,
  }) async {
    final localId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final db = await _db.database;

    final row = {
      'id': localId,
      'name': name,
      'code_client_profit': '',
      'tax_id': taxId,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
      'activo': 1,
      'tipo': '',
      'sincronizado': 0,
      'is_prospect': 1,
      'notes': notes,
      'lat': lat,
      'lng': lng,
      'updated_at': nowIso,
      'fecha_sync': null,
      'contact_name': contactName,
      'city': city,
      'zone_code': zoneCode,
      'next_followup_date': nextFollowupDate,
      'photo_1': photo1,
      'photo_2': photo2,
    };
    await db.insert('clientes', row,
        conflictAlgorithm: ConflictAlgorithm.replace);

    final salespersonId = await GenericRepository.instance.getUserId();
    String? salespersonEmail;
    String? salespersonPassword;
    if (salespersonId != null) {
      final userLocal = await _db.getUsuario(salespersonId);
      if (userLocal != null) {
        salespersonEmail = userLocal['username'];
        salespersonPassword = userLocal['password'];
      }
    }

    // Payload para POST /salesperson/auth/prospects (CredsCreateProspectDto).
    // salesperson_id lo deriva el backend de email/password; no se envía.
    // Las fotos se suben aparte (ver _onCustomerPushSuccess) porque el DTO
    // no tiene campos photo_1/photo_2.
    final payload = <String, dynamic>{
      'name': name,
      if (taxId.isNotEmpty) 'tax_id': taxId,
      if (telefono.isNotEmpty) 'phone': telefono,
      if (email.isNotEmpty) 'contact_email': email,
      if (direccion.isNotEmpty) 'address': direccion,
      if (notes.isNotEmpty) 'notes': notes,
      if (lat != null) 'latitude': lat,
      if (lng != null) 'longitude': lng,
      'source': 'OTRO',
      if (salespersonEmail != null) 'email': salespersonEmail,
      if (salespersonPassword != null) 'password': salespersonPassword,
      if (contactName != null && contactName.isNotEmpty) 'contact_name': contactName,
      if (city != null && city.isNotEmpty) 'city': city,
      if (zoneCode != null && zoneCode.isNotEmpty) 'zone_code': zoneCode,
      if (nextFollowupDate != null && nextFollowupDate.isNotEmpty) 'next_followup_date': nextFollowupDate,
    };

    await SyncQueueService.instance.enqueue(
      entityType: entityType,
      entityLocalId: localId,
      operation: 'create',
      httpMethod: 'POST',
      endpoint: '/salesperson/auth/prospects',
      payload: payload,
    );

    print('🆕 [Cliente] prospecto creado offline: $localId');

    return ClienteModel(
      id: localId,
      name: name,
      taxId: taxId,
      telefono: telefono,
      email: email,
      direccion: direccion,
      notes: notes,
      isProspect: true,
      sincronizado: false,
      contactName: contactName,
      city: city,
      zoneCode: zoneCode,
      nextFollowupDate: nextFollowupDate,
      photo1: photo1,
      photo2: photo2,
    );
  }

  /// Cantidad de prospectos aún no oficializados.
  Future<int> contarProspectosPendientes() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM clientes WHERE is_prospect = 1 AND server_id IS NULL',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Obtiene clientes desde la API con email/password
  Future<List<ClienteModel>> fetchClientesFromApi({
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('${Env.apiBaseUrl}/salesperson/auth/customers');

      final payload = {'email': email, 'password': password};
      print('📡 === DETALLE DE ENVÍO HTTP (DEBUG) ===');
      print('🔄 Método: POST');
      print('🌐 URL: $url');
      print('🔑 Headers: {"Content-Type": "application/json"}');
      try {
        const encoder = JsonEncoder.withIndent('  ');
        final prettyJson = encoder.convert(payload);
        print('📦 Payload (JSON):\n$prettyJson');
      } catch (_) {
        print('📦 Payload (raw): $payload');
      }
      print('========================================');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      print('📊 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final clientes = data.map((json) => ClienteModel.fromJson(json)).toList();
        print('✅ ${clientes.length} clientes obtenidos de API');
        return clientes;
      }
      return [];
    } catch (e) {
      print('❌ Error obteniendo clientes: $e');
      return [];
    }
  }

  /// Descarga clientes de API y los guarda en SQLite (solo insert)
  Future<int> sincronizarClientes({
    required String email,
    required String password,
  }) async {
    try {
      final clientes = await fetchClientesFromApi(email: email, password: password);
      if (clientes.isEmpty) return 0;

      final db = await _db.database;
      int guardados = 0;

      for (var cliente in clientes) {
        List<Map<String, dynamic>> existente = await db.query(
          'clientes',
          where: 'id = ? OR server_id = ?',
          whereArgs: [cliente.id, cliente.id],
          limit: 1,
        );

        if (existente.isEmpty && cliente.taxId.isNotEmpty) {
          existente = await db.query(
            'clientes',
            where: 'tax_id = ? AND is_prospect = 1',
            whereArgs: [cliente.taxId],
            limit: 1,
          );
        }

        if (existente.isEmpty) {
          await db.insert('clientes', {
            'id': cliente.id,
            'name': cliente.name,
            'code_client_profit': cliente.codeClientProfit,
            'tax_id': cliente.taxId,
            'telefono': cliente.telefono,
            'email': cliente.email,
            'direccion': cliente.direccion,
            'activo': cliente.activo ? 1 : 0,
            'tipo': cliente.tipo,
            'lat': cliente.lat,
            'lng': cliente.lng,
            'sincronizado': 1,
            'fecha_sync': DateTime.now().toIso8601String(),
          });
          guardados++;
        } else {
          final localRow = existente.first;
          final localId = localRow['id'] as String;
          // Preservar lat/lng local si el vendedor las ajustó manualmente.
          // Solo actualizar cuando backend trae valor y local está vacío.
          final localLat = localRow['lat'];
          final localLng = localRow['lng'];
          await db.update(
            'clientes',
            {
              'server_id': cliente.id,
              'name': cliente.name,
              'code_client_profit': cliente.codeClientProfit,
              'tax_id': cliente.taxId,
              'telefono': cliente.telefono,
              'email': cliente.email,
              'direccion': cliente.direccion,
              'activo': cliente.activo ? 1 : 0,
              'tipo': cliente.tipo,
              if (localLat == null && cliente.lat != null) 'lat': cliente.lat,
              if (localLng == null && cliente.lng != null) 'lng': cliente.lng,
              'sincronizado': 1,
              'is_prospect': 0, // Ya se oficializó en el backend
              'fecha_sync': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [localId],
          );
        }
      }

      print('✅ Sincronización de clientes completada ($guardados nuevos)');
      return guardados;
    } catch (e) {
      print('❌ Error sincronizando clientes: $e');
      return 0;
    }
  }

  /// Obtiene prospectos desde la API con email/password
  Future<List<ClienteModel>> fetchProspectosFromApi({
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('${Env.apiBaseUrl}/salesperson/auth/prospects/list');

      final payload = {
        'email': email,
        'password': password,
        'page': 1,
        'limit': 200,
      };
      print('📡 === DETALLE DE ENVÍO HTTP (DEBUG) ===');
      print('🔄 Método: POST');
      print('🌐 URL: $url');
      print('🔑 Headers: {"Content-Type": "application/json"}');
      try {
        const encoder = JsonEncoder.withIndent('  ');
        final prettyJson = encoder.convert(payload);
        print('📦 Payload (JSON):\n$prettyJson');
      } catch (_) {
        print('📦 Payload (raw): $payload');
      }
      print('========================================');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      print('📊 Status prospectos: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded['data'] ?? [];
        final prospectos = data.map((json) => ClienteModel.fromJson(json)).toList();
        print('✅ ${prospectos.length} prospectos obtenidos de API');
        return prospectos;
      }
      return [];
    } catch (e) {
      print('❌ Error obteniendo prospectos: $e');
      return [];
    }
  }

  /// Descarga prospectos de la API y los guarda en SQLite
  Future<int> sincronizarProspectos({
    required String email,
    required String password,
  }) async {
    try {
      final prospectos = await fetchProspectosFromApi(email: email, password: password);
      if (prospectos.isEmpty) return 0;

      final db = await _db.database;
      int guardados = 0;

      for (var prospecto in prospectos) {
        // Buscar si ya existe localmente por id (o server_id si ya se subió)
        List<Map<String, dynamic>> existente = await db.query(
          'clientes',
          where: 'id = ? OR server_id = ?',
          whereArgs: [prospecto.id, prospecto.id],
          limit: 1,
        );

        if (existente.isEmpty && prospecto.taxId.isNotEmpty) {
          existente = await db.query(
            'clientes',
            where: 'tax_id = ? AND is_prospect = 1',
            whereArgs: [prospecto.taxId],
            limit: 1,
          );
        }

        if (existente.isNotEmpty) {
          final localSynced = (existente.first['sincronizado'] as int?) ?? 1;
          if (localSynced == 0) {
            // Conservar versión local pendiente de envío
            continue;
          }
        }

        final row = {
          'name': prospecto.name,
          'tax_id': prospecto.taxId,
          'telefono': prospecto.telefono,
          'email': prospecto.email,
          'direccion': prospecto.direccion,
          'notes': prospecto.notes,
          'contact_name': prospecto.contactName,
          'city': prospecto.city,
          'zone_code': prospecto.zoneCode,
          'next_followup_date': prospecto.nextFollowupDate,
          'sincronizado': 1, // Ya está en el servidor
          'is_prospect': 1,
          'fecha_sync': DateTime.now().toIso8601String(),
        };

        if (existente.isEmpty) {
          // Es un prospecto nuevo del servidor, lo insertamos usando el id del servidor
          row['id'] = prospecto.id;
          row['server_id'] = prospecto.id;
          await db.insert('clientes', row);
          guardados++;
        } else {
          // Existe localmente, actualizamos
          final localId = existente.first['id'] as String;
          row['server_id'] = prospecto.id;
          await db.update(
            'clientes',
            row,
            where: 'id = ?',
            whereArgs: [localId],
          );
          guardados++;
        }
      }

      print('✅ Sincronización de prospectos completada ($guardados guardados/actualizados)');
      return guardados;
    } catch (e) {
      print('❌ Error sincronizando prospectos: $e');
      return 0;
    }
  }
}