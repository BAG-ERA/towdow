// Navbar Sync ViewModel for managing global sync state in navbar widgets
// Handles background sync status, account connection, and sync controls

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/caldav_account.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/services/sync_service.dart';
import '../../core/logger.dart';

// Navbar Sync State
class NavbarSyncState {
  final bool isConnected;
  final bool isBackgroundSyncRunning;
  final bool isBackgroundSyncing;
  final bool isFullSyncing;
  final SyncStatus syncStatus;
  final String? error;
  final CaldavAccount? account;
  final DateTime? lastSyncTime;
  final int syncedCalendarsCount;

  const NavbarSyncState({
    this.isConnected = false,
    this.isBackgroundSyncRunning = false,
    this.isBackgroundSyncing = false,
    this.isFullSyncing = false,
    this.syncStatus = SyncStatus.idle,
    this.error,
    this.account,
    this.lastSyncTime,
    this.syncedCalendarsCount = 0,
  });

  NavbarSyncState copyWith({
    bool? isConnected,
    bool? isBackgroundSyncRunning,
    bool? isBackgroundSyncing,
    bool? isFullSyncing,
    SyncStatus? syncStatus,
    String? error,
    CaldavAccount? account,
    DateTime? lastSyncTime,
    int? syncedCalendarsCount,
  }) {
    return NavbarSyncState(
      isConnected: isConnected ?? this.isConnected,
      isBackgroundSyncRunning: isBackgroundSyncRunning ?? this.isBackgroundSyncRunning,
      isBackgroundSyncing: isBackgroundSyncing ?? this.isBackgroundSyncing,
      isFullSyncing: isFullSyncing ?? this.isFullSyncing,
      syncStatus: syncStatus ?? this.syncStatus,
      error: error,
      account: account ?? this.account,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      syncedCalendarsCount: syncedCalendarsCount ?? this.syncedCalendarsCount,
    );
  }

  /// Check if any sync is currently active
  bool get isSyncing => isBackgroundSyncing || isFullSyncing || syncStatus == SyncStatus.syncing;

  /// Get sync status indicator color
  SyncIndicatorStatus get indicatorStatus {
    if (!isConnected) return SyncIndicatorStatus.offline;
    if (error != null) return SyncIndicatorStatus.error;
    if (isSyncing) return SyncIndicatorStatus.syncing;
    return SyncIndicatorStatus.idle;
  }

  /// Get display text for sync status
  String get statusText {
    if (!isConnected) return 'Offline';
    if (error != null) return 'Sync Error';
    if (isBackgroundSyncing) return 'Syncing...';
    if (isFullSyncing) return 'Full Sync...';
    if (syncStatus == SyncStatus.syncing) return 'Syncing...';
    if (lastSyncTime != null) {
      final diff = DateTime.now().difference(lastSyncTime!);
      if (diff.inMinutes < 1) return 'Just synced';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }
    return 'Ready';
  }
}

enum SyncIndicatorStatus {
  idle,
  syncing,
  error,
  offline,
}

// Navbar Sync ViewModel
class NavbarSyncViewModel extends StateNotifier<NavbarSyncState> {
  final AccountRepository _accountRepository;
  final SyncService _syncService;

  NavbarSyncViewModel(
    this._accountRepository,
    this._syncService,
  ) : super(const NavbarSyncState());

  /// Initialize the view model and start monitoring sync state
  Future<void> initialize() async {
    // AppLogger.info('NavbarSyncViewModel: Initializing');
    
    try {
      // Load account status
      await _updateAccountStatus();
      
      // Start monitoring sync status
      _monitorSyncStatus();
      
      // AppLogger.info('NavbarSyncViewModel: Initialized successfully');
    } catch (e, stackTrace) {
      AppLogger.error('NavbarSyncViewModel: Failed to initialize', e, stackTrace);
      state = state.copyWith(error: 'Failed to initialize: $e');
    }
  }

