import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/sync/connection_monitor_service.dart';
import '../../data/services/sync/sync_service.dart';
import '../../data/services/sync/sync_orchestrator_service.dart';

/// UI state for background monitoring widget
enum MonitoringUiState {
  inProgress,
  waiting,
  offline,
}

/// Composite state exposed by MonitoringStatusViewModel
class MonitoringState {
  final MonitoringUiState ui;
  final bool hasCompletedFirstSync;

  const MonitoringState({
    required this.ui,
    required this.hasCompletedFirstSync,
  });

  MonitoringState copyWith({
    MonitoringUiState? ui,
    bool? hasCompletedFirstSync,
  }) => MonitoringState(
        ui: ui ?? this.ui,
        hasCompletedFirstSync: hasCompletedFirstSync ?? this.hasCompletedFirstSync,
      );
}

class MonitoringStatusViewModel extends StateNotifier<MonitoringState> {
  final ConnectionMonitorService _connectionMonitorService;
  final SyncService _syncService;
  final CalDAVMonitor _caldavMonitor;

  StreamSubscription<ConnectionStatus>? _connSub;
  StreamSubscription<SyncStatus>? _syncSub;
  StreamSubscription<bool>? _monitoringSub;

  MonitoringStatusViewModel({
    required ConnectionMonitorService connectionMonitorService,
    required SyncService syncService,
    required CalDAVMonitor caldavMonitor,
  })  : _connectionMonitorService = connectionMonitorService,
        _syncService = syncService,
        _caldavMonitor = caldavMonitor,
        super(MonitoringState(
          ui: MonitoringUiState.waiting,
          hasCompletedFirstSync: syncService.lastSyncTime != null,
        )) {
    // Initialize current state
    _recompute();

    // Listen to changes
    _connSub = _connectionMonitorService.statusStream.listen((_) => _recompute());
    _syncSub = _syncService.statusStream.listen((_) => _recompute());
    _monitoringSub = _caldavMonitor.monitoringActivityStream.listen((_) => _recompute());
  }

  void _recompute() {
    final hasFirst = _syncService.lastSyncTime != null;

    // 1) If no internet => offline
    final conn = _connectionMonitorService.currentStatus;
    if (conn == ConnectionStatus.disconnected) {
      state = state.copyWith(ui: MonitoringUiState.offline, hasCompletedFirstSync: hasFirst);
      return;
    }

    // 2) If syncing / monitoring => in progress
    final syncStatus = _syncService.status;
    if (syncStatus == SyncStatus.syncing || _caldavMonitor.isPerformingMonitoring) {
      state = state.copyWith(ui: MonitoringUiState.inProgress, hasCompletedFirstSync: hasFirst);
      return;
    }

    // Fallback: if connection unknown but not explicitly disconnected, show waiting
    state = state.copyWith(ui: MonitoringUiState.waiting, hasCompletedFirstSync: hasFirst);
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _syncSub?.cancel();
    _monitoringSub?.cancel();
    super.dispose();
  }
}
