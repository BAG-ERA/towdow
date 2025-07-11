// Export/Import service for calendar data
// Handles zip file operations for exporting and importing calendar data

import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/task_calendar.dart';
import '../models/task.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/task_repository.dart';
import '../repositories/account_repository.dart';
import 'local_storage_service.dart';
import '../services/caldav_service.dart';

/// Result of an import operation
class ImportResult {
  final int calendarsCreated;
  final int tasksImported;
  final List<String> errors;
  final DateTime importTime;

  const ImportResult({
    required this.calendarsCreated,
    required this.tasksImported,
    required this.errors,
    required this.importTime,
  });

  bool get hasErrors => errors.isNotEmpty;
  String get summary => 'Imported $calendarsCreated calendars and $tasksImported tasks';
}

class ExportImportService {
  final CalendarRepository _calendarRepository;
  final TaskRepository _taskRepository;
  final LocalStorageService _localStorage;
  final AccountRepository _accountRepository;

  ExportImportService({
    required CalendarRepository calendarRepository,
    required TaskRepository taskRepository,
    required LocalStorageService localStorage,
    required AccountRepository accountRepository,
  }) : _calendarRepository = calendarRepository,
       _taskRepository = taskRepository,
       _localStorage = localStorage,
       _accountRepository = accountRepository;

  /// Export all calendars to a zip file
  /// Returns the path to the created zip file
  Future<Result<String>> exportCalendars() async {
    try {
      AppLogger.info('ExportImportService: Starting calendar export');
      
      // Get all project calendars
      final calendarsResult = await _calendarRepository.getProjectCalendars();
      final calendars = calendarsResult.when(
        success: (calendars) => calendars,
        failure: (failure) {
          AppLogger.error('ExportImportService: Failed to get calendars', failure.exception, failure.stackTrace);
          return <TaskCalendar>[];
        },
      );

      if (calendars.isEmpty) {
        return Result.failure(Failure(
          message: 'No calendars found to export',
        ));
      }

      // Create temporary directory for export
      final tempDir = await Directory.systemTemp.createTemp('towdow_export_');
      final archive = Archive();

      // Export each calendar
      for (final calendar in calendars) {
        await _exportCalendar(calendar, archive, tempDir.path);
      }

      // Create zip file
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) {
        return Result.failure(Failure(
          message: 'Failed to create zip file',
        ));
      }

      // Save zip file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipPath = path.join(tempDir.path, 'towdow-export-$timestamp.zip');
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);