  /// Update account connection status
  Future<void> _updateAccountStatus() async {
    try {
      final accountResult = await _accountRepository.getActiveAccount();
      await accountResult.when(
        success: (account) async {
          state = state.copyWith(
            account: account,
            isConnected: account != null,
          );
        },
        failure: (failure) async {
          AppLogger.error('NavbarSyncViewModel: Failed to get account', failure.exception, failure.stackTrace);
          state = state.copyWith(
            isConnected: false,
            error: 'Account error: ${failure.message}',
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('NavbarSyncViewModel: Exception getting account', e, stackTrace);
      state = state.copyWith(
        isConnected: false,
        error: 'Failed to get account: $e',
      );
    }
  }

  /// Monitor sync service status
  void _monitorSyncStatus() {
    // Monitor sync status stream
    _syncService.statusStream.listen((status) {
      state = state.copyWith(
        syncStatus: status,
        isFullSyncing: status == SyncStatus.syncing,
      );
    });

    // Periodically update sync state
    _updateSyncState();
  }

  /// Update current sync state from services
  void _updateSyncState() {
    try {
      state = state.copyWith(
        isBackgroundSyncRunning: _syncService.isBackgroundSyncRunning,
        isBackgroundSyncing: _syncService.isBackgroundSyncing,
        lastSyncTime: _syncService.lastSyncTime,
        syncStatus: _syncService.status,
        isFullSyncing: _syncService.status == SyncStatus.syncing,
        // Preserve existing error state
        error: state.error,
      );
    } catch (e, stackTrace) {
      AppLogger.error('NavbarSyncViewModel: Failed to update sync state', e, stackTrace);
      state = state.copyWith(error: 'Failed to update sync state: $e');
    }
  }

  /// Trigger manual sync
  Future<void> triggerSync() async {
    // AppLogger.info('NavbarSyncViewModel: Triggering manual sync');
    
    try {
      state = state.copyWith(error: null);
      
      final result = await _syncService.syncNow();
      await result.when(
        success: (syncResult) async {
          // AppLogger.info('NavbarSyncViewModel: Manual sync completed successfully');
          _updateSyncState();
        },
        failure: (failure) async {
          AppLogger.error('NavbarSyncViewModel: Manual sync failed', failure.exception, failure.stackTrace);
          state = state.copyWith(error: 'Sync failed: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('NavbarSyncViewModel: Exception during manual sync', e, stackTrace);
      state = state.copyWith(error: 'Sync failed: $e');
    }
  }

  /// Start background sync service
  Future<void> startBackgroundSync() async {
    // AppLogger.info('NavbarSyncViewModel: Starting background sync');
    
    try {
      // Background sync is automatically started by SyncService.initialize()
      // This method can be used to restart it if needed
      await _syncService.initialize();
      _updateSyncState();
      
      // AppLogger.info('NavbarSyncViewModel: Background sync started');
    } catch (e, stackTrace) {
      AppLogger.error('NavbarSyncViewModel: Failed to start background sync', e, stackTrace);
      state = state.copyWith(error: 'Failed to start sync: $e');
    }
  }

  /// Stop background sync service
  void stopBackgroundSync() {
    // AppLogger.info('NavbarSyncViewModel: Stopping background sync');
    
    try {
      // Call the sync service to stop periodic sync
      _syncService.stopPeriodicSync();
      _updateSyncState();
      
      // AppLogger.info('NavbarSyncViewModel: Background sync stop requested');
    } catch (e, stackTrace) {
      AppLogger.error('NavbarSyncViewModel: Failed to stop background sync', e, stackTrace);
      state = state.copyWith(error: 'Failed to stop sync: $e');
    }
  }

  /// Refresh account and sync status
  Future<void> refresh() async {
    // AppLogger.info('NavbarSyncViewModel: Refreshing status');
    
    try {
      await _updateAccountStatus();
      _updateSyncState();
      
      // AppLogger.info('NavbarSyncViewModel: Status refreshed');
    } catch (e, stackTrace) {
      AppLogger.error('NavbarSyncViewModel: Failed to refresh', e, stackTrace);
      state = state.copyWith(error: 'Failed to refresh: $e');
    }
  }

  /// Clear any errors
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Check if account is properly configured
  bool get hasValidAccount => state.account != null && state.isConnected;

  /// Get account display name
  String get accountDisplayName {
    if (state.account == null) return 'No Account';
    final account = state.account!;
    
    // Try to construct display name from firstName + lastName
    if (account.firstName != null && account.lastName != null) {
      return '${account.firstName} ${account.lastName}';
    }
    
    // Fallback to email if available
    if (account.email != null && account.email!.isNotEmpty) {
      return account.email!;
    }
    
    // Final fallback to username
    return account.username;
  }

  /// Get server URL for display
  String get serverUrl {
    if (state.account == null) return '';
    return state.account!.serverUrl;
  }

  /// Get sync status for display in UI
  String get syncStatusDisplay {
    switch (state.indicatorStatus) {
      case SyncIndicatorStatus.offline:
        return 'Offline';
      case SyncIndicatorStatus.error:
        return 'Error';
      case SyncIndicatorStatus.syncing:
        return 'Syncing';
      case SyncIndicatorStatus.idle:
        return state.statusText;
    }
  }
} 
