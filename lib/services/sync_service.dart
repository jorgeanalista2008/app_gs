import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/env.dart';
import 'database_helper.dart';
import 'connectivity_service.dart';
import 'auth_service.dart';
import 'sync_queue_service.dart';
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
    int errores = 0;

    try {
      final conectado = await ConnectivityService.instance.isConnected();
      if (!conectado) {
        print('📴 Sin conexión para descargar datos');
        return {
          'clientes': 0,
          'visitas': 0,
          'preguntas': 0,
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

        for (var pregunta in preguntas) {
          final id = pregunta['id']?.toString() ?? '';
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
          );
        }
        preguntasDescargadas = preguntas.length;
        print('✅ $preguntasDescargadas preguntas guardadas localmente');
      }
    } catch (e) {
      errores++;
      print('❌ Error en descargarDatosFromServer: $e');
    }

    return {
      'clientes': clientesDescargados,
      'visitas': visitasDescargadas,
      'preguntas': preguntasDescargadas,
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

          if (respuestas.isEmpty) {
            // Si la visita está completada pero no hay respuestas, simplemente la marcamos como sincronizada
            await _db.marcarVisitaSincronizada(visitId);
            marcadas++;
            continue;
          }

          final respuestaRow = respuestas.first;
          final answersList = jsonDecode(respuestaRow['respuestas_json'] as String) as List;

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
          final realScheduleId = isAdHocVisit ? null : rawScheduleId;

          final visitDate = visitRow['visit_date_from']?.toString() ?? 
                            (respuestaRow['fecha_creacion']?.toString().substring(0, 10)) ?? 
                            DateTime.now().toIso8601String().substring(0, 10);

          final visitBody = <String, dynamic>{
            'email': username,
            'password': pass,
            'customer_id': effectiveCustomerId,
            if (realScheduleId != null) 'visit_schedule_id': realScheduleId,
            'visit_date': visitDate,
            'latitude': respuestaRow['lat'] ?? 0.0,
            'longitude': respuestaRow['lng'] ?? 0.0,
            'description': (visitRow['notes'] != null && visitRow['notes'].toString().trim().isNotEmpty)
                ? visitRow['notes'].toString().trim()
                : 'Visita realizada',
            'extra_data': {},
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
          await _db.marcarRespuestaSincronizada(respuestaRow['id'] as int);
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

      // 1. Subir operaciones en cola (prospectos, respuestas, etc.)
      print('📤 [SyncService] Subiendo operaciones pendientes en la cola...');
      await SyncQueueService.instance.drain(force: true);

      // 2. Subir visitas completadas y respuestas no encoladas
      print('📤 [SyncService] Subiendo visitas completadas...');
      await marcarTodoSincronizado();

      // 3. Descargar datos actualizados (clientes, visitas, preguntas)
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

  /// Realiza un HEAD rápido al backend para comprobar conectividad real
  Future<bool> verificarConexionServidor() async {
    try {
      final url = Uri.parse(Env.apiBaseUrl);
      await http.head(url).timeout(const Duration(seconds: 4));
      return true;
    } catch (_) {
      return false;
    }
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
      
      // Drenar la cola forzando la ejecución
      await SyncQueueService.instance.drain(force: true);

      // Subir visitas completadas
      await marcarTodoSincronizado();

      print('✅ [SyncService] Intento periódico de subida finalizado.');
    } catch (e) {
      print('❌ [SyncService] Error en intento periódico de subida: $e');
    } finally {
      _isSyncing = false;
      _syncingController.add(false);
    }
  }

  /// Inicia el servicio (sin auto-sync de red)
  static void iniciar() {
    print('📦 SyncService local iniciado');
    instance.verificarPendientes();
  }
}