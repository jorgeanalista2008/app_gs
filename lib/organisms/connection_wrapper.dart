import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../providers/sync_provider.dart';
import '../atoms/offline_banner.dart';
import '../core/app_colors.dart';
import '../services/conflict_resolver.dart';

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

  void _showFailedOperationsBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final failedOpsAsync = ref.watch(failedOperationsProvider);
            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Operaciones Fallidas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Las siguientes operaciones fallaron permanentemente en el servidor. Puedes revisar el error e intentar subirlas de nuevo.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: failedOpsAsync.when(
                      data: (ops) {
                        if (ops.isEmpty) {
                          return const Center(
                            child: Text('No hay operaciones fallidas'),
                          );
                        }
                        return ListView.builder(
                          itemCount: ops.length,
                          itemBuilder: (context, index) {
                            final op = ops[index];
                            final id = op['id'] as int;
                            final entityType = op['entity_type'] ?? '';
                            final operation = op['operation'] ?? '';
                            final lastError = op['last_error'] ?? '';
                            final payloadJson = op['payload_json'] ?? '{}';
                            
                            String entityName = 'Operación';
                            try {
                              final payload = jsonDecode(payloadJson);
                              if (payload is Map && payload.containsKey('name')) {
                                entityName = payload['name']?.toString() ?? 'Operación';
                              }
                            } catch (_) {}

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${entityType.toString().toUpperCase()} - ${operation.toString().toUpperCase()}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppColors.primaryColor,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.refresh, color: Colors.green),
                                          onPressed: () async {
                                            await ref
                                                .read(syncStateProvider.notifier)
                                                .retryFailed(id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Reintentando operación...'),
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    Text(
                                      entityName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Error: $lastError',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (err, stack) => Center(
                        child: Text('Error: $err'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showConflictsBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final conflictsAsync = ref.watch(unreviewedConflictsProvider);
            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Conflictos de Sincronización',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Se detectaron discrepancias entre los datos locales y del servidor. Se resolvió automáticamente usando la fecha de última modificación.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: conflictsAsync.when(
                      data: (list) {
                        if (list.isEmpty) {
                          return const Center(
                            child: Text('No hay conflictos sin revisar'),
                          );
                        }
                        return ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final c = list[index];
                            final id = c['id'] as int;
                            final entityType = c['entity_type'] ?? '';
                            final resolution = c['resolution'] ?? '';
                            final resolvedAt = c['resolved_at'] ?? '';
                            
                            String desc = resolution == 'local_wins'
                                ? 'Se conservaron los datos locales por ser más recientes.'
                                : 'Se aplicaron los datos del servidor por ser más recientes.';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${entityType.toString().toUpperCase()} - Resolución: $resolution',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: resolution == 'local_wins'
                                                ? Colors.blue
                                                : Colors.green,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.check, color: Colors.green),
                                          onPressed: () async {
                                            await ConflictResolver.instance
                                                .markReviewed(id);
                                            ref.invalidate(syncStateProvider);
                                          },
                                        ),
                                      ],
                                    ),
                                    Text(
                                      desc,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Fecha: $resolvedAt',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (err, stack) => Center(
                        child: Text('Error: $err'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
            onShowPending: () => _showFailedOperationsBottomSheet(context, ref),
            onShowConflicts: () => _showConflictsBottomSheet(context, ref),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
