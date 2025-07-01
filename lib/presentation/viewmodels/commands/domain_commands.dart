// Domain commands for managing project domains
// Implements Command pattern for domain-related operations
// Provides reusable and composable domain management actions

import '../../../core/command.dart';
import '../../../core/result.dart';
import '../../../core/logger.dart';
import '../../../data/services/domain_service.dart';
import '../../../data/models/task_calendar.dart';

/// Command to assign a domain to a single calendar
class AssignDomainToCalendarCommand extends VoidCommand {
  final DomainService _domainService;
  final String calendarUid;
  final String? domain;

  AssignDomainToCalendarCommand(
    this._domainService,
    this.calendarUid,
    this.domain,
  );

  @override
  Future<void> run() async {
    AppLogger.info('AssignDomainToCalendarCommand: Assigning domain "$domain" to calendar $calendarUid');
    final result = await _domainService.assignDomainToCalendar(calendarUid, domain);
    
    result.when(
      success: (_) => null,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to remove domain from a calendar
class RemoveDomainFromCalendarCommand extends VoidCommand {
  final DomainService _domainService;
  final String calendarUid;

  RemoveDomainFromCalendarCommand(
    this._domainService,
    this.calendarUid,
  );

  @override
  Future<void> run() async {
    AppLogger.info('RemoveDomainFromCalendarCommand: Removing domain from calendar $calendarUid');
    final result = await _domainService.removeDomainFromCalendar(calendarUid);
    
    result.when(
      success: (_) => null,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to bulk assign domain to multiple calendars
class BulkAssignDomainCommand extends VoidCommand {
  final DomainService _domainService;
  final List<String> calendarUids;
  final String? domain;

  BulkAssignDomainCommand(
    this._domainService,
    this.calendarUids,
    this.domain,
  );

  @override
  Future<void> run() async {
    AppLogger.info('BulkAssignDomainCommand: Bulk assigning domain "$domain" to ${calendarUids.length} calendars');
    final result = await _domainService.bulkAssignDomain(calendarUids, domain);
    
    result.when(
      success: (_) => null,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to rename a domain across all calendars
class RenameDomainCommand extends VoidCommand {
  final DomainService _domainService;
  final String oldDomain;
  final String newDomain;

  RenameDomainCommand(
    this._domainService,
    this.oldDomain,
    this.newDomain,
  );

  @override
  Future<void> run() async {
    AppLogger.info('RenameDomainCommand: Renaming domain "$oldDomain" to "$newDomain"');
    
    // Validate the new domain name first
    final validationResult = _domainService.validateDomainName(newDomain);
    if (validationResult is Error<void>) {
      throw Exception(validationResult.failure.message);
    }
    
    final result = await _domainService.renameDomain(oldDomain, newDomain);
    result.when(
      success: (_) => null,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to get all available domains
class GetAvailableDomainsCommand extends Command<List<String>> {
  final DomainService _domainService;

  GetAvailableDomainsCommand(this._domainService);

  @override
  Future<List<String>> run() async {
    AppLogger.info('GetAvailableDomainsCommand: Getting all available domains');
    final result = await _domainService.getAvailableDomains();
    
    return result.when(
      success: (domains) => domains,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to get calendars grouped by domain
class GetCalendarsGroupedByDomainCommand extends Command<Map<String, List<TaskCalendar>>> {
  final DomainService _domainService;

  GetCalendarsGroupedByDomainCommand(this._domainService);

  @override
  Future<Map<String, List<TaskCalendar>>> run() async {
    AppLogger.info('GetCalendarsGroupedByDomainCommand: Getting calendars grouped by domain');
    final result = await _domainService.getCalendarsGroupedByDomain();
    
    return result.when(
      success: (grouped) => grouped,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to get calendars by specific domain
class GetCalendarsByDomainCommand extends Command<List<TaskCalendar>> {
  final DomainService _domainService;
  final String? domain;

  GetCalendarsByDomainCommand(this._domainService, this.domain);

  @override
  Future<List<TaskCalendar>> run() async {
    AppLogger.info('GetCalendarsByDomainCommand: Getting calendars for domain: ${domain ?? "No Domain"}');
    final result = await _domainService.getCalendarsByDomain(domain);
    
    return result.when(
      success: (calendars) => calendars,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to get domain statistics
class GetDomainStatisticsCommand extends Command<Map<String, int>> {
  final DomainService _domainService;

  GetDomainStatisticsCommand(this._domainService);

  @override
  Future<Map<String, int>> run() async {
    AppLogger.info('GetDomainStatisticsCommand: Getting domain statistics');
    final result = await _domainService.getDomainStatistics();
    
    return result.when(
      success: (stats) => stats,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to check if a domain exists
class CheckDomainExistsCommand extends Command<bool> {
  final DomainService _domainService;
  final String domain;

  CheckDomainExistsCommand(this._domainService, this.domain);

  @override
  Future<bool> run() async {
    AppLogger.info('CheckDomainExistsCommand: Checking if domain "$domain" exists');
    final result = await _domainService.domainExists(domain);
    
    return result.when(
      success: (exists) => exists,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to validate domain name
class ValidateDomainNameCommand extends VoidCommand {
  final DomainService _domainService;
  final String domain;

  ValidateDomainNameCommand(this._domainService, this.domain);

  @override
  Future<void> run() async {
    AppLogger.info('ValidateDomainNameCommand: Validating domain name "$domain"');
    final result = _domainService.validateDomainName(domain);
    
    result.when(
      success: (_) => null,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to get calendars without domain
class GetCalendarsWithoutDomainCommand extends Command<List<TaskCalendar>> {
  final DomainService _domainService;

  GetCalendarsWithoutDomainCommand(this._domainService);

  @override
  Future<List<TaskCalendar>> run() async {
    AppLogger.info('GetCalendarsWithoutDomainCommand: Getting calendars without domain');
    final result = await _domainService.getCalendarsWithoutDomain();
    
    return result.when(
      success: (calendars) => calendars,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Factory class for creating domain commands
class DomainCommandFactory {
  final DomainService _domainService;

  DomainCommandFactory(this._domainService);

  /// Create command to assign domain to calendar
  AssignDomainToCalendarCommand assignDomainToCalendar(String calendarUid, String? domain) {
    return AssignDomainToCalendarCommand(_domainService, calendarUid, domain);
  }

  /// Create command to remove domain from calendar
  RemoveDomainFromCalendarCommand removeDomainFromCalendar(String calendarUid) {
    return RemoveDomainFromCalendarCommand(_domainService, calendarUid);
  }

  /// Create command to bulk assign domain
  BulkAssignDomainCommand bulkAssignDomain(List<String> calendarUids, String? domain) {
    return BulkAssignDomainCommand(_domainService, calendarUids, domain);
  }

  /// Create command to rename domain
  RenameDomainCommand renameDomain(String oldDomain, String newDomain) {
    return RenameDomainCommand(_domainService, oldDomain, newDomain);
  }

  /// Create command to get available domains
  GetAvailableDomainsCommand getAvailableDomains() {
    return GetAvailableDomainsCommand(_domainService);
  }

  /// Create command to get calendars grouped by domain
  GetCalendarsGroupedByDomainCommand getCalendarsGroupedByDomain() {
    return GetCalendarsGroupedByDomainCommand(_domainService);
  }

  /// Create command to get calendars by domain
  GetCalendarsByDomainCommand getCalendarsByDomain(String? domain) {
    return GetCalendarsByDomainCommand(_domainService, domain);
  }

  /// Create command to get domain statistics
  GetDomainStatisticsCommand getDomainStatistics() {
    return GetDomainStatisticsCommand(_domainService);
  }

  /// Create command to check domain exists
  CheckDomainExistsCommand checkDomainExists(String domain) {
    return CheckDomainExistsCommand(_domainService, domain);
  }

  /// Create command to validate domain name
  ValidateDomainNameCommand validateDomainName(String domain) {
    return ValidateDomainNameCommand(_domainService, domain);
  }

  /// Create command to get calendars without domain
  GetCalendarsWithoutDomainCommand getCalendarsWithoutDomain() {
    return GetCalendarsWithoutDomainCommand(_domainService);
  }
} 