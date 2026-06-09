import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../providers/sync_provider.dart';

/// Chip compacto para AppBar/Drawer con estado de sync.
/// Tap → fuerza drain manual.
class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final sync = ref.watch(syncStateProvider);

    final ({IconData icon, Color bg, String label}) cfg = _config(isOnline, sync);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          sync.isDraining
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(cfg.icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            cfg.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  ({IconData icon, Color bg, String label}) _config(bool isOnline, SyncState s) {
    if (!isOnline) {
      return (
        icon: Icons.wifi_off,
        bg: Colors.orange.shade700,
        label: s.hasPending ? 'Offline · ${s.pendingCount}' : 'Offline',
      );
    }
    if (s.hasFailed || s.hasConflicts) {
      return (
        icon: Icons.error_outline,
        bg: Colors.red.shade700,
        label: s.hasConflicts ? '${s.conflictsUnreviewed} conflicto(s)' : '${s.failedCount} fallido(s)',
      );
    }
    if (s.isDraining) {
      return (
        icon: Icons.sync,
        bg: Colors.blue.shade700,
        label: 'Sync…',
      );
    }
    if (s.hasPending) {
      return (
        icon: Icons.cloud_upload_outlined,
        bg: Colors.blue.shade600,
        label: '${s.pendingCount} por subir',
      );
    }
    return (
      icon: Icons.cloud_done_outlined,
      bg: Colors.green.shade600,
      label: 'Sync ok',
    );
  }
}
