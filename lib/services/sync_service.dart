import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../core/env.dart';
import 'database_helper.dart';
import 'connectivity_service.dart';
import 'auth_service.dart';
import 'sync_queue_service.dart';
import 'image_upload_service.dart';
import '../repositories/generic_repository.dart';
import '../repositories/cliente_repository.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  final DatabaseHelper _db = DatabaseHelper.instance;
  bool _isSyncing = false;

  final _syncingController = StreamController<bool>.broadcast();
  Stream<bool> get syncingStream => _syncingController.stream;
  bool get isSyncing => _isSyncing;

  SyncService._();

  /// Realiza login online con las credenciales dadas para obtener el JWT token
  Future<bool> authenticateOnline({String? email, String? password}) async {
    return await _authenticateOnline(email: email, password: password);
  }

  /// Realiza login online con las credenciales locales del vendedor para obtener el JWT token
  Future<bool> _authenticateOnline({String? email, String? password}) async {
    try {
      String? username = email;
      String? pass = password;

      if (username == null || pass == null) {
        final userId = AuthService.instance.userId;
        if (userId == null) {
          print('❌ No hay usuario logueado localmente');
          return false;
        }

        final userLocal = await _db.getUsuario(userId);
        if (userLocal == null) {
          print('❌ No se encontró el usuario local en SQLite');
          return false;
        }

        username = userLocal['username'];
        pass = userLocal['password'];
      }

      print('🔑 Intentando login online para $username...');
      final body = {
        'identifier': username,
        'password': pass,
      };

      final response = await GenericRepository.instance.postOnline<Map<String, dynamic>>(
        path: '/auth/login',
        body: body,
        fromJson: (json) => json,
      );

      if (response != null) {
        final token = response['access_token'] ?? response['token'] ?? 
                      (response['data'] is Map ? (response['data']['access_token'] ?? response['data']['token']) : null);
        
        if (token != null) {
          AuthService.instance.onlineToken = token.toString();
          print('✅ Login online exitoso. JWT guardado.');

          // Si el login fue exitoso y las credenciales provistas o usadas difieren de las guardadas en SQLite para el usuario actual,
          // o si el usuario actual es el default, actualicemos localmente en SQLite y en AuthService.
          final userId = AuthService.instance.userId;
          if (userId != null) {
            final userLocal = await _db.getUsuario(userId);
            if (userLocal != null && (userLocal['username'] != username || userLocal['password'] != pass)) {
              final db = await _db.database;
              await db.update(
                'usuarios',
                {
                  'username': username,
                  'password': pass,
                  if (response['user'] != null && response['user']['full_name'] != null)
                    'full_name': response['user']['full_name'],
                },
                where: 'id = ?',
                whereArgs: [userId],
              );
              print('💾 Credenciales locales de SQLite actualizadas con las online exitosas');

              final updatedUser = Map<String, dynamic>.from(userLocal);
              updatedUser['username'] = username;
              updatedUser['password'] = pass;
              if (response['user'] != null && response['user']['full_name'] != null) {
                updatedUser['full_name'] = response['user']['full_name'];
              }
              await AuthService.instance.updateLocalSession(updatedUser);
            }
          }
          return true;
        } else {
          print('❌ Login online exitoso pero no se encontró el campo access_token ni token: $response');
        }
      }
      return false;
    } catch (e) {
      print('❌ Excepción durante _authenticateOnline: $e');
      return false;
    }
  }

  /// Verifica respuestas guardadas y muestra estadísticas
  Future<Map<String, int>> verificarPendientes() async {
    try {
      final pendientes = await _db.getRespuestasPendientes();
      final completadas = pendientes.where((r) => r['sincronizado'] == 1).length;
      final sinEnviar = pendientes.where((r) => r['sincronizado'] == 0).length;

      print('📊 Estado de respuestas:');
      print('   ✅ Completadas: $completadas');
      print('   ⏳ Pendientes: $sinEnviar');

      return {
        'completadas': completadas,
        'pendientes': sinEnviar,
        'total': pendientes.length,
      };
    } catch (e) {
      print('❌ Error verificando pendientes: $e');
      return {'completadas': 0, 'pendientes': 0, 'total': 0};
    }
  }

  /// Descarga los clientes asignados desde el servidor y los guarda localmente
  Future<Map<String, int>> descargarDatosFromServer({String? email, String? password}) async {
    int clientesDescargados = 0;
    int visitasDescargadas = 0;
    int preguntasDescargadas = 0;
    int packsDescargados = 0;
    int errores = 0;

    try {
      final conectado = await ConnectivityService.instance.isConnected();
      if (!conectado) {
        print('📴 Sin conexión para descargar datos');
        return {
          'clientes': 0,
          'visitas': 0,
          'preguntas': 0,
          'packs': 0,
          'errores': 1,
        };
      }

      // Autenticar online
      final autenticado = await _authenticateOnline(email: email, password: password);
      if (!autenticado) {
        print('❌ No se pudo autenticar online');
        return {
          'clientes': 0,
          'visitas': 0,
          'preguntas': 0,
          'packs': 0,
          'errores': 1,
        };
      }

      // 1. Descargar clientes
      print('📥 Descargando clientes asignados desde el servidor...');
      final clientes = await GenericRepository.instance.getListOnline<Map<String, dynamic>>(
        path: '/salesperson/me/customers',
        nestedKey: 'data',
        fromJson: (json) => json,
      );

      if (clientes.isNotEmpty) {
        await _db.guardarClientes(clientes);
        clientesDescargados = clientes.length;
        print('✅ $clientesDescargados clientes guardados localmente');
      }

      // 2. Descargar visitas programadas
      print('📥 Descargando visitas programadas desde el servidor...');
      String? username = email;
      String? pass = password;
      if (username == null || pass == null) {
        final userId = AuthService.instance.userId;
        if (userId != null) {
          final userLocal = await _db.getUsuario(userId);
          if (userLocal != null) {
            username = userLocal['username'];
            pass = userLocal['password'];
          }
        }
      }

      if (username != null && pass != null) {
        // 1.5. Descargar prospectos del vendedor desde el servidor
        print('📥 Descargando prospectos desde el servidor...');
        final prospectosDescargados = await ClienteRepository().sincronizarProspectos(
          email: username,
          password: pass,
        );
        print('✅ $prospectosDescargados prospectos nuevos guardados/actualizados localmente');

        final res = await GenericRepository.instance.executeRequest(
          method: 'POST',
          endpoint: '/salesperson/auth/visits/list',
          payload: {
            'email': username,
            'password': pass,
            'page': 1,
            'limit': 200,
          },
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          final jsonResponse = jsonDecode(res.body);
          if (jsonResponse is Map<String, dynamic> && jsonResponse.containsKey('schedules')) {
            final List<dynamic> schedulesList = jsonResponse['schedules'] as List;
            final List<Map<String, dynamic>> visitas = schedulesList
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();

            if (visitas.isNotEmpty) {
              await _db.guardarVisitas(visitas);
              visitasDescargadas = visitas.length;
              print('✅ $visitasDescargadas visitas guardadas localmente');
            }
          }
        } else {
          print('❌ Error al descargar visitas programadas (Status: ${res.statusCode})');
        }
      } else {
        print('⚠️ No se encontraron credenciales para descargar visitas programadas');
      }

      // 3. Descargar preguntas del formulario de visitas
      print('📥 Descargando preguntas del formulario desde el servidor...');
      final preguntas = await GenericRepository.instance.getListOnline<Map<String, dynamic>>(
        path: '/visit/questions',
        fromJson: (json) => json,
      );

      if (preguntas.isNotEmpty) {
        const plantillaId = 'encuesta_general';
        await _db.guardarPlantillaEncuesta(
          id: plantillaId,
          titulo: 'Encuesta de Visita',
          descripcion: 'Cuestionario general de visitas a clientes',
        );

        final db = await _db.database;
        for (var pregunta in preguntas) {
          final id = pregunta['id']?.toString() ?? '';

          // Evitar duplicados: si ya existe localmente una pregunta con este
          // server_id (p. ej. creada offline por un admin y ya sincronizada),
          // no se vuelve a insertar bajo el id numérico del servidor.
          final yaExiste = await db.query(
            'preguntas',
            where: 'id = ? OR server_id = ?',
            whereArgs: [id, id],
            limit: 1,
          );
          if (yaExiste.isNotEmpty && yaExiste.first['id'] != id) {
            continue;
          }

          final descripcion = pregunta['description']?.toString() ?? '';
          final tipo = pregunta['question_type']?.toString() ?? 'TEXT';
          final esRequerida = (pregunta['is_required'] == true || pregunta['is_required'] == 1) ? 1 : 0;
          
          String? opcionesStr;
          final opts = pregunta['response_options'];
          if (opts != null) {
            if (opts is String) {
              opcionesStr = opts;
            } else {
              opcionesStr = jsonEncode(opts);
            }
          }

          final orden = int.tryParse(pregunta['sort_order']?.toString() ?? '0') ?? 0;

          await _db.guardarPreguntaTemplate(
            id: id,
            encuestaId: plantillaId,
            descripcion: descripcion,
            tipo: tipo,
            esRequerida: esRequerida,
            opciones: opcionesStr,
            orden: orden,
            serverId: id,
            sincronizado: 1,
          );
        }
        preguntasDescargadas = preguntas.length;
        print('✅ $preguntasDescargadas preguntas guardadas localmente');
      }

      // 4. Descargar packs de preguntas
      print('📥 Descargando packs de preguntas desde el servidor...');
      await _descargarPacks();
      packsDescargados = await _contarPacksLocales();

    } catch (e) {
      errores++;
      print('❌ Error en descargarDatosFromServer: $e');
    }

    return {
      'clientes': clientesDescargados,
      'visitas': visitasDescargadas,
      'preguntas': preguntasDescargadas,
      'packs': packsDescargados,
      'errores': errores,
    };
  }

  /// Sube las visitas locales y respuestas al servidor
  Future<Map<String, int>> marcarTodoSincronizado({String? email, String? password}) async {
    int marcadas = 0;
    int errores = 0;

    try {
      final conectado = await ConnectivityService.instance.isConnected();
      if (!conectado) {
        print('📴 Sin conexión para subir datos');
        return {'marcadas': 0, 'errores': 1};
      }

      // Autenticar online
      final autenticado = await _authenticateOnline(email: email, password: password);
      if (!autenticado) {
        print('❌ No se pudo autenticar online');
        return {'marcadas': 0, 'errores': 1};
      }

      final db = await _db.database;

      // Obtener credenciales para el envío a los nuevos endpoints públicos
      String? username = email;
      String? pass = password;

      if (username == null || pass == null) {
        final userId = AuthService.instance.userId;
        if (userId != null) {
          final userLocal = await _db.getUsuario(userId);
          if (userLocal != null) {
            username = userLocal['username'];
            pass = userLocal['password'];
          }
        }
      }

      if (username == null || pass == null) {
        print('❌ No hay credenciales para sincronizar');
        return {'marcadas': 0, 'errores': 1};
      }

      // 0. Subir preguntas creadas offline por el vendedor ANTES de las visitas.
      // Así, cuando la visita se sincronice, las respuestas apunten al server_id
      // real de la pregunta (no al uuid local).
      await _pushPreguntasPendientes(email: username, password: pass);

      // Auto-reparar cualquier visita completada que tenga respuestas pendientes de sincronización
      await db.rawUpdate('''
        UPDATE visitas 
        SET sincronizado = 0 
        WHERE status = 'COMPLETED' 
          AND sincronizado = 1
          AND id IN (SELECT DISTINCT visit_id FROM respuestas_pendientes WHERE sincronizado = 0)
      ''');

      // Obtener visitas completadas localmente y que no estén sincronizadas
      final completedVisits = await db.query(
        'visitas',
        where: "status = 'COMPLETED' AND sincronizado = 0",
      );

      print('📦 Sincronizando ${completedVisits.length} visitas completadas locales...');

      for (var visitRow in completedVisits) {
        final visitId = visitRow['id']?.toString() ?? '';
        
        try {
          // Obtener respuestas asociadas a la visita
          final respuestas = await db.query(
            'respuestas_pendientes',
            where: 'visit_id = ? AND sincronizado = 0',
            whereArgs: [visitId],
          );

          // Antes: si no había respuestas pendientes, la visita se marcaba
          // "sincronizada" localmente SIN nunca crearla en el backend — una
          // visita sin encuesta contestada desaparecía para siempre, nunca
          // llegaba a `visit_records`. Ahora sigue el mismo camino de abajo
          // (crea la visita igual, solo que sin loop de respuestas).
          final Map<String, dynamic>? respuestaRow =
              respuestas.isNotEmpty ? respuestas.first : null;
          final answersList = respuestaRow != null
              ? jsonDecode(respuestaRow['respuestas_json'] as String) as List
              : <dynamic>[];

          // Resolver el customer_id real del servidor y verificar estado de sincronización del cliente
          String rawCustomerId = visitRow['customer_id']?.toString() ?? '';
          String effectiveCustomerId = rawCustomerId;
          bool prospectoPendiente = false;

          final mappedId = await _db.getServerId('prospecto', rawCustomerId) ?? 
                           await _db.getServerId('cliente', rawCustomerId);
          if (mappedId != null && mappedId.isNotEmpty) {
            effectiveCustomerId = mappedId;
          } else {
            final clienteRows = await db.rawQuery(
              'SELECT id, server_id, code_client_profit, sincronizado FROM clientes WHERE id = ? OR server_id = ? OR code_client_profit = ?',
              [rawCustomerId, rawCustomerId, rawCustomerId],
            );
            if (clienteRows.isNotEmpty) {
              final c = clienteRows.first;
              final syncVal = (c['sincronizado'] as int?) ?? 1;
              if (c['server_id'] != null && c['server_id'].toString().isNotEmpty) {
                effectiveCustomerId = c['server_id'].toString();
              } else if (c['code_client_profit'] != null && c['code_client_profit'].toString().isNotEmpty) {
                effectiveCustomerId = c['code_client_profit'].toString();
              }

              // Si fue creado localmente y aún no tiene server_id ni sincronizado == 1
              if (syncVal == 0 && (c['server_id'] == null || c['server_id'].toString().isEmpty) && (c['code_client_profit'] == null || c['code_client_profit'].toString().isEmpty)) {
                prospectoPendiente = true;
              }
            }
          }

          if (prospectoPendiente) {
            print('⏳ [SyncService] El prospecto local $rawCustomerId aún no se ha subido a la API. Posponiendo envío de visita.');
            continue;
          }

          // 1. Crear el registro de visita en el backend
          final rawScheduleId = int.tryParse(visitId) ?? (double.tryParse(visitId)?.toInt());
          final isAdHocVisit = visitId.toString().startsWith('visita_') || (rawScheduleId != null && rawScheduleId > 2000000);
          // Una visita ad-hoc ("Nueva Visita") ya no vive solo local: se
          // auto-agenda en el servidor al crearse (ver nueva_visita_page.dart
          // → SyncQueueService entityType 'visit_schedule'). Si ese POST ya
          // se resolvió, hay un id_mapping local→server que hay que usar
          // como schedule real para poder completarlo igual que uno agendado
          // por un admin.
          final mappedScheduleId = isAdHocVisit
              ? await _db.getServerId('visit_schedule', visitId)
              : null;
          final realScheduleId = isAdHocVisit
              ? (mappedScheduleId != null ? int.tryParse(mappedScheduleId) : null)
              : rawScheduleId;

          final visitDate = visitRow['visit_date_from']?.toString() ??
                            (respuestaRow?['fecha_creacion']?.toString().substring(0, 10)) ??
                            DateTime.now().toIso8601String().substring(0, 10);

          // Las fotos se suben aparte a /images/upload-base64 y se referencian
          // por id en photo_1_id/photo_2_id (columnas dedicadas en visit_records).
          final foto1Path = respuestaRow?['foto1_path']?.toString();
          final foto2Path = respuestaRow?['foto2_path']?.toString();
          int? photo1Id;
          int? photo2Id;
          if (foto1Path != null && foto1Path.isNotEmpty) {
            photo1Id = await ImageUploadService.instance.subirFoto(
              localPath: foto1Path,
              ownerType: 'visit',
              ownerId: visitId,
            );
          }
          if (foto2Path != null && foto2Path.isNotEmpty) {
            photo2Id = await ImageUploadService.instance.subirFoto(
              localPath: foto2Path,
              ownerType: 'visit',
              ownerId: visitId,
            );
          }

          final visitBody = <String, dynamic>{
            'email': username,
            'password': pass,
            'customer_id': effectiveCustomerId,
            if (realScheduleId != null) 'visit_schedule_id': realScheduleId,
            'visit_date': visitDate,
            'latitude': respuestaRow?['lat'] ?? 0.0,
            'longitude': respuestaRow?['lng'] ?? 0.0,
            'description': (visitRow['notes'] != null && visitRow['notes'].toString().trim().isNotEmpty)
                ? visitRow['notes'].toString().trim()
                : 'Visita realizada',
            'extra_data': {},
            if (photo1Id != null) 'photo_1_id': photo1Id,
            if (photo2Id != null) 'photo_2_id': photo2Id,
            // Estable entre reintentos (mismo visitId local siempre) — el
            // backend usa esto para no duplicar la visita si este POST se
            // reintenta tras un timeout de red.
            'client_dedup_key': 'app_visit_$visitId',
          };

          print('🔍 Sincronizando visita - ID local: $visitId, parsed scheduleId: $realScheduleId');
          print('📤 Creando visita en backend para cliente ${visitRow['customer_name']}...');
          final visitResponse = await GenericRepository.instance.postOnline<Map<String, dynamic>>(
            path: '/salesperson/auth/visits',
            body: visitBody,
            fromJson: (json) => json,
          );

          if (visitResponse == null) {
            throw Exception('El servidor rechazó la creación de la visita');
          }

          final backendVisitId = visitResponse['id'] ?? (visitResponse['data'] is Map ? visitResponse['data']['id'] : null);
          if (backendVisitId == null) {
            throw Exception('No se recibió un ID de visita válido desde el servidor: $visitResponse');
          }

          final parsedVisitId = int.tryParse(backendVisitId.toString()) ?? 
                                (double.tryParse(backendVisitId.toString())?.toInt()) ?? 
                                backendVisitId;

          // 2. Enviar las respuestas de la encuesta una a una
          for (var item in answersList) {
            final qId = int.tryParse(item['question_id']?.toString() ?? '') ?? 0;
            final answerText = item['answer_text']?.toString() ?? '';
            final answerOption = item['answer_option']?.toString() ?? '';
            final notes = visitRow['notes']?.toString() ?? '';

            final answerBody = <String, dynamic>{
              'email': username,
              'password': pass,
              'visit_id': parsedVisitId,
              'question_id': qId,
              'answer_text': answerText,
              'answer_option': answerOption,
              'notes': notes,
            };

            print('📤 Registrando respuesta para pregunta $qId (Visita $parsedVisitId)...');
            final answerResponse = await GenericRepository.instance.postOnline<Map<String, dynamic>>(
              path: '/salesperson/auth/answers',
              body: answerBody,
              fromJson: (json) => json,
            );

            if (answerResponse == null) {
              throw Exception('El servidor rechazó registrar la respuesta para la pregunta $qId');
            }
          }

          // 3. Completar visita programada en backend si correspondía a un schedule real
          if (realScheduleId != null) {
            try {
              print('📤 Completando visita programada $realScheduleId en backend via POST...');
              final completeBody = <String, dynamic>{
                'email': username,
                'password': pass,
                'status': 'COMPLETED',
                'notes': visitRow['notes'] ?? '',
                'visit_record_id': parsedVisitId,
              };

              await GenericRepository.instance.postOnline<Map<String, dynamic>>(
                path: '/salesperson/auth/schedules/$realScheduleId/complete',
                body: completeBody,
                fromJson: (json) => json,
              );
            } catch (e) {
              print('⚠️ Notificación de agenda programada $realScheduleId no requerida o ya completada: $e');
            }
          }

          // Marcar localmente como sincronizado
          if (respuestaRow != null) {
            await _db.marcarRespuestaSincronizada(respuestaRow['id'] as int);
          }
          await _db.marcarVisitaSincronizada(visitId);
          marcadas++;
          print('✅ Sincronización unificada exitosa para la visita $visitId');
        } catch (e) {
          errores++;
          print('❌ Error sincronizando visita $visitId: $e');
        }
      }

      // Preservar respuestas en SQLite para consulta en Detalle de Visita
      if (marcadas > 0) {
        // await _db.eliminarRespuestasSincronizadas();
        await _db.limpiarDatosAntiguos();
      }

      // Limpiar token
      AuthService.instance.onlineToken = null;
    } catch (e) {
      print('❌ Error en marcarTodoSincronizado: $e');
      errores++;
    }

    return {'marcadas': marcadas, 'errores': errores};
  }

  /// Obtiene todas las respuestas para revisión (admin)
  Future<List<Map<String, dynamic>>> getTodasLasRespuestas() async {
    try {
      final db = await _db.database;
      return await db.query('respuestas_pendientes', orderBy: 'fecha_creacion DESC');
    } catch (e) {
      return [];
    }
  }

  /// Obtiene respuestas de una visita específica
  Future<List<Map<String, dynamic>>> getRespuestasDeVisita(String visitId) async {
    try {
      final db = await _db.database;
      return await db.query(
        'respuestas_pendientes',
        where: 'visit_id = ?',
        whereArgs: [visitId],
        orderBy: 'fecha_creacion DESC',
      );
    } catch (e) {
      return [];
    }
  }

  /// Limpia todas las respuestas (peligroso, solo admin)
  Future<bool> limpiarTodo() async {
    try {
      final db = await _db.database;
      await db.delete('respuestas_pendientes');
      print('🗑️ Todas las respuestas eliminadas');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sube al backend las preguntas creadas offline por el vendedor.
  /// Cada una se envía a `/salesperson/auth/questions`, endpoint idempotente
  /// por `code` (retorna id existente si ya estaba). Al recibir server_id,
  /// se guarda localmente y se marca sincronizada, y se remapean las respuestas
  /// pendientes que apuntaban al uuid local.
  Future<void> _pushPreguntasPendientes({
    required String email,
    required String password,
  }) async {
    try {
      final pendientes = await _db.getPreguntasPendientesPush();
      if (pendientes.isEmpty) return;
      print('📤 ${pendientes.length} preguntas locales pendientes de push');

      final db = await _db.database;

      for (final p in pendientes) {
        final localId = p['id']?.toString() ?? '';
        final descripcion = p['descripcion']?.toString() ?? '';
        final tipo = p['tipo']?.toString() ?? 'TEXT';
        final esRequerida = (p['es_requerida'] == 1);
        final opcionesRaw = p['opciones']?.toString();
        final orden = (p['orden'] as int?) ?? 100;

        // Sanear tipo: RATING queda restringido al admin
        final tipoNorm = (tipo == 'RATING') ? 'TEXT' : tipo;

        // Derivar un code determinístico a partir del uuid local para
        // idempotencia. Truncado + upper para respetar 50 chars max backend.
        final code = 'V_${localId.replaceAll('-', '').substring(0, 20).toUpperCase()}';

        List<String>? opciones;
        if (opcionesRaw != null && opcionesRaw.isNotEmpty) {
          try {
            final decoded = jsonDecode(opcionesRaw);
            if (decoded is List) {
              opciones = decoded.map((e) => e.toString()).toList();
            }
          } catch (_) {}
        }

        final body = <String, dynamic>{
          'email': email,
          'password': password,
          'code': code,
          'description': descripcion,
          'question_type': tipoNorm,
          'is_required': esRequerida,
          if (opciones != null && opciones.isNotEmpty) 'response_options': opciones,
          'sort_order': orden,
        };

        try {
          final resp = await GenericRepository.instance
              .postOnline<Map<String, dynamic>>(
            path: '/salesperson/auth/questions',
            body: body,
            fromJson: (json) => json,
          );
          final serverId = resp?['id']?.toString();
          if (serverId == null) {
            print('⚠️ Respuesta sin id para pregunta local $localId: $resp');
            continue;
          }

          await _db.marcarPreguntaSincronizada(localId, serverId);

          // Remapear respuestas ya guardadas que aún referencien el uuid local.
          await db.rawUpdate(
            '''UPDATE respuestas_pendientes
               SET respuestas_json = REPLACE(respuestas_json, ?, ?)
               WHERE respuestas_json LIKE ?''',
            [
              '"question_id":"$localId"',
              '"question_id":"$serverId"',
              '%"question_id":"$localId"%',
            ],
          );

          print(
            '✅ Pregunta local $localId → server $serverId (reused=${resp?['reused']})',
          );
        } catch (e) {
          print('❌ Error subiendo pregunta local $localId: $e');
        }
      }
    } catch (e) {
      print('❌ Error en _pushPreguntasPendientes: $e');
    }
  }

  /// Obtiene estadísticas generales
  Future<Map<String, dynamic>> getEstadisticas() async {
    try {
      final db = await _db.database;

      final totalVisitas = await db.rawQuery('SELECT COUNT(*) as total FROM visitas');
      final visitasPendientes = await db.rawQuery("SELECT COUNT(*) as total FROM visitas WHERE status = 'PENDING'");
      final visitasCompletadas = await db.rawQuery("SELECT COUNT(*) as total FROM visitas WHERE status = 'COMPLETED'");
      final totalRespuestas = await db.rawQuery('SELECT COUNT(*) as total FROM respuestas_pendientes');
      final totalClientes = await db.rawQuery('SELECT COUNT(*) as total FROM clientes');

      return {
        'visitas_total': totalVisitas.first['total'] ?? 0,
        'visitas_pendientes': visitasPendientes.first['total'] ?? 0,
        'visitas_completadas': visitasCompletadas.first['total'] ?? 0,
        'respuestas_total': totalRespuestas.first['total'] ?? 0,
        'clientes_total': totalClientes.first['total'] ?? 0,
      };
    } catch (e) {
      return {};
    }
  }

  /// Ejecuta una sincronización completa en segundo plano de forma automática.
  /// Sube datos pendientes de la cola, envía visitas completadas, y descarga los últimos clientes/visitas.
  Future<void> ejecutarSincronizacionCompleta() async {
    if (_isSyncing) {
      print('⏳ [SyncService] Sincronización completa ya en progreso, ignorando llamada.');
      return;
    }
    _isSyncing = true;
    _syncingController.add(true);
    try {
      final conectado = await ConnectivityService.instance.isConnected();
      if (!conectado) {
        print('📴 [SyncService] Cancelando sync automática: sin conexión a internet.');
        return;
      }

      print('🔄 [SyncService] Iniciando sincronización completa automática...');

      // Autenticar online primero para obtener JWT token antes de procesar la cola
      print('🔑 [SyncService] Autenticando en línea...');
      final autenticado = await _authenticateOnline();
      if (!autenticado) {
        print('⚠️ [SyncService] No se pudo obtener token JWT, continuando sin él...');
      }

      // 1. Subir operaciones en cola (prospectos, respuestas, etc.)
      print('📤 [SyncService] Subiendo operaciones pendientes en la cola...');
      await SyncQueueService.instance.drain(force: true);

      // 2. Subir visitas completadas y respuestas no encoladas
      print('📤 [SyncService] Subiendo visitas completadas...');
      await marcarTodoSincronizado();

      // 3. Descargar datos actualizados (clientes, visitas, preguntas)
      // Re-autentica de nuevo (no reusa `autenticado` de arriba): el JWT del
      // backend puede tener TTL corto, y para cuando se llega acá ya se
      // drenó la cola completa + subieron visitas — el token del inicio del
      // ciclo puede haber vencido, causando 401 en /survey/packs y compañía
      // (visto en producción: los packs dejaban de aparecer).
      print('📥 [SyncService] Descargando datos desde el servidor...');
      await descargarDatosFromServer();

      print('✅ [SyncService] Sincronización completa automática finalizada con éxito.');
    } catch (e) {
      print('❌ [SyncService] Error en la sincronización completa automática: $e');
    } finally {
      _isSyncing = false;
      _syncingController.add(false);
    }
  }

  /// Realiza un HEAD rápido al backend para comprobar conectividad real.
  /// Usa un timeout generoso (10s) porque cada llamada de `http.head()` abre
  /// una conexión nueva (sin reutilizar keep-alive), y el handshake TLS en
  /// redes móviles puede tardar más que los 4s originales, generando falsos
  /// negativos aun cuando el servidor sí responde (visto en logs reales
  /// donde llamadas POST exitosas precedían a un HEAD reportado como fallido).
  /// Se reintenta una vez antes de declarar el servidor inalcanzable.
  Future<bool> verificarConexionServidor() async {
    for (var intento = 0; intento < 2; intento++) {
      try {
        final url = Uri.parse(Env.apiBaseUrl);
        await http.head(url).timeout(const Duration(seconds: 10));
        return true;
      } catch (e) {
        print('⚠️ [SyncService] verificarConexionServidor intento ${intento + 1} falló: $e');
      }
    }
    return false;
  }

  /// Intenta subir datos pendientes (cola + visitas) de forma periódica, incluso
  /// si connectivity reporta offline (doble chequeo contra el servidor).
  Future<void> intentarSubirDatos() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncingController.add(true);
    try {
      bool online = await ConnectivityService.instance.isConnected();
      if (!online) {
        print('🔍 [SyncService] Sin conexión local reportada. Verificando servidor...');
        online = await verificarConexionServidor();
      }

      if (!online) {
        print('📴 [SyncService] Servidor inalcanzable. Cancelando intento de subida.');
        return;
      }

      print('🔄 [SyncService] Iniciando intento periódico de subida de datos...');

      // Autenticar online primero para obtener JWT token antes de procesar la cola
      print('🔑 [SyncService] Autenticando en línea...');
      final autenticado = await _authenticateOnline();
      if (!autenticado) {
        print('⚠️ [SyncService] No se pudo obtener token JWT, continuando sin él...');
      }

      // Drenar la cola forzando la ejecución
      await SyncQueueService.instance.drain(force: true);

      // Subir visitas completadas
      await marcarTodoSincronizado();

      // Descargar visitas programadas nuevas: este método corre cada 2 min
      // en background (Timer.periodic en sync_queue_service.dart) y era el
      // único ciclo automático que NO bajaba schedules nuevas — si el
      // vendedor tenía la app abierta sin perder conexión, una visita
      // programada por un admin nunca le llegaba hasta cerrar/abrir la app
      // o perder y recuperar señal.
      print('📥 [SyncService] Descargando visitas programadas nuevas...');
      await descargarDatosFromServer();

      print('✅ [SyncService] Intento periódico de subida finalizado.');
    } catch (e) {
      print('❌ [SyncService] Error en intento periódico de subida: $e');
    } finally {
      _isSyncing = false;
      _syncingController.add(false);
    }
  }

  /// Descargar packs de preguntas disponibles
  Future<void> _descargarPacks() async {
    try {
      final packs = await GenericRepository.instance.getListOnline<Map<String, dynamic>>(
        path: '/survey/packs',
        nestedKey: 'data',
        fromJson: (json) => json,
      );

      if (packs.isEmpty) {
        print('⚠️ No se encontraron packs de preguntas');
        return;
      }

      final db = await _db.database;
      for (final pack in packs) {
        final packId = pack['id']?.toString() ?? '';
        final packName = pack['name']?.toString() ?? '';
        final packType = pack['pack_type']?.toString() ?? '';
        final description = pack['description']?.toString() ?? '';
        final isActive = (pack['is_active'] == true || pack['is_active'] == 1) ? 1 : 0;
        final createdAt = pack['created_at']?.toString() ?? DateTime.now().toIso8601String();
        final updatedAt = pack['updated_at']?.toString() ?? DateTime.now().toIso8601String();

        // Guardar pack
        await db.insert(
          'survey_packs',
          {
            'id': packId,
            'name': packName,
            'pack_type': packType,
            'description': description,
            'is_active': isActive,
            'created_at': createdAt,
            'updated_at': updatedAt,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Guardar preguntas del pack si existen
        final questionIds = pack['question_ids'] ?? pack['questions'] ?? [];
        if (questionIds is List) {
          for (int i = 0; i < questionIds.length; i++) {
            final qId = questionIds[i];
            final questionId = int.tryParse(qId.toString());
            if (questionId != null) {
              await db.insert(
                'survey_pack_questions',
                {
                  'pack_id': packId,
                  'question_id': questionId,
                  'sort_order': i,
                  'is_required': 1,
                },
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }
          }
        }
      }

      print('✅ ${packs.length} packs de preguntas guardados localmente');
    } catch (e) {
      print('❌ Error descargando packs: $e');
    }
  }

  /// Contar packs locales
  Future<int> _contarPacksLocales() async {
    try {
      final db = await _db.database;
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM survey_packs WHERE is_active = 1'),
      ) ?? 0;
      return count;
    } catch (e) {
      return 0;
    }
  }

  /// Inicia el servicio (sin auto-sync de red)
  static void iniciar() {
    print('📦 SyncService local iniciado');
    instance.verificarPendientes();
  }
}