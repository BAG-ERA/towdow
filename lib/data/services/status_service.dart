// Status service for managing project statuses
// Provides business logic for status organization and management
// Acts as intermediary between ViewModels and Repository layer

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/task_calendar.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/account_repository.dart';
import 'local_storage_service.dart';
import 'caldav_service.dart';

/// Service for managing project statuses and status-related operations
class StatusService {
  final CalendarRepository _calendarRepository;
  final LocalStorageService _localStorageService;
  final AccountRepository _accountRepository;

  StatusService(this._calendarRepository, this._localStorageService, this._accountRepository);

  /// Create a new status
  Future<Result<void>> createStatus(String status) async {
    AppLogger.info('StatusService: Creating status: $status');
    
    // Validate status name
    final validationResult = validateStatusName(status);
    if (validationResult is Error<void>) {
      return validationResult;
    }
    
    // Check if status already exists
    final existsResult = await statusExists(status);
    return existsResult.when(
      success: (exists) async {
        if (exists) {
          return Result.failure(const Failure(
            message: 'Status already exists',
            code: 'STATUS_ALREADY_EXISTS',
          ));
        }
        
        // Add status to storage
        return await _localStorageService.addStatus(status);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Get all available statuses sorted alphabetically
  Future<Result<List<String>>> getAvailableStatuses() async {
    AppLogger.info('StatusService: Getting available statuses');
    
    // Get statuses from calendars
    final calendarStatusesResult = await _calendarRepository.getUniqueStatuses();
    
    // Get standalone statuses from storage
    final storageStatusesResult = await _localStorageService.getAllStatuses();
    
    return calendarStatusesResult.when(
      success: (calendarStatuses) => storageStatusesResult.when(
        success: (storageStatuses) {
          final allStatuses = <String>{...calendarStatuses, ...storageStatuses}.toList();
          allStatuses.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          AppLogger.info('StatusService: Found ${allStatuses.length} total statuses');
          return Result.success(allStatuses);
        },
        failure: (failure) => Result.failure(failure),
      ),
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Get calendars grouped by status
  Future<Result<Map<String, List<TaskCalendar>>>> getCalendarsGroupedByStatus() async {
    AppLogger.info('StatusService: Getting calendars grouped by status');
    
    final result = await _calendarRepository.getAll();
    return result.when(
      success: (calendars) {
        final grouped = <String, List<TaskCalendar>>{};
        
        for (final calendar in calendars) {
          final status = calendar.statusDisplayName;
          grouped.putIfAbsent(status, () => []).add(calendar);
        }
        
        // Sort each group by calendar name
        for (final entry in grouped.entries) {
          entry.value.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        }
        
        AppLogger.info('StatusService: Grouped ${calendars.length} calendars into ${grouped.length} status groups');
        return Result.success(grouped);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Get calendars by specific status
  Future<Result<List<TaskCalendar>>> getCalendarsByStatus(String? status) async {
    AppLogger.info('StatusService: Getting calendars by status: ${status ?? "No Status"}');
    return await _calendarRepository.getCalendarsByStatus(status);
  }

  /// Assign a status to a calendar
  Future<Result<void>> assignStatusToCalendar(String calendarUid, String? status) async {
    AppLogger.info('StatusService: Assigning status "$status" to calendar $calendarUid');
    
    final calendarResult = await _calendarRepository.getById(calendarUid);
    return calendarResult.when(
      success: (calendar) async {
        if (calendar == null) {
          return Result.failure(const Failure(
            message: 'Calendar not found',
            code: 'CALENDAR_NOT_FOUND',
          ));
        }
        
        final updatedCalendar = calendar.withStatus(status);
        
        // Save locally first
        final saveResult = await _calendarRepository.save(updatedCalendar);
        if (saveResult is Error<void>) {
          return saveResult;
        }
        
        // Then sync to CalDAV server
        return await _syncStatusToServer(updatedCalendar);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Remove status from a calendar
  Future<Result<void>> removeStatusFromCalendar(String calendarUid) async {
    AppLogger.info('StatusService: Removing status from calendar $calendarUid');
    
    final calendarResult = await _calendarRepository.getById(calendarUid);
    return calendarResult.when(
      success: (calendar) async {
        if (calendar == null) {
          return Result.failure(const Failure(
            message: 'Calendar not found',
            code: 'CALENDAR_NOT_FOUND',
          ));
        }
        
        final updatedCalendar = calendar.withoutStatus();
        
        // Save locally first
        final saveResult = await _calendarRepository.save(updatedCalendar);
        if (saveResult is Error<void>) {
          return saveResult;
        }
        
        // Then sync to CalDAV server
        return await _syncStatusToServer(updatedCalendar);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Archive a calendar (set status to ARCHIVE)
  Future<Result<void>> archiveCalendar(String calendarUid) async {
    AppLogger.info('StatusService: Archiving calendar $calendarUid');
    return await assignStatusToCalendar(calendarUid, 'ARCHIVE');
  }

  /// Unarchive a calendar (set status to ONGOING)
  Future<Result<void>> unarchiveCalendar(String calendarUid) async {
    AppLogger.info('StatusService: Unarchiving calendar $calendarUid');
    return await assignStatusToCalendar(calendarUid, 'ONGOING');
  }

  /// Sync status to CalDAV server
  Future<Result<void>> _syncStatusToServer(TaskCalendar calendar) async {
    try {
      AppLogger.info('StatusService: *** Starting status sync to server ***');
      AppLogger.info('StatusService: Calendar UID: ${calendar.uid}');
      AppLogger.info('StatusService: Calendar path: ${calendar.path}');
      AppLogger.info('StatusService: Status value: ${calendar.flowitStatus ?? "(null)"}');
      
      // Get active account
      final accountResult = await _accountRepository.getActiveAccount();
      return accountResult.when(
        success: (account) async {
          if (account == null) {
            AppLogger.warning('StatusService: No active account found, skipping server sync');
            return Result.success(null); // Still success since local save worked
          }
          
          AppLogger.info('StatusService: Found active account: ${account.username}@${account.serverUrl}');
          
          // Create CalDAV service instance
          final caldavService = CalDAVService(account: account);
          AppLogger.info('StatusService: Created CalDAV service, calling updateCalendarProperties...');
          
          // Update calendar properties on server
          final updateResult = await caldavService.updateCalendarProperties(calendar);
          
          return updateResult.when(
            success: (_) {
              AppLogger.info('StatusService: *** Successfully synced status to server ***');
              return Result.success(null);
            },
            failure: (failure) {
              AppLogger.error('StatusService: Failed to sync status to server: ${failure.message}');
              AppLogger.error('StatusService: Failure code: ${failure.code}');
              // Don't fail the entire operation since local save succeeded
              // The sync will be retried during next full sync
              return Result.success(null);
            },
          );
        },
        failure: (failure) {
          AppLogger.error('StatusService: Failed to get active account for server sync: ${failure.message}');
          AppLogger.error('StatusService: Account failure code: ${failure.code}');
          // Don't fail the entire operation since local save succeeded
          return Result.success(null);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('StatusService: Exception during server sync', e, stackTrace);
      // Don't fail the entire operation since local save succeeded
      return Result.success(null);
    }
  }

  /// Rename a status across all calendars
  Future<Result<void>> renameStatus(String oldStatus, String newStatus) async {
    AppLogger.info('StatusService: Renaming status "$oldStatus" to "$newStatus"');
    
    // Validate the new status name
    final validationResult = validateStatusName(newStatus);
    if (validationResult is Error<void>) {
      return validationResult;
    }
    
    // Update repository
    final repositoryResult = await _calendarRepository.changeStatus(oldStatus, newStatus);
    if (repositoryResult is Error<void>) {
      return repositoryResult;
    }
    
    // Update local storage
    final storageRenameResult = await _localStorageService.renameStatus(oldStatus, newStatus);
    if (storageRenameResult is Error<void>) {
      AppLogger.warning('StatusService: Failed to rename status in storage, but repository update succeeded');
    }
    
    return Result.success(null);
  }

  /// Bulk assign status to multiple calendars
  Future<Result<void>> bulkAssignStatus(List<String> calendarUids, String? status) async {
    AppLogger.info('StatusService: Bulk assigning status "$status" to ${calendarUids.length} calendars');
    
    for (final uid in calendarUids) {
      final result = await assignStatusToCalendar(uid, status);
      if (result is Error<void>) {
        AppLogger.error('StatusService: Failed to assign status to calendar $uid: ${result.failure.message}');
        return result;
      }
    }
    
    return Result.success(null);
  }

  /// Get status statistics (status name -> calendar count)
  Future<Result<Map<String, int>>> getStatusStatistics() async {
    AppLogger.info('StatusService: Getting status statistics');
    return await _calendarRepository.getStatusStatistics();
  }

  /// Get calendars without status
  Future<Result<List<TaskCalendar>>> getCalendarsWithoutStatus() async {
    AppLogger.info('StatusService: Getting calendars without status');
    return await _calendarRepository.getCalendarsWithoutStatus();
  }

  /// Get archived calendars
  Future<Result<List<TaskCalendar>>> getArchivedCalendars() async {
    AppLogger.info('StatusService: Getting archived calendars');
    return await _calendarRepository.getArchivedCalendars();
  }

  /// Get active calendars (not archived)
  Future<Result<List<TaskCalendar>>> getActiveCalendars() async {
    AppLogger.info('StatusService: Getting active calendars');
    return await _calendarRepository.getActiveCalendars();
  }

  /// Remove a status from storage
  Future<Result<void>> removeStatusFromStorage(String status) async {
    AppLogger.info('StatusService: Removing status from storage: $status');
    return await _localStorageService.removeStatus(status);
  }

  /// Validate status name
  Result<void> validateStatusName(String status) {
    final trimmed = status.trim().toUpperCase();
    
    if (trimmed.isEmpty) {
      return Result.failure(const Failure(
        message: 'Status name cannot be empty',
        code: 'EMPTY_STATUS_NAME',
      ));
    }
    
    if (!TaskCalendarStatus.validStatuses.contains(trimmed)) {
      return Result.failure(Failure(
        message: 'Invalid status. Valid statuses are: ${TaskCalendarStatus.validStatuses.join(', ')}',
        code: 'INVALID_STATUS_NAME',
      ));
    }
    
    return Result.success(null);
  }

  /// Check if a status exists
  Future<Result<bool>> statusExists(String status) async {
    // Check storage first (faster)
    final storageResult = await _localStorageService.statusExists(status);
    return storageResult.when(
      success: (existsInStorage) async {
        if (existsInStorage) {
          return Result.success(true);
        }
        
        // Check calendar statuses
        final calendarStatusesResult = await _calendarRepository.getUniqueStatuses();
        return calendarStatusesResult.when(
          success: (calendarStatuses) {
            final existsInCalendars = calendarStatuses.any((s) => s.toLowerCase() == status.toLowerCase());
            return Result.success(existsInCalendars);
          },
          failure: (failure) => Result.failure(failure),
        );
      },
      failure: (failure) => Result.failure(failure),
    );
  }
} 