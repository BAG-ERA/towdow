// Domain service for managing project domains
// Provides business logic for domain organization and management
// Acts as intermediary between ViewModels and Repository layer

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/task_calendar.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/account_repository.dart';
import 'local_storage_service.dart';
import 'caldav_service.dart';

/// Service for managing project domains and domain-related operations
class DomainService {
  final CalendarRepository _calendarRepository;
  final LocalStorageService _localStorageService;
  final AccountRepository _accountRepository;

  DomainService(this._calendarRepository, this._localStorageService, this._accountRepository);

  /// Create a new domain
  Future<Result<void>> createDomain(String domain) async {
    AppLogger.info('DomainService: Creating domain: $domain');
    
    // Validate domain name
    final validationResult = validateDomainName(domain);
    if (validationResult is Error<void>) {
      return validationResult;
    }
    
    // Check if domain already exists
    final existsResult = await domainExists(domain);
    return existsResult.when(
      success: (exists) async {
        if (exists) {
          return Result.failure(const Failure(
            message: 'Domain already exists',
            code: 'DOMAIN_ALREADY_EXISTS',
          ));
        }
        
        // Add domain to storage
        return await _localStorageService.addDomain(domain);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Get all available domains sorted alphabetically
  Future<Result<List<String>>> getAvailableDomains() async {
    AppLogger.info('DomainService: Getting available domains');
    
    // Get domains from calendars
    final calendarDomainsResult = await _calendarRepository.getUniqueDomains();
    
    // Get standalone domains from storage
    final storageDomainsResult = await _localStorageService.getAllDomains();
    
    return calendarDomainsResult.when(
      success: (calendarDomains) => storageDomainsResult.when(
        success: (storageDomains) {
          final allDomains = <String>{...calendarDomains, ...storageDomains}.toList();
          allDomains.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          AppLogger.info('DomainService: Found ${allDomains.length} total domains');
          return Result.success(allDomains);
        },
        failure: (failure) => Result.failure(failure),
      ),
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Get all calendars grouped by domain
  Future<Result<Map<String, List<TaskCalendar>>>> getCalendarsGroupedByDomain() async {
    AppLogger.info('DomainService: Getting calendars grouped by domain');
    
    final calendarsResult = await _calendarRepository.getAll();
    return calendarsResult.when(
      success: (calendars) {
        final grouped = <String, List<TaskCalendar>>{};
        
        for (final calendar in calendars) {
          final domain = calendar.domainDisplayName;
          grouped.putIfAbsent(domain, () => []).add(calendar);
        }
        
        // Sort domains alphabetically, but put "No Domain" last
        final sortedDomains = grouped.keys.toList()
          ..sort((a, b) {
            if (a == 'No Domain') return 1;
            if (b == 'No Domain') return -1;
            return a.toLowerCase().compareTo(b.toLowerCase());
          });
        
        final sortedGrouped = <String, List<TaskCalendar>>{};
        for (final domain in sortedDomains) {
          // Sort calendars within each domain by display name
          final domainCalendars = grouped[domain]!
            ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
          sortedGrouped[domain] = domainCalendars;
        }
        
        AppLogger.info('DomainService: Grouped ${calendars.length} calendars into ${grouped.length} domains');
        return Result.success(sortedGrouped);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Get calendars belonging to a specific domain
  Future<Result<List<TaskCalendar>>> getCalendarsByDomain(String? domain) async {
    AppLogger.info('DomainService: Getting calendars for domain: ${domain ?? "No Domain"}');
    return await _calendarRepository.getCalendarsByDomain(domain);
  }

  /// Assign a domain to a calendar
  Future<Result<void>> assignDomainToCalendar(String calendarUid, String? domain) async {
    AppLogger.info('DomainService: Assigning domain "$domain" to calendar $calendarUid');
    
    final calendarResult = await _calendarRepository.getById(calendarUid);
    return calendarResult.when(
      success: (calendar) async {
        if (calendar == null) {
          return Result.failure(const Failure(
            message: 'Calendar not found',
            code: 'CALENDAR_NOT_FOUND',
          ));
        }
        
        final updatedCalendar = calendar.withDomain(domain);
        
        // Save locally first
        final saveResult = await _calendarRepository.save(updatedCalendar);
        if (saveResult is Error<void>) {
          return saveResult;
        }
        
        // Then sync to CalDAV server
        return await _syncDomainToServer(updatedCalendar);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Remove domain from a calendar
  Future<Result<void>> removeDomainFromCalendar(String calendarUid) async {
    AppLogger.info('DomainService: Removing domain from calendar $calendarUid');
    
    final calendarResult = await _calendarRepository.getById(calendarUid);
    return calendarResult.when(
      success: (calendar) async {
        if (calendar == null) {
          return Result.failure(const Failure(
            message: 'Calendar not found',
            code: 'CALENDAR_NOT_FOUND',
          ));
        }
        
        final updatedCalendar = calendar.withoutDomain();
        
        // Save locally first
        final saveResult = await _calendarRepository.save(updatedCalendar);
        if (saveResult is Error<void>) {
          return saveResult;
        }
        
        // Then sync to CalDAV server
        return await _syncDomainToServer(updatedCalendar);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Sync domain changes to CalDAV server
  Future<Result<void>> _syncDomainToServer(TaskCalendar calendar) async {
    try {
      AppLogger.info('DomainService: *** Starting domain sync to server ***');
      AppLogger.info('DomainService: Calendar UID: ${calendar.uid}');
      AppLogger.info('DomainService: Calendar path: ${calendar.path}');
      AppLogger.info('DomainService: Domain value: ${calendar.flowitDomain ?? "(null)"}');
      
      // Get active account
      final accountResult = await _accountRepository.getActiveAccount();
      return accountResult.when(
        success: (account) async {
          if (account == null) {
            AppLogger.warning('DomainService: No active account found, skipping server sync');
            return Result.success(null); // Still success since local save worked
          }
          
          AppLogger.info('DomainService: Found active account: ${account.username}@${account.serverUrl}');
          
          // Create CalDAV service instance
          final caldavService = CalDAVService(account: account);
          AppLogger.info('DomainService: Created CalDAV service, calling updateCalendarProperties...');
          
          // Update calendar properties on server
          final updateResult = await caldavService.updateCalendarProperties(calendar);
          
          return updateResult.when(
            success: (_) {
              AppLogger.info('DomainService: *** Successfully synced domain to server ***');
              return Result.success(null);
            },
            failure: (failure) {
              AppLogger.error('DomainService: Failed to sync domain to server: ${failure.message}');
              AppLogger.error('DomainService: Failure code: ${failure.code}');
              // Don't fail the entire operation since local save succeeded
              // The sync will be retried during next full sync
              return Result.success(null);
            },
          );
        },
        failure: (failure) {
          AppLogger.error('DomainService: Failed to get active account for server sync: ${failure.message}');
          AppLogger.error('DomainService: Account failure code: ${failure.code}');
          // Don't fail the entire operation since local save succeeded
          return Result.success(null);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('DomainService: Exception during server sync', e, stackTrace);
      // Don't fail the entire operation since local save succeeded
      return Result.success(null);
    }
  }

  /// Rename a domain across all calendars that use it
  Future<Result<void>> renameDomain(String oldDomain, String newDomain) async {
    AppLogger.info('DomainService: Renaming domain "$oldDomain" to "$newDomain"');
    
    if (oldDomain.toLowerCase() == 'no domain') {
      return Result.failure(const Failure(
        message: 'Cannot rename the "No Domain" group',
        code: 'INVALID_DOMAIN_RENAME',
      ));
    }
    
    if (newDomain.trim().isEmpty) {
      return Result.failure(const Failure(
        message: 'New domain name cannot be empty',
        code: 'EMPTY_DOMAIN_NAME',
      ));
    }
    
    return await _calendarRepository.renameDomain(oldDomain, newDomain);
  }

  /// Bulk assign domain to multiple calendars
  Future<Result<void>> bulkAssignDomain(List<String> calendarUids, String? domain) async {
    AppLogger.info('DomainService: Bulk assigning domain "$domain" to ${calendarUids.length} calendars');
    
    for (final uid in calendarUids) {
      final result = await assignDomainToCalendar(uid, domain);
      if (result is Error<void>) {
        AppLogger.error('DomainService: Failed to assign domain to calendar $uid: ${result.failure.message}');
        return result;
      }
    }
    
    return Result.success(null);
  }

  /// Get domain statistics (domain name -> calendar count)
  Future<Result<Map<String, int>>> getDomainStatistics() async {
    AppLogger.info('DomainService: Getting domain statistics');
    return await _calendarRepository.getDomainStatistics();
  }

  /// Get calendars without domain
  Future<Result<List<TaskCalendar>>> getCalendarsWithoutDomain() async {
    AppLogger.info('DomainService: Getting calendars without domain');
    return await _calendarRepository.getCalendarsWithoutDomain();
  }

  /// Remove a domain from storage
  Future<Result<void>> removeDomainFromStorage(String domain) async {
    AppLogger.info('DomainService: Removing domain from storage: $domain');
    return await _localStorageService.removeDomain(domain);
  }

  /// Validate domain name
  Result<void> validateDomainName(String domain) {
    final trimmed = domain.trim();
    
    if (trimmed.isEmpty) {
      return Result.failure(const Failure(
        message: 'Domain name cannot be empty',
        code: 'EMPTY_DOMAIN_NAME',
      ));
    }
    
    if (trimmed.toLowerCase() == 'no domain') {
      return Result.failure(const Failure(
        message: 'Cannot use "No Domain" as a domain name',
        code: 'RESERVED_DOMAIN_NAME',
      ));
    }
    
    return Result.success(null);
  }

  /// Check if a domain exists
  Future<Result<bool>> domainExists(String domain) async {
    // Check storage first (faster)
    final storageResult = await _localStorageService.domainExists(domain);
    return storageResult.when(
      success: (existsInStorage) async {
        if (existsInStorage) {
          return Result.success(true);
        }
        
        // Check calendar domains
        final calendarDomainsResult = await _calendarRepository.getUniqueDomains();
        return calendarDomainsResult.when(
          success: (calendarDomains) {
            final existsInCalendars = calendarDomains.any((d) => d.toLowerCase() == domain.toLowerCase());
            return Result.success(existsInCalendars);
          },
          failure: (failure) => Result.failure(failure),
        );
      },
      failure: (failure) => Result.failure(failure),
    );
  }
} 