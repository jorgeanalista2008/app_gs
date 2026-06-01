import 'dart:convert';
import 'database_helper.dart';
import 'connectivity_service.dart';
import 'auth_service.dart';
import '../repositories/generic_repository.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  final DatabaseHelper _db = DatabaseHelper.instance;

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
          
          String? opcionesCSV;
          final opts = pregunta['response_options'];
          if (opts != null) {
            try {
              if (opts is String && opts.isNotEmpty) {
                final parsed = jsonDecode(opts);
                if (parsed is List) {
                  opcionesCSV = parsed.join(', ');
                } else {
                  opcionesCSV = opts;
                }
              } else if (opts is List) {
                opcionesCSV = opts.join(', ');
              }
            } catch (_) {
              opcionesCSV = opts.toString();
            }
          }

          final orden = int.tryParse(pregunta['sort_order']?.toString() ?? '0') ?? 0;

          await _db.guardarPreguntaTemplate(
            id: id,
            encuestaId: plantillaId,
            descripcion: descripcion,
            tipo: tipo,
            esRequerida: esRequerida,
            opciones: opcionesCSV,
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

          // 1. Crear la visita en el backend
          final visitBody = {
            'customer_id': int.tryParse(visitRow['customer_id']?.toString() ?? '') ?? visitRow['customer_id'],
            'notes': visitRow['notes'] ?? '',
            'priority': visitRow['priority'] ?? 3,
            'visit_date_from': visitRow['visit_date_from'],
            'visit_date_to': visitRow['visit_date_to'],
            'latitude': respuestaRow['lat'],
            'longitude': respuestaRow['lng'],
            'photo_1': respuestaRow['foto1_path'],
            'photo_2': respuestaRow['foto2_path'],
          };

          print('📤 Creando visita en backend para cliente ${visitRow['customer_name']}...');
          final visitResponse = await GenericRepository.instance.postOnline<Map<String, dynamic>>(
            path: '/salesperson/me/visits',
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

          print('✅ Visita creada en backend con ID: $backendVisitId. Subiendo respuestas una a una...');

          // 2. Subir respuestas individualmente
          bool todasRespuestasSincronizadas = true;
          for (var answerItem in answersList) {
            final answerBody = {
              'visit_id': int.tryParse(backendVisitId.toString()) ?? backendVisitId,
              'question_id': int.tryParse(answerItem['question_id']?.toString() ?? '') ?? answerItem['question_id'],
              if (answerItem.containsKey('answer_option')) 'answer_option': answerItem['answer_option'],
              if (answerItem.containsKey('answer_text')) 'answer_text': answerItem['answer_text'],
            };

            print('📤 Subiendo respuesta para pregunta ${answerItem['question_id']}...');
            final answerResponse = await GenericRepository.instance.postOnline<Map<String, dynamic>>(
              path: '/salesperson/me/answers',
              body: answerBody,
              fromJson: (json) => json,
            );

            if (answerResponse == null) {
              todasRespuestasSincronizadas = false;
              print('❌ Error al subir respuesta: $answerBody');
            }
          }

          if (todasRespuestasSincronizadas) {
            // Marcar localmente como sincronizado
            await _db.marcarRespuestaSincronizada(respuestaRow['id'] as int);
            await _db.marcarVisitaSincronizada(visitId);
            marcadas++;
            print('✅ Sincronización exitosa para la visita $visitId');
          } else {
            errores++;
            print('⚠️ Algunas respuestas no se pudieron sincronizar para la visita $visitId');
          }
        } catch (e) {
          errores++;
          print('❌ Error sincronizando visita $visitId: $e');
        }
      }

      // Limpiar sincronizadas de SQLite
      if (marcadas > 0) {
        await _db.eliminarRespuestasSincronizadas();
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

  /// Inicia el servicio (sin auto-sync de red)
  static void iniciar() {
    print('📦 SyncService local iniciado');
    instance.verificarPendientes();
  }
}