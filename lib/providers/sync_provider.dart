import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_queue_service.dart';
import '../services/sync_service.dart';
import '../services/conflict_resolver.dart';
import 'connectivity_provider.dart';

class SyncState {
  final int pendingCount;
  final int failedCount;
  final int conflictsUnreviewed;
  final bool isDraining;
  final DateTime? lastDrainAt;

  const SyncState({
    this.pendingCount = 0,
    this.failedCount = 0,
    this.conflictsUnreviewed = 0,
    this.isDraining = false,
    this.lastDrainAt,
  });

  SyncState copyWith({
    int? pendingCount,
    int? failedCount,
    int? conflictsUnreviewed,
    bool? isDraining,
    DateTime? lastDrainAt,
  }) =>
      SyncState(
        pendingCount: pendingCount ?? this.pendingCount,
        failedCount: failedCount ?? this.failedCount,
        conflictsUnreviewed: conflictsUnreviewed ?? this.conflictsUnreviewed,
        isDraining: isDraining ?? this.isDraining,
        lastDrainAt: lastDrainAt ?? this.lastDrainAt,
      );

  bool get hasPending => pendingCount > 0;
  bool get hasFailed => failedCount > 0;
  bool get hasConflicts => conflictsUnreviewed > 0;
  bool get isClean => !hasPending && !hasFailed && !hasConflicts;
}

class SyncStateNotifier extends StateNotifier<SyncState> {
  SyncStateNotifier(this._ref) : super(const SyncState()) {
    _init();
  }

  final Ref _ref;
  StreamSubscription<int>? _pendingSub;
  StreamSubscription<bool>? _queueSyncSub;
  StreamSubscription<bool>? _serviceSyncSub;
  Timer? _refreshTimer;

  void _init() {
    refresh();
    // Stream emite cada vez que enqueue/drain cambian cantidad.
    _pendingSub = SyncQueueService.instance.pendingCountStream.listen((count) {
      state = state.copyWith(pendingCount: count);
      _refreshFailedAndConflicts();
    });

    // Escuchar el estado de drenaje de la cola
    _queueSyncSub = SyncQueueService.instance.syncingStream.listen((_) {
      _updateDrainingState();
    });

    // Escuchar el estado de sincronización completa
    _serviceSyncSub = SyncService.instance.syncingStream.listen((_) {
      _updateDrainingState();
    });

    // Refresh periódico para capturar cambios de otros caminos.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refresh(),
    );
  }

  void _updateDrainingState() {
    final active = SyncQueueService.instance.isDraining || SyncService.instance.isSyncing;
    state = state.copyWith(isDraining: active);
  }

  Future<void> refresh() async {
    final pending = await SyncQueueService.instance.countPending();
    final failed = (await SyncQueueService.instance.getFailedPermanent()).length;
    final conflicts = await ConflictResolver.instance.countUnreviewed();
    state = state.copyWith(
      pendingCount: pending,
      failedCount: failed,
      conflictsUnreviewed: conflicts,
    );
  }

  Future<void> _refreshFailedAndConflicts() async {
    final failed = (await SyncQueueService.instance.getFailedPermanent()).length;
    final conflicts = await ConflictResolver.instance.countUnreviewed();
    state = state.copyWith(
      failedCount: failed,
      conflictsUnreviewed: conflicts,
    );
  }

  /// Dispara drain manual desde UI (botón "sincronizar ahora").
  Future<void> drainNow() async {
    state = state.copyWith(isDraining: true);
    try {
      await SyncQueueService.instance.drain();
    } finally {
      state = state.copyWith(
        isDraining: false,
        lastDrainAt: DateTime.now(),
      );
      await refresh();
    }
  }

  /// Reintenta una operación fallida permanente.
  Future<void> retryFailed(int operationId) async {
    await SyncQueueService.instance.retryFailed(operationId);
    await refresh();
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    _queueSyncSub?.cancel();
    _serviceSyncSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}

final syncStateProvider =
    StateNotifierProvider<SyncStateNotifier, SyncState>((ref) {
  return SyncStateNotifier(ref);
});

/// Lista de operaciones fallidas permanentes (para UI de revisión).
final failedOperationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // Re-evalúa cuando syncStateProvider cambia.
  ref.watch(syncStateProvider);
  return SyncQueueService.instance.getFailedPermanent();
});

/// Lista de conflictos no revisados (para UI admin).
final unreviewedConflictsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(syncStateProvider);
  return ConflictResolver.instance.getConflicts(reviewed: false);
});
