import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../providers/sync_provider.dart';

/// Banner que combina estado de conexión + estado de cola de sync.
/// - Sin red: naranja "sin conexión" + cantidad pendiente.
/// - Con red + pendientes: azul "sincronizando" con botón manual.
/// - Con red + fallos permanentes o conflictos: rojo con badge para revisar.
/// - Con red + cola limpia: oculto.
class OfflineBanner extends ConsumerWidget {
  final VoidCallback? onGoOffline;
  final VoidCallback? onShowPending;
  final VoidCallback? onShowConflicts;

  const OfflineBanner({
    super.key,
    this.onGoOffline,
    this.onShowPending,
    this.onShowConflicts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final sync = ref.watch(syncStateProvider);

    // Offline
    if (!isOnline) {
      return _Banner(
        color: Colors.orange.shade700,
        icon: Icons.wifi_off,
        text: sync.hasPending
            ? 'Sin conexión — ${sync.pendingCount} pendientes'
            : 'Sin conexión a internet',
        trailing: onGoOffline != null
            ? _SmallButton(label: 'Modo offline', onTap: onGoOffline!)
            : null,
      );
    }

    // Online con conflictos o fallos
    if (sync.hasFailed || sync.hasConflicts) {
      final parts = <String>[];
      if (sync.hasFailed) parts.add('${sync.failedCount} fallidos');
      if (sync.hasConflicts) parts.add('${sync.conflictsUnreviewed} conflictos');
      return _Banner(
        color: Colors.red.shade700,
        icon: Icons.error_outline,
        text: parts.join(' · '),
        trailing: _SmallButton(
          label: 'Revisar',
          onTap: () =>
              (sync.hasConflicts ? onShowConflicts : onShowPending)?.call(),
        ),
      );
    }

    // Online drenando
    if (sync.isDraining) {
      return _Banner(
        color: Colors.blue.shade700,
        icon: Icons.sync,
        text: 'Sincronizando ${sync.pendingCount} operaciones…',
      );
    }

    // Online con pendientes en cola
    if (sync.hasPending) {
      return _Banner(
        color: Colors.blue.shade600,
        icon: Icons.cloud_upload_outlined,
        text: '${sync.pendingCount} pendientes de subir',
        trailing: _SmallButton(
          label: 'Sincronizar',
          onTap: () => ref.read(syncStateProvider.notifier).drainNow(),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final Widget? trailing;

  const _Banner({
    required this.color,
    required this.icon,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: color,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SmallButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        backgroundColor: Colors.white.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