      AppLogger.info('ExportImportService: Export completed successfully to $zipPath');
      return Result.success(zipPath);
    } catch (e, stackTrace) {
      AppLogger.error('ExportImportService: Export failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'Export failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Export a single calendar with all its tasks
  Future<void> _exportCalendar(TaskCalendar calendar, Archive archive, String tempDirPath) async {
    AppLogger.info('ExportImportService: Exporting calendar ${calendar.displayName}');
    
    // Get all tasks for this calendar
    final tasksResult = await _taskRepository.getByProject(calendar.uid);
    final tasks = tasksResult.when(
      success: (tasks) => tasks,
      failure: (failure) {
        AppLogger.warning('ExportImportService: Failed to get tasks for ${calendar.displayName}', failure.exception, failure.stackTrace);
        return <Task>[];
      },
    );

    // Create calendar content (VCALENDAR with all VTODOs)
    final calendarContent = _createCalendarContent(calendar, tasks);
    
    // Add calendar file to archive
    final fileName = '${calendar.displayName.replaceAll(RegExp(r'[^\w\s-]'), '_')}.ics';
    final archiveFile = ArchiveFile(fileName, calendarContent.length, calendarContent);
    archive.addFile(archiveFile);
  }

  /// Create VCALENDAR content with all VTODOs
  String _createCalendarContent(TaskCalendar calendar, List<Task> tasks) {
    final buffer = StringBuffer();
    
    // VCALENDAR header
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//FlowIt//FlowIt CalDAV//EN');
    buffer.writeln('X-WR-CALNAME;VALUE=TEXT:${_escapeCalendarText(calendar.displayName)}');
    buffer.writeln('X-WR-CALDESC;VALUE=TEXT:${_escapeCalendarText(calendar.description)}');
    
    // Add all VTODOs
    for (final task in tasks) {
      buffer.writeln(_createVTODOContent(task));
    }
    
    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  /// Create VTODO content for a single task
  String _createVTODOContent(Task task) {
    final buffer = StringBuffer();
    
    buffer.writeln('BEGIN:VTODO');
    buffer.writeln('UID:${task.uid}');
    buffer.writeln('DTSTAMP:${_formatDateTime(task.dtstamp)}');
    buffer.writeln('CREATED:${_formatDateTime(task.created)}');
    buffer.writeln('LAST-MODIFIED:${_formatDateTime(task.lastModified)}');
    buffer.writeln('SUMMARY:${_escapeCalendarText(task.summary)}');
    
    if (task.description.isNotEmpty) {
      buffer.writeln('DESCRIPTION:${_escapeCalendarText(task.description)}');
    }
    
    if (task.due != null) {
      buffer.writeln('DUE:${_formatDateTime(task.due!)}');
    }
    
    buffer.writeln('STATUS:${task.status}');
    buffer.writeln('PERCENT-COMPLETE:${task.percentComplete}');
    
    if (task.categories.isNotEmpty) {
      buffer.writeln('CATEGORIES:${task.categories.map(_escapeCalendarText).join(',')}');
    }
    
    if (task.organizer != null) {
      buffer.writeln('ORGANIZER:mailto:${task.organizer}');
    }
    
    // FlowIt-specific extensions
    buffer.writeln('X-FLOWIT-TYPE:task');
    buffer.writeln('X-FLOWIT-VALIDATOR:${_escapeCalendarText(task.flowitValidator)}');
    buffer.writeln('X-FLOWIT-REQUIREMENT:${task.flowitRequirement}');
    
    if (task.flowitTemplate != null) {
      buffer.writeln('X-FLOWIT-TEMPLATE:${task.flowitTemplate}');
    }
    
    buffer.writeln('END:VTODO');
    return buffer.toString();
  }

  /// Helper method to format DateTime for iCalendar
  String _formatDateTime(DateTime dateTime) {
    return dateTime.toUtc().toIso8601String().replaceAll(RegExp(r'[:\-]'), '').replaceAll('.000Z', 'Z');
  }

  /// Helper method to escape calendar text
  String _escapeCalendarText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;');
  }

  /// Import calendars from a zip file
  /// Returns import statistics
  Future<Result<ImportResult>> importCalendars(String zipPath) async {
    try {
      AppLogger.info('ExportImportService: Starting calendar import from $zipPath');
      
      // Read the zip file
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) {
        return Result.failure(Failure(
          message: 'Import file not found: $zipPath',
        ));
      }

      final zipBytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);
      
      if (archive.isEmpty) {
        return Result.failure(Failure(
          message: 'Import file is empty or invalid',
        ));
      }

      int calendarsCreated = 0;
      int tasksImported = 0;
      final errors = <String>[];

      // Process each file in the zip
      for (final file in archive) {
        if (!file.isFile || !file.name.endsWith('.ics')) {
          continue;
        }

        try {
          final icsContent = String.fromCharCodes(file.content as List<int>);
          final importStats = await _importCalendarFromICS(icsContent);
          calendarsCreated += importStats.calendarsCreated;
          tasksImported += importStats.tasksImported;
          errors.addAll(importStats.errors);
        } catch (e, stackTrace) {
          AppLogger.error('ExportImportService: Failed to import file ${file.name}', e, stackTrace);
          errors.add('Failed to import ${file.name}: $e');
        }
      }

      final result = ImportResult(
        calendarsCreated: calendarsCreated,
        tasksImported: tasksImported,
        errors: errors,
        importTime: DateTime.now(),
      );

      AppLogger.info('ExportImportService: Import completed - $calendarsCreated calendars, $tasksImported tasks');
      return Result.success(result);
    } catch (e, stackTrace) {
      AppLogger.error('ExportImportService: Import failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'Import failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Import a single calendar from ICS content
  Future<ImportResult> _importCalendarFromICS(String icsContent) async {
    final lines = icsContent.split('\n');
    final calendarName = _extractCalendarName(lines);
    final calendarDescription = _extractCalendarDescription(lines);
    
    AppLogger.info('ExportImportService: Importing calendar: $calendarName');

    // Create calendar on CalDAV server *without* assuming the final path.
    // The server decides where the collection is actually created and the
    // returned TaskCalendar contains the authoritative path.

    final placeholderCalendar = TaskCalendarFactory.createNew(
      path: '',
      displayName: calendarName,
      description: calendarDescription,
    );

    final calendarResult = await _createCalendarOnServer(placeholderCalendar);

    return await calendarResult.when(
      success: (createdCalendar) async {
        final calendarPath = createdCalendar.path;

        // Extract and import VTODO items
        final vtodos = _extractVTODOs(icsContent);
        int tasksImported = 0;
        final errors = <String>[];

        for (final vtodo in vtodos) {
          try {
            final task = _parseVTODO(vtodo);
            if (task != null) {
              final taskResult = await _createTaskOnServer(task, calendarPath);
              await taskResult.when(
                success: (_) {
                  tasksImported++;
                },
                failure: (failure) {
                  errors.add('Failed to import task ${task.summary}: ${failure.message}');
                },
              );
            }
          } catch (e, stackTrace) {
            AppLogger.error('ExportImportService: Failed to parse VTODO', e, stackTrace);
            errors.add('Failed to parse VTODO: $e');
          }
        }

        return ImportResult(
          calendarsCreated: 1,
          tasksImported: tasksImported,
          errors: errors,
          importTime: DateTime.now(),
        );
      },
      failure: (failure) {
        return ImportResult(
          calendarsCreated: 0,
          tasksImported: 0,
          errors: [failure.message],
          importTime: DateTime.now(),
        );
      },
    );
  }

  /// Extract calendar name from X-WR-CALNAME property
  String _extractCalendarName(List<String> lines) {
    for (final line in lines) {
      if (line.startsWith('X-WR-CALNAME')) {
        final colonIndex = line.indexOf(':');
        if (colonIndex != -1) {
          return _unescapeCalendarText(line.substring(colonIndex + 1).trim());
        }
      }
    }
    return 'Imported Calendar';
  }

  /// Extract calendar description from X-WR-CALDESC property
  String _extractCalendarDescription(List<String> lines) {
    for (final line in lines) {
      if (line.startsWith('X-WR-CALDESC')) {
        final colonIndex = line.indexOf(':');
        if (colonIndex != -1) {
          return _unescapeCalendarText(line.substring(colonIndex + 1).trim());
        }
      }
    }
    return 'Imported from FlowIt';
  }

  /// Extract VTODO blocks from ICS content
  List<String> _extractVTODOs(String icsContent) {
    final vtodos = <String>[];
    final lines = icsContent.split('\n');
    bool inVTODO = false;
    final currentVTODO = StringBuffer();

    for (final line in lines) {
      if (line.trim() == 'BEGIN:VTODO') {
        inVTODO = true;
        currentVTODO.clear();
        currentVTODO.writeln(line);
      } else if (line.trim() == 'END:VTODO') {
        currentVTODO.writeln(line);
        vtodos.add(currentVTODO.toString());
        inVTODO = false;
      } else if (inVTODO) {
        currentVTODO.writeln(line);
      }
    }

    return vtodos;
  }

  /// Parse a VTODO block into a Task object
  Task? _parseVTODO(String vtodoContent) {
    try {
      final lines = vtodoContent.split('\n');
      final properties = <String, String>{};

      for (final line in lines) {
        if (line.contains(':') && !line.startsWith('BEGIN:') && !line.startsWith('END:')) {
          final colonIndex = line.indexOf(':');
          final key = line.substring(0, colonIndex).trim();
          final value = line.substring(colonIndex + 1).trim();
          properties[key] = _unescapeCalendarText(value);
        }
      }

      // Extract required properties
      final uid = properties['UID'];
      final summary = properties['SUMMARY'];
      
      if (uid == null || summary == null) {
        AppLogger.warning('ExportImportService: VTODO missing required properties');
        return null;
      }

      // Parse dates
      final dtstamp = _parseDateTime(properties['DTSTAMP']) ?? DateTime.now();
      final created = _parseDateTime(properties['CREATED']) ?? dtstamp;
      final lastModified = _parseDateTime(properties['LAST-MODIFIED']) ?? dtstamp;
      final due = _parseDateTime(properties['DUE']);

      // Parse other properties
      final description = properties['DESCRIPTION'] ?? '';
      final status = properties['STATUS'] ?? 'NEEDS-ACTION';
      final percentComplete = int.tryParse(properties['PERCENT-COMPLETE'] ?? '0') ?? 0;
      final organizer = properties['ORGANIZER']?.replaceAll('mailto:', '');
      
      // Parse categories
      final categoriesStr = properties['CATEGORIES'];
      final categories = categoriesStr?.split(',').map((c) => c.trim()).toList() ?? <String>[];

      // Parse FlowIt-specific properties
      final flowitValidator = properties['X-FLOWIT-VALIDATOR'] ?? '[]';
      final flowitRequirement = properties['X-FLOWIT-REQUIREMENT'] ?? '{}';
      final flowitTemplate = properties['X-FLOWIT-TEMPLATE'];

      return Task(
        uid: uid,
        summary: summary,
        description: description,
        dtstamp: dtstamp,
        created: created,
        lastModified: lastModified,
        due: due,
        status: status,
        percentComplete: percentComplete,
        organizer: organizer,
        categories: categories,
        flowitValidator: flowitValidator,
        flowitRequirement: flowitRequirement,
        flowitTemplate: flowitTemplate,
        attendees: [], // TODO: Parse attendees if needed
      );
    } catch (e, stackTrace) {
      AppLogger.error('ExportImportService: Failed to parse VTODO', e, stackTrace);
      return null;
    }
  }

  /// Helper method to unescape calendar text
  String _unescapeCalendarText(String text) {
    return text
        .replaceAll('\\n', '\n')
        .replaceAll('\\r', '\r')
        .replaceAll('\\,', ',')
        .replaceAll('\\;', ';')
        .replaceAll('\\\\', '\\');
  }

  /// Helper method to parse DateTime from iCalendar format
  DateTime? _parseDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return null;
    try {
      // Handle iCalendar format: 20250101T090000Z
      if (dateTimeStr.endsWith('Z')) {
        final cleaned = dateTimeStr.substring(0, dateTimeStr.length - 1);
        final year = int.parse(cleaned.substring(0, 4));
        final month = int.parse(cleaned.substring(4, 6));
        final day = int.parse(cleaned.substring(6, 8));
        final hour = int.parse(cleaned.substring(9, 11));
        final minute = int.parse(cleaned.substring(11, 13));
        final second = int.parse(cleaned.substring(13, 15));
        return DateTime.utc(year, month, day, hour, minute, second);
      }
    } catch (e) {
      AppLogger.warning('ExportImportService: Failed to parse datetime: $dateTimeStr');
    }
    return null;
  }

  // No longer needed – we now rely on the server-returned calendar path.
  // If another part of the service still requires a username, consider
  // injecting it from AccountRepository instead of hard-coding.

  /// Create calendar on CalDAV server
  Future<Result<TaskCalendar>> _createCalendarOnServer(TaskCalendar calendar) async {
    try {
      AppLogger.info('ExportImportService: Creating calendar on server: ${calendar.displayName}');
      
      // Get the CalDAV service from the repository
      final accountResult = await _accountRepository.getActiveAccount();
      final account = accountResult.when(
        success: (account) => account,
        failure: (failure) => throw Exception('No active account: ${failure.message}'),
      );
      if (account == null) {
        return Result.failure(Failure(message: 'No active account found'));
      }
      final caldavService = CalDAVService(account: account);
      
      // Create the calendar using CalDAV MKCOL method
      final result = await caldavService.createCalendar(
        displayName: calendar.displayName,
        description: calendar.description,
        uid: calendar.uid,
      );

      // Simply propagate the Result coming from caldavService so that
      // callers receive the newly created TaskCalendar (with the correct
      // server-generated path).
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('ExportImportService: Exception creating calendar', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to create calendar: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Create task on CalDAV server
  Future<Result<void>> _createTaskOnServer(Task task, String calendarPath) async {
    try {
      AppLogger.info('ExportImportService: Creating task on server: ${task.summary}');
      
      // Get the CalDAV service from the repository
      final accountResult = await _accountRepository.getActiveAccount();
      final account = accountResult.when(
        success: (account) => account,
        failure: (failure) => throw Exception('No active account: ${failure.message}'),
      );
      if (account == null) {
        return Result.failure(Failure(message: 'No active account found'));
      }
      final caldavService = CalDAVService(account: account);
      
      // Create the task using CalDAV PUT method
      final result = await caldavService.createTask(task, calendarPath: calendarPath);
      
      return result.when(
        success: (_) {
          AppLogger.info('ExportImportService: Task created successfully: ${task.summary}');
          return Result.success(null);
        },
        failure: (failure) {
          AppLogger.error('ExportImportService: Failed to create task ${task.summary}: ${failure.message}');
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ExportImportService: Exception creating task', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to create task: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }
} 