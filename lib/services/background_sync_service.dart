import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'auth_service.dart';
import 'sync_queue_service.dart';
import 'sync_service.dart';

/// Nombre único de la tarea periódica registrada en el sistema operativo.
const String _kSyncTaskUniqueName = 'solsumed-background-sync';
const String _kSyncTaskName = 'solsumed-sync-task';

/// Punto de entrada ejecutado por el SO en un isolate en segundo plano,
/// incluso con la app cerrada. Debe ser una función top-level (o estática)
/// marcada con @pragma('vm:entry-point') para que el motor Flutter headless
/// pueda invocarla.
@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    print('🌙 [BackgroundSync] tarea "$task" iniciada (app en 2do plano/cerrada)');
    try {
      // El isolate es nuevo: hay que rehidratar la sesión desde SharedPreferences/SQLite.
      final sesionActiva = await AuthService.instance.tryAutoLogin();
      if (!sesionActiva) {
        print('🌙 [BackgroundSync] sin sesión guardada, se omite sincronización');
        return Future.value(true);
      }

      await SyncQueueService.instance.drain(force: true);
      await SyncService.instance.marcarTodoSincronizado();
      print('🌙 [BackgroundSync] sincronización en 2do plano completada');
      return Future.value(true);
    } catch (e) {
      print('❌ [BackgroundSync] error: $e');
      return Future.value(false);
    }
  });
}

/// Registra la sincronización periódica en segundo plano usando el
/// WorkManager nativo (Android) / BGTaskScheduler (iOS), condicionada a que
/// haya red disponible. Esto permite subir lo hecho offline aun con la app
/// cerrada, a diferencia de [SyncQueueService.start] que sólo reacciona
/// mientras el proceso de Flutter sigue vivo.
///
/// Limitación del SO: el intervalo mínimo que Android/iOS permiten para
/// tareas periódicas es ~15 minutos, y puede demorarse más por Doze/ahorro
/// de batería. No es un disparo instantáneo como el listener en primer plano.
class BackgroundSyncService {
  static bool get _soportado =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> initialize() async {
    if (!_soportado) return;
    try {
      await Workmanager().initialize(backgroundSyncCallbackDispatcher);
      await Workmanager().registerPeriodicTask(
        _kSyncTaskUniqueName,
        _kSyncTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 1),
      );
      print('🌙 [BackgroundSync] tarea periódica registrada');
    } catch (e) {
      print('❌ [BackgroundSync] no se pudo registrar la tarea: $e');
    }
  }
}
