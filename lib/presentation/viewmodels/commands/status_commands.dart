// Status commands for managing project statuses
// Implements Command pattern for status-related operations
// Provides reusable and composable status management actions

import '../../../core/command.dart';
import '../../../core/result.dart';
import '../../../core/logger.dart';
import '../../../data/services/status_service.dart';
import '../../../data/models/task_calendar.dart';

/// Command to assign a status to a single calendar
class AssignStatusToCalendarCommand extends VoidCommand {
  final StatusService _statusService;
  final String calendarUid;
  final String? status;

  AssignStatusToCalendarCommand(
    this._statusService,
    this.calendarUid,
    this.status,
  );

  @override
  Future<void> run() async {
    AppLogger.info('AssignStatusToCalendarCommand: Assigning status "$status" to calendar $calendarUid');
    final result = await _statusService.assignStatusToCalendar(calendarUid, status);
    
    result.when(
      success: (_) => null,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to remove status from a calendar
class RemoveStatusFromCalendarCommand extends VoidCommand {
  final StatusService _statusService;
  final String calendarUid;

  RemoveStatusFromCalendarCommand(
    this._statusService,
    this.calendarUid,
  );

  @override
  Future<void> run() async {
    AppLogger.info('RemoveStatusFromCalendarCommand: Removing status from calendar $calendarUid');
    final result = await _statusService.removeStatusFromCalendar(calendarUid);
    
    result.when(
      success: (_) => null,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to archive a calendar
class ArchiveCalendarCommand extends VoidCommand {
  final StatusService _statusService;
  final String calendarUid;

  ArchiveCalendarCommand(
    this._statusService,
    this.calendarUid,
  );

  @override
  Future<void> run() async {
    AppLogger.info('ArchiveCalendarCommand: Archiving calendar $calendarUid');
    final result = await _statusService.archiveCalendar(calendarUid);
    
    result.when(
      success: (_) => null,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to unarchive a calendar
class UnarchiveCalendarCommand extends VoidCommand {
  final StatusService _statusService;
  final String calendarUid;

  UnarchiveCalendarCommand(
    this._statusService,
    this.calendarUid,
  );

  @override
  Future<void> run() async {
    AppLogger.info('UnarchiveCalendarCommand: Unarchiving calendar $calendarUid');
    final result = await _statusService.unarchiveCalendar(calendarUid);
    
    result.when(
      success: (_) => null,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to bulk assign status to multiple calendars
class BulkAssignStatusCommand extends VoidCommand {
  final StatusService _statusService;
  final List<String> calendarUids;
  final String? status;

  BulkAssignStatusCommand(
    this._statusService,
    this.calendarUids,
    this.status,
  );

  @override
  Future<void> run() async {
    AppLogger.info('BulkAssignStatusCommand: Bulk assigning status "$status" to ${calendarUids.length} calendars');
    final result = await _statusService.bulkAssignStatus(calendarUids, status);
    
    result.when(
      success: (_) => null,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to rename a status across all calendars
class RenameStatusCommand extends VoidCommand {
  final StatusService _statusService;
  final String oldStatus;
  final String newStatus;

  RenameStatusCommand(
    this._statusService,
    this.oldStatus,
    this.newStatus,
  );

  @override
  Future<void> run() async {
    AppLogger.info('RenameStatusCommand: Renaming status "$oldStatus" to "$newStatus"');
    
    // Validate the new status name first
    final validationResult = _statusService.validateStatusName(newStatus);
    if (validationResult is Error<void>) {
      throw Exception(validationResult.failure.message);
    }
    
    final result = await _statusService.renameStatus(oldStatus, newStatus);
    result.when(
      success: (_) => null,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to get all available statuses
class GetAvailableStatusesCommand extends Command<List<String>> {
  final StatusService _statusService;

  GetAvailableStatusesCommand(this._statusService);

  @override
  Future<List<String>> run() async {
    AppLogger.info('GetAvailableStatusesCommand: Getting all available statuses');
    final result = await _statusService.getAvailableStatuses();
    
    return result.when(
      success: (statuses) => statuses,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to get calendars grouped by status
class GetCalendarsGroupedByStatusCommand extends Command<Map<String, List<TaskCalendar>>> {
  final StatusService _statusService;

  GetCalendarsGroupedByStatusCommand(this._statusService);

  @override
  Future<Map<String, List<TaskCalendar>>> run() async {
    AppLogger.info('GetCalendarsGroupedByStatusCommand: Getting calendars grouped by status');
    final result = await _statusService.getCalendarsGroupedByStatus();
    
    return result.when(
      success: (grouped) => grouped,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to get calendars by specific status
class GetCalendarsByStatusCommand extends Command<List<TaskCalendar>> {
  final StatusService _statusService;
  final String? status;

  GetCalendarsByStatusCommand(this._statusService, this.status);

  @override
  Future<List<TaskCalendar>> run() async {
    AppLogger.info('GetCalendarsByStatusCommand: Getting calendars by status: ${status ?? "No Status"}');
    final result = await _statusService.getCalendarsByStatus(status);
    
    return result.when(
      success: (calendars) => calendars,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to get status statistics
class GetStatusStatisticsCommand extends Command<Map<String, int>> {
  final StatusService _statusService;

  GetStatusStatisticsCommand(this._statusService);

  @override
  Future<Map<String, int>> run() async {
    AppLogger.info('GetStatusStatisticsCommand: Getting status statistics');
    final result = await _statusService.getStatusStatistics();
    
    return result.when(
      success: (statistics) => statistics,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to check if status exists
class CheckStatusExistsCommand extends Command<bool> {
  final StatusService _statusService;
  final String status;

  CheckStatusExistsCommand(this._statusService, this.status);

  @override
  Future<bool> run() async {
    AppLogger.info('CheckStatusExistsCommand: Checking if status "$status" exists');
    final result = await _statusService.statusExists(status);
    
    return result.when(
      success: (exists) => exists,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to validate status name
class ValidateStatusNameCommand extends VoidCommand {
  final StatusService _statusService;
  final String status;

  ValidateStatusNameCommand(this._statusService, this.status);

  @override
  Future<void> run() async {
    AppLogger.info('ValidateStatusNameCommand: Validating status name "$status"');
    final result = _statusService.validateStatusName(status);
    
    result.when(
      success: (_) => null,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to get calendars without status
class GetCalendarsWithoutStatusCommand extends Command<List<TaskCalendar>> {
  final StatusService _statusService;

  GetCalendarsWithoutStatusCommand(this._statusService);

  @override
  Future<List<TaskCalendar>> run() async {
    AppLogger.info('GetCalendarsWithoutStatusCommand: Getting calendars without status');
    final result = await _statusService.getCalendarsWithoutStatus();
    
    return result.when(
      success: (calendars) => calendars,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to get archived calendars
class GetArchivedCalendarsCommand extends Command<List<TaskCalendar>> {
  final StatusService _statusService;

  GetArchivedCalendarsCommand(this._statusService);

  @override
  Future<List<TaskCalendar>> run() async {
    AppLogger.info('GetArchivedCalendarsCommand: Getting archived calendars');
    final result = await _statusService.getArchivedCalendars();
    
    return result.when(
      success: (calendars) => calendars,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Command to get active calendars
class GetActiveCalendarsCommand extends Command<List<TaskCalendar>> {
  final StatusService _statusService;

  GetActiveCalendarsCommand(this._statusService);

  @override
  Future<List<TaskCalendar>> run() async {
    AppLogger.info('GetActiveCalendarsCommand: Getting active calendars');
    final result = await _statusService.getActiveCalendars();
    
    return result.when(
      success: (calendars) => calendars,
      failure: (failure) => throw Exception(failure.message),
    );
  }
}

/// Factory class for creating status commands
class StatusCommandFactory {
  final StatusService _statusService;

  StatusCommandFactory(this._statusService);

  /// Create command to assign status to calendar
  AssignStatusToCalendarCommand assignStatusToCalendar(String calendarUid, String? status) {
    return AssignStatusToCalendarCommand(_statusService, calendarUid, status);
  }

  /// Create command to remove status from calendar
  RemoveStatusFromCalendarCommand removeStatusFromCalendar(String calendarUid) {
    return RemoveStatusFromCalendarCommand(_statusService, calendarUid);
  }

  /// Create command to archive calendar
  ArchiveCalendarCommand archiveCalendar(String calendarUid) {
    return ArchiveCalendarCommand(_statusService, calendarUid);
  }

  /// Create command to unarchive calendar
  UnarchiveCalendarCommand unarchiveCalendar(String calendarUid) {
    return UnarchiveCalendarCommand(_statusService, calendarUid);
  }

  /// Create command to bulk assign status
  BulkAssignStatusCommand bulkAssignStatus(List<String> calendarUids, String? status) {
    return BulkAssignStatusCommand(_statusService, calendarUids, status);
  }

  /// Create command to rename status
  RenameStatusCommand renameStatus(String oldStatus, String newStatus) {
    return RenameStatusCommand(_statusService, oldStatus, newStatus);
  }

  /// Create command to get available statuses
  GetAvailableStatusesCommand getAvailableStatuses() {
    return GetAvailableStatusesCommand(_statusService);
  }

  /// Create command to get calendars grouped by status
  GetCalendarsGroupedByStatusCommand getCalendarsGroupedByStatus() {
    return GetCalendarsGroupedByStatusCommand(_statusService);
  }

  /// Create command to get calendars by status
  GetCalendarsByStatusCommand getCalendarsByStatus(String? status) {
    return GetCalendarsByStatusCommand(_statusService, status);
  }

  /// Create command to get status statistics
  GetStatusStatisticsCommand getStatusStatistics() {
    return GetStatusStatisticsCommand(_statusService);
  }

  /// Create command to check status exists
  CheckStatusExistsCommand checkStatusExists(String status) {
    return CheckStatusExistsCommand(_statusService, status);
  }

  /// Create command to validate status name
  ValidateStatusNameCommand validateStatusName(String status) {
    return ValidateStatusNameCommand(_statusService, status);
  }

  /// Create command to get calendars without status
  GetCalendarsWithoutStatusCommand getCalendarsWithoutStatus() {
    return GetCalendarsWithoutStatusCommand(_statusService);
  }

  /// Create command to get archived calendars
  GetArchivedCalendarsCommand getArchivedCalendars() {
    return GetArchivedCalendarsCommand(_statusService);
  }

  /// Create command to get active calendars
  GetActiveCalendarsCommand getActiveCalendars() {
    return GetActiveCalendarsCommand(_statusService);
  }
} 