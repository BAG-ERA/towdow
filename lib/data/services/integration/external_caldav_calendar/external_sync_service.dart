// External calendar sync service
// Handles background synchronization of external CalDAV calendars
// Minimal implementation for testing

import 'dart:async';
import '../../../../core/result.dart';
import '../../../../core/logger.dart';
import '../../../models/external_caldav_account.dart';
import '../../../models/external_calendar.dart';
import '../../../repositories/external_account_repository.dart';
import '../../../repositories/external_calendar_repository.dart';
import '../../../repositories/external_event_repository.dart';
import 'external_caldav_service.dart';

// External calendar sync service
class ExternalCalendarSyncService {
  final ExternalAccountRepository _accountRepository;
  final ExternalCalendarRepository _calendarRepository;
  final ExternalEventRepository _eventRepository;
  
  Timer? _syncTimer;
  bool _syncRunning = false;
  
  ExternalCalendarSyncService(
    this._accountRepository,
    this._calendarRepository,
    this._eventRepository,
  );

  /// Start background sync with specified interval
  void startBackgroundSync({Duration interval = const Duration(minutes: 5)}) {
    AppLogger.info('ExternalCalendarSyncService: Starting background sync with interval: ${interval.inMinutes} minutes');
    
    _syncTimer?.cancel();
    
    // Trigger immediate sync on startup
    if (!_syncRunning) {
      syncAllAccounts();
    }
    
    _syncTimer = Timer.periodic(interval, (_) async {
      if (!_syncRunning) {
        await syncAllAccounts();
      }
    });
  }

