import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

/// Stream del estado de conexión (bool: true = online).
/// Lee de ConnectivityService que ya está corriendo desde main().
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final service = ConnectivityService.instance;
  // Estado inicial
  yield await service.isConnected();
  // Cambios subsecuentes
  await for (final result in service.onConnectivityChanged) {
    yield result != ConnectivityResult.none;
  }
});

/// Bool sincrono más fácil de consumir (true = online, default true al cargar).
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityStreamProvider).maybeWhen(
        data: (online) => online,
        orElse: () => true,
      );
});
