import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../providers/sync_provider.dart';
import '../atoms/offline_banner.dart';

/// Envuelve una página mostrando el [OfflineBanner] reactivo al estado de red
/// y de la cola de sync. También dispara snackbars al cambiar conectividad.
class ConnectionWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const ConnectionWrapper({super.key, required this.child});

  @override
  ConsumerState<ConnectionWrapper> createState() => _ConnectionWrapperState();
}

class _ConnectionWrapperState extends ConsumerState<ConnectionWrapper> {
  bool? _lastOnline;

  void _showSnack(BuildContext context, {required bool online}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(online ? Icons.wifi : Icons.wifi_off,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(online
                ? '🌐 Conexión recuperada'
                : '📴 Se perdió la conexión a internet'),
          ],
        ),
        backgroundColor: online ? Colors.green : Colors.orange,
        duration: Duration(seconds: online ? 2 : 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _goOffline(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📴 Modo offline activado. Trabajando con datos locales.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isOnlineProvider, (prev, next) {
      if (_lastOnline == null) {
        _lastOnline = next;
        return;
      }
      if (next != _lastOnline) {
        _showSnack(context, online: next);
        _lastOnline = next;
      }
    });

    final isOnline = ref.watch(isOnlineProvider);
    final sync = ref.watch(syncStateProvider);
    final showBanner = !isOnline || !sync.isClean;

    return Column(
      children: [
        if (showBanner)
          OfflineBanner(
            onGoOffline: () => _goOffline(context),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