  /// Stop background sync
  void stopBackgroundSync() {
    AppLogger.info('ExternalCalendarSyncService: Stopping background sync');
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Manually sync all accounts
  Future<Result<void>> syncAllAccounts() async {
    if (_syncRunning) {
      AppLogger.warning('ExternalCalendarSyncService: Sync already running, skipping');
      return const Result.success(null);
    }

    _syncRunning = true;
    AppLogger.info('ExternalCalendarSyncService: Starting sync for all accounts');

    try {
      final accountsResult = await _accountRepository.getAll();
      
      return await accountsResult.when(
        success: (accounts) async {
          final activeAccounts = accounts.where((account) => account.isActive).toList();
          AppLogger.info('ExternalCalendarSyncService: Found ${activeAccounts.length} active accounts to sync');
          
          // Sync each active account
          for (final account in activeAccounts) {
            final syncResult = await syncAccount(account.id);
            syncResult.when(
              success: (_) => AppLogger.debug('ExternalCalendarSyncService: Successfully synced account ${account.id}'),
              failure: (failure) => AppLogger.warning('ExternalCalendarSyncService: Failed to sync account ${account.id}: ${failure.message}'),
            );
            // Continue with other accounts even if one fails
          }
          
          AppLogger.info('ExternalCalendarSyncService: Completed sync for all accounts');
          return const Result.success(null);
        },
        failure: (failure) {
          AppLogger.error('ExternalCalendarSyncService: Failed to get accounts: ${failure.message}');
          return Result.failure(failure);
        },
      );
    } catch (e) {
      AppLogger.error('ExternalCalendarSyncService: Unexpected error during sync: $e');
      return Result.failure(Failure(
        message: 'Unexpected sync error: $e',
        exception: e is Exception ? e : Exception(e.toString()),
      ));
    } finally {
      _syncRunning = false;
    }
  }

  /// Sync a single account
  Future<Result<void>> syncAccount(String accountId) async {
    AppLogger.info('ExternalCalendarSyncService: Syncing account: $accountId');
    
    try {
      // Get the account
      final accountResult = await _accountRepository.getById(accountId);
      return await accountResult.when(
        success: (account) async {
          if (account == null) {
            return Result.failure(Failure(
              message: 'Account not found: $accountId',
              exception: Exception('Account not found'),
            ));
          }
          return await _syncAccountInternal(account);
        },
        failure: (failure) async => Result.failure(failure),
      );
    } catch (e) {
      AppLogger.error('ExternalCalendarSyncService: Account sync failed: $e');
      return Result.failure(Failure(
        message: 'Account sync failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
      ));
    }
  }
  
  /// Internal method to sync account after validation
  Future<Result<void>> _syncAccountInternal(ExternalCaldavAccount account) async {
    try {
      
      // Get calendars for this account
      final calendarsResult = await _calendarRepository.getCalendarsByAccount(account.id);
      return await calendarsResult.when(
        success: (calendars) async {
          final enabledCalendars = calendars.where((cal) => cal.isEnabled).toList();
          AppLogger.info('ExternalCalendarSyncService: Account ${account.id} has ${calendars.length} total calendars, ${enabledCalendars.length} enabled');
          
          // Debug log each calendar
          for (final calendar in calendars) {
            AppLogger.debug('ExternalCalendarSyncService: Calendar "${calendar.displayName}" (${calendar.uid}) - enabled: ${calendar.isEnabled}, path: ${calendar.href}');
          }
          
          // Sync each enabled calendar
          for (final calendar in enabledCalendars) {
            await _syncCalendar(account, calendar);
          }
          
          // Update account last sync time
          final updatedAccount = account.copyWith(
            lastSyncAt: DateTime.now(),
            lastSuccessfulSync: DateTime.now(),
            syncErrorCount: 0,
            lastSyncError: null,
          );
          await _accountRepository.saveWithoutSync(updatedAccount);
          
          AppLogger.info('ExternalCalendarSyncService: Successfully synced account ${account.id}');
          return const Result.success(null);
        },
        failure: (failure) async {
          AppLogger.error('ExternalCalendarSyncService: Failed to get calendars for account ${account.id}: ${failure.message}');
          return Result.failure(failure);
        },
      );
    } catch (e) {
      AppLogger.error('ExternalCalendarSyncService: Account sync failed: $e');
      
      // Update account with error info
      try {
        final updatedAccount = account.copyWith(
          lastSyncAt: DateTime.now(),
          syncErrorCount: account.syncErrorCount + 1,
          lastSyncError: e.toString(),
        );
        await _accountRepository.saveWithoutSync(updatedAccount);
      } catch (updateError) {
        AppLogger.warning('ExternalCalendarSyncService: Failed to update account error status: $updateError');
      }
      
      return Result.failure(Failure(
        message: 'Account sync failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
      ));
    }
  }
  
  /// Sync a single calendar
  Future<void> _syncCalendar(ExternalCaldavAccount account, ExternalCalendar calendar) async {
    AppLogger.debug('ExternalCalendarSyncService: Syncing calendar ${calendar.displayName} (${calendar.uid})');
    
    try {
      // Create CalDAV service for this account
      final caldavService = ExternalCalDAVService(account: account);
      
      // Calculate time range for sync (yesterday to +30 days)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day); // Start of today
      final yesterday = today.subtract(const Duration(days: 1)); // Start of yesterday
      final timeMin = yesterday;
      final timeMax = now.add(const Duration(days: 30)); // 30 days from now
      
      AppLogger.debug('ExternalCalendarSyncService: Syncing events from ${timeMin.toIso8601String()} to ${timeMax.toIso8601String()}');
      
      // Fetch events from CalDAV server
      final eventsResult = await caldavService.fetchEvents(
        calendarPath: calendar.href, 
        calendarUid: calendar.uid,
        timeMin: timeMin,
        timeMax: timeMax,
      );
      
      await eventsResult.when(
        success: (events) async {
          AppLogger.info('ExternalCalendarSyncService: Fetched ${events.length} events from calendar ${calendar.displayName}');
          
          // Save events to repository
          for (final event in events) {
            await _eventRepository.save(event);
          }
          
          AppLogger.info('ExternalCalendarSyncService: Saved ${events.length} events from calendar ${calendar.displayName}');
        },
        failure: (failure) {
          AppLogger.error('ExternalCalendarSyncService: Failed to fetch events from calendar ${calendar.displayName}: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('ExternalCalendarSyncService: Error syncing calendar ${calendar.displayName}: $e');
    }
  }

  /// Force full resync of an account (clears sync tokens)
  Future<Result<void>> forceFullResync(String accountId) async {
    AppLogger.info('ExternalCalendarSyncService: Starting force full resync for account: $accountId');
    
    try {
      // TODO: Implement force resync logic
      AppLogger.info('ExternalCalendarSyncService: Force resync not yet implemented');
      return const Result.success(null);
    } catch (e) {
      AppLogger.error('ExternalCalendarSyncService: Force resync failed: $e');
      return Result.failure(Failure(
        message: 'Force resync failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
      ));
    }
  }

  /// Get sync status for all accounts
  Future<Result<Map<String, Map<String, dynamic>>>> getSyncStatus() async {
    final accountsResult = await _accountRepository.getAll();
    
    return accountsResult.when(
      success: (accounts) async {
        final status = <String, Map<String, dynamic>>{};
        
        for (final account in accounts) {
          status[account.id] = {
            'displayName': account.displayName,
            'isActive': account.isActive,
            'lastSyncAt': account.lastSyncAt?.toIso8601String(),
            'lastSuccessfulSync': account.lastSuccessfulSync?.toIso8601String(),
            'lastSyncError': account.lastSyncError,
            'syncErrorCount': account.syncErrorCount,
            'needsSync': account.needsSync,
            'hasSyncErrors': account.hasSyncErrors,
          };
        }
        
        return Result.success(status);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Dispose resources
  void dispose() {
    stopBackgroundSync();
  }
}

// Extension methods for external calendar sync
extension ExternalCalendarSyncExtensions on ExternalCalendarSyncService {
  /// Check if sync is currently running
  bool get isSyncRunning => _syncRunning;
} 