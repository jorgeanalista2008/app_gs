import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/env.dart';
import '../models/cliente_model.dart';
import '../services/database_helper.dart';
import '../services/sync_queue_service.dart';
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
    } catch (e) {
      print('❌ [Cliente] error procesando éxito push: $e');
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
    final payload = <String, dynamic>{
      'name': name,
      if (taxId.isNotEmpty) 'tax_id': taxId,
      if (telefono.isNotEmpty) 'phone': telefono,
      if (email.isNotEmpty) 'contact_email': email,
      if (direccion.isNotEmpty) 'address': direccion,
      if (notes.isNotEmpty) 'notes': notes,
      if (lat != null) 'latitude': lat,
      if (lng != null) 'longitude': lng,
      if (salespersonId != null) 'salesperson_id': salespersonId,
      'source': 'OTRO',
      if (salespersonEmail != null) 'email': salespersonEmail,
      if (salespersonPassword != null) 'password': salespersonPassword,
      if (contactName != null && contactName.isNotEmpty) 'contact_name': contactName,
      if (city != null && city.isNotEmpty) 'city': city,
      if (zoneCode != null && zoneCode.isNotEmpty) 'zone_code': zoneCode,
      if (nextFollowupDate != null && nextFollowupDate.isNotEmpty) 'next_followup_date': nextFollowupDate,
      if (photo1 != null && photo1.isNotEmpty) 'photo_1': photo1,
      if (photo2 != null && photo2.isNotEmpty) 'photo_2': photo2,
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

      print('🌐 Obteniendo clientes desde API...');
      print('📧 Email: $email');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
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
            'sincronizado': 1,
            'fecha_sync': DateTime.now().toIso8601String(),
          });
          guardados++;
        } else {
          final localRow = existente.first;
          final localId = localRow['id'] as String;
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
}