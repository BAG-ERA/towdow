// VTODO parser for CalDAV operations
// Centralizes all VTODO serialization and parsing logic including attendee handling

import 'dart:convert';
import '../../../core/logger.dart';
import '../../models/task.dart';
import '../../models/attendee.dart';

class VTODOParser {
  /// Convert FlowIt Task to iCalendar VTODO format - RFC 5545
  static String serializeTask(Task task, {String? etag}) {
    final vtodo = StringBuffer();
    vtodo.writeln('BEGIN:VCALENDAR');
    vtodo.writeln('VERSION:2.0');
    vtodo.writeln('PRODID:-//FlowIt//FlowIt CalDAV//EN');
    vtodo.writeln('BEGIN:VTODO');
    vtodo.writeln('UID:${task.uid}');
    vtodo.writeln('DTSTAMP:${_formatDateTime(task.dtstamp)}');
    vtodo.writeln('CREATED:${_formatDateTime(task.created)}');
    vtodo.writeln('LAST-MODIFIED:${_formatDateTime(task.lastModified)}');
    vtodo.writeln('SUMMARY:${_escapeCalendarText(task.summary)}');
    
    if (task.description.isNotEmpty) {
      vtodo.writeln('DESCRIPTION:${_escapeCalendarText(task.description)}');
    }
    
    if (task.due != null) {
      vtodo.writeln('DUE:${_formatDateTime(task.due!)}');
    }
    
    // Task completion status
    vtodo.writeln('STATUS:${task.status}');
    vtodo.writeln('PERCENT-COMPLETE:${task.percentComplete}');
    
    // Categories
    if (task.categoryIds.isNotEmpty) {
      vtodo.writeln('CATEGORIES:${task.categoryIds.join(',')}');
    }
    
    // Organizer (RFC 5545)
    if (task.organizer != null) {
      vtodo.writeln('ORGANIZER:mailto:${task.organizer}');
    }
    
    // Attendees (RFC 5545)
    for (final attendee in task.attendees) {
      vtodo.writeln(_serializeAttendee(attendee));
    }
    
    // Attachments (RFC 5545 ATTACH field with FlowIt extensions)
    final attachments = _parseAttachments(task.attachments);
    for (final attachment in attachments) {
      vtodo.writeln(_serializeAttachment(attachment));
    }
    
    // Media Attachments (RFC 5545 ATTACH field with FlowIt media extensions)
    final mediaAttachments = _parseAttachments(task.mediaAttachments);
    for (final mediaAttachment in mediaAttachments) {
      vtodo.writeln(_serializeMediaAttachment(mediaAttachment));
    }
    
    // FlowIt-specific extensions
    vtodo.writeln('X-FLOWIT-TYPE:task');
    vtodo.writeln('X-FLOWIT-VALIDATOR:${_escapeCalendarText(task.flowitValidator)}');
    vtodo.writeln('X-FLOWIT-REQUIREMENT:${task.flowitRequirement}');
    
    if (task.flowitTemplate != null) {
      vtodo.writeln('X-FLOWIT-TEMPLATE:${task.flowitTemplate}');
    }
    
    if (task.flowitReversalTask != null) {
      vtodo.writeln('X-FLOWIT-REVERSALTASK:${task.flowitReversalTask}');
    }
    
    if (etag != null) {
      vtodo.writeln('X-FLOWIT-ETAG:$etag');
    }
    
    vtodo.writeln('END:VTODO');
    vtodo.writeln('END:VCALENDAR');
    
    return vtodo.toString();
  }

  /// Parse a single VTODO string into a Task object
  static Task? parseVTODO(String vtodo) {
    try {
      // Handle line folding according to RFC 5545 BEFORE trimming lines
      // Lines can be continued by starting the next line with a space or tab
      AppLogger.debug('VTODOParser: VTODO before unfolding: \n$vtodo');

      // Use regex to properly handle line folding (RFC 5545)
      // Pattern: newline followed by one or more whitespace characters
      final unfoldedVtodo = vtodo.replaceAll(RegExp(r'\r?\n[\s]+'), '');

      AppLogger.debug('VTODOParser: VTODO after unfolding: \n$unfoldedVtodo');
      final lines = unfoldedVtodo.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty);
      
      String? uid, summary, description, status, organizer;
      DateTime? created, lastModified, due;
      List<String> categories = [];
      List<Attendee> attendees = [];
      List<Map<String, dynamic>> attachments = [];
      List<Map<String, dynamic>> mediaAttachments = [];
      String? flowitValidator;
      int percentComplete = 0;
      
      for (final line in lines) {
        if (line.startsWith('UID:')) {
          uid = line.substring(4);
        } else if (line.startsWith('SUMMARY:')) {
          summary = _unescapeCalendarText(line.substring(8));
        } else if (line.startsWith('DESCRIPTION:')) {
          description = _unescapeCalendarText(line.substring(12));
        } else if (line.startsWith('STATUS:')) {
          status = line.substring(7);
        } else if (line.startsWith('CREATED:')) {
          created = _parseDateTime(line.substring(8));
        } else if (line.startsWith('LAST-MODIFIED:')) {
          lastModified = _parseDateTime(line.substring(14));
        } else if (line.startsWith('DUE:')) {
          due = _parseDateTime(line.substring(4));
        } else if (line.startsWith('CATEGORIES:')) {
          categories = line.substring(11).split(',').where((cat) => cat.trim().isNotEmpty).toList();
        } else if (line.startsWith('PERCENT-COMPLETE:')) {
          percentComplete = int.tryParse(line.substring(17)) ?? 0;
        } else if (line.startsWith('X-FLOWIT-VALIDATOR:')) {
          flowitValidator = _unescapeCalendarText(line.substring(19));
        } else if (line.startsWith('ORGANIZER:')) {
          // Parse organizer (remove mailto: prefix if present)
          organizer = line.substring(10);
          if (organizer.startsWith('mailto:')) {
            organizer = organizer.substring(7);
          }
          AppLogger.debug('VTODOParser: Found organizer: $organizer');
        } else if (line.startsWith('ATTENDEE:') || line.startsWith('ATTENDEE;')) {
          // Parse attendee with parameters according to RFC 5545
          final attendee = _parseAttendee(line);
          if (attendee != null) {
            // Check if attendee already exists (by email)
            final existingIndex = attendees.indexWhere((a) => a.email == attendee.email);
            if (existingIndex >= 0) {
              // Update existing attendee
              attendees[existingIndex] = attendee;
            } else {
              // Add new attendee
              attendees.add(attendee);
            }
            AppLogger.debug('VTODOParser: Added attendee: ${attendee.email} (${attendee.displayName ?? 'no name'})');
          }
        } else if (line.startsWith('ATTACH:') || line.startsWith('ATTACH;')) {
          // Parse attachment with parameters according to RFC 5545
          final attachment = _parseAttachment(line);
          if (attachment != null) {
            // Check if this is a media attachment
            final attachType = attachment['attachType'] as String?;
            if (attachType == 'media') {
              mediaAttachments.add(attachment);
              AppLogger.debug('VTODOParser: Added media attachment: ${attachment['filename'] ?? attachment['uri'] ?? 'unknown'}');
            } else {
              attachments.add(attachment);
              AppLogger.debug('VTODOParser: Added attachment: ${attachment['filename'] ?? attachment['uri'] ?? 'unknown'}');
            }
          }
        }
      }
      
      if (uid != null && summary != null) {
        AppLogger.debug('VTODOParser: Successfully parsed VTODO: $uid');
        AppLogger.debug('VTODOParser: - Summary: $summary');
        AppLogger.debug('VTODOParser: - Organizer: $organizer');
        AppLogger.debug('VTODOParser: - Attendees count: ${attendees.length}');
        AppLogger.debug('VTODOParser: - Attachments count: ${attachments.length}');
        AppLogger.debug('VTODOParser: - Media attachments count: ${mediaAttachments.length}');
        for (int i = 0; i < attendees.length; i++) {
          final attendee = attendees[i];
          AppLogger.debug('VTODOParser: - Attendee $i: ${attendee.email} (${attendee.displayName ?? 'no name'}) - ${attendee.status.value}');
        }
        
        return Task(
          uid: uid,
          summary: summary,
          description: description ?? '',
          status: status ?? 'NEEDS-ACTION',
          lastModified: lastModified ?? DateTime.now(),
          created: created ?? DateTime.now(),
          dtstamp: DateTime.now(), // Required by iCalendar specification
          due: due,
          categoryIds: categories,
          organizer: organizer,
          attendees: attendees,
          percentComplete: percentComplete,
          flowitValidator: flowitValidator ?? 'default',
          attachments: _serializeAttachments(attachments),
          mediaAttachments: _serializeAttachments(mediaAttachments),
        );
      }
    } catch (e) {
      AppLogger.error('VTODOParser: Failed to parse VTODO', e, StackTrace.current);
    }
    
    return null;
  }

  /// Parse multiple VTODO objects from CalDAV response
  static List<Task> parseTasksFromResponse(String xmlResponse) {
    final tasks = <Task>[];
    
    try {
      // Simple regex parsing - extract VTODO blocks from XML response
      final vtodoPattern = RegExp(r'BEGIN:VTODO.*?END:VTODO', dotAll: true);
      final vtodos = vtodoPattern.allMatches(xmlResponse);
      
      for (final match in vtodos) {
        final vtodoContent = match.group(0)!;
        final task = parseVTODO(vtodoContent);
        if (task != null) {
          tasks.add(task);
        }
      }
    } catch (e) {
      AppLogger.error('VTODOParser: Failed to parse VTODO response', e, StackTrace.current);
    }
    
    return tasks;
  }

  /// Parse VTODO from calendar data (for sync operations)
  static Task? parseVTODOFromCalendarData(String calendarData) {
    try {
      // Extract VTODO block from calendar data
      final vtodoPattern = RegExp(r'BEGIN:VTODO.*?END:VTODO', dotAll: true);
      final match = vtodoPattern.firstMatch(calendarData);
      
      if (match != null) {
        final vtodoContent = match.group(0)!;
        return parseVTODO(vtodoContent);
      }
    } catch (e) {
      AppLogger.error('VTODOParser: Failed to parse VTODO from calendar data', e, StackTrace.current);
    }
    return null;
  }

  /// Format DateTime to iCalendar format
  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.toUtc().toIso8601String()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .replaceAll('.', '')
        .substring(0, 15)}Z';
  }

  /// Parse DateTime from iCalendar format
  static DateTime? _parseDateTime(String dateTimeStr) {
    try {
      // Handle both YYYYMMDDTHHMMSSZ and YYYYMMDD formats
      if (dateTimeStr.endsWith('Z')) {
        final cleanStr = dateTimeStr.substring(0, dateTimeStr.length - 1);
        if (cleanStr.length >= 15) {
          return DateTime.utc(
            int.parse(cleanStr.substring(0, 4)),
            int.parse(cleanStr.substring(4, 6)),
            int.parse(cleanStr.substring(6, 8)),
            int.parse(cleanStr.substring(9, 11)),
            int.parse(cleanStr.substring(11, 13)),
            int.parse(cleanStr.substring(13, 15)),
          );
        }
      }
      // Try ISO format as fallback
      return DateTime.tryParse(dateTimeStr);
    } catch (e) {
      AppLogger.error('VTODOParser: Failed to parse date time: $dateTimeStr', e, StackTrace.current);
      return null;
    }
  }

  /// Escape calendar text according to RFC 5545
  static String _escapeCalendarText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;')
        .replaceAll('\n', '\\n');
  }

  /// Unescape calendar text according to RFC 5545 and decode HTML entities
  static String _unescapeCalendarText(String text) {
    return text
        // First handle HTML entities (common in CalDAV responses)
        .replaceAll('&#13;', '') // Remove carriage return entities
        .replaceAll('&#10;', '\n') // Line feed entity to newline
        .replaceAll('&#9;', '\t') // Tab entity
        .replaceAll('&lt;', '<') // Less than entity
        .replaceAll('&gt;', '>') // Greater than entity
        .replaceAll('&amp;', '&') // Ampersand entity (must be last)
        .replaceAll('&quot;', '"') // Quote entity
        .replaceAll('&apos;', "'") // Apostrophe entity
        // Then handle standard iCalendar escaping (RFC 5545)
        .replaceAll('\\n', '\n')
        .replaceAll('\\;', ';')
        .replaceAll('\\,', ',')
        .replaceAll('\\\\', '\\');
  }

  /// Serialize an Attendee object to RFC 5545 ATTENDEE line
  static String _serializeAttendee(Attendee attendee) {
    final parameters = <String>[];
    
    // Add display name (CN parameter)
    if (attendee.displayName != null && attendee.displayName!.isNotEmpty) {
      parameters.add('CN=${attendee.displayName}');
    }
    
    // Add participation status (PARTSTAT parameter)
    if (attendee.status != AttendeeStatus.needsAction) {
      parameters.add('PARTSTAT=${attendee.status.value}');
    }
    
    // Add role (ROLE parameter)
    if (attendee.role != AttendeeRole.requiredParticipant) {
      parameters.add('ROLE=${attendee.role.value}');
    }
    
    // Add RSVP parameter
    if (attendee.rsvpRequested) {
      parameters.add('RSVP=TRUE');
    }
    
    // Add calendar user type (CUTYPE parameter)
    if (attendee.userType != CalendarUserType.individual) {
      parameters.add('CUTYPE=${attendee.userType.value}');
    }
    
    // Add delegation information
    if (attendee.delegatedFrom != null) {
      parameters.add('DELEGATED-FROM=${attendee.delegatedFrom}');
    }
    
    if (attendee.delegatedTo != null) {
      parameters.add('DELEGATED-TO=${attendee.delegatedTo}');
    }
    
    // Add schedule agent
    if (attendee.scheduleAgent != null) {
      parameters.add('SCHEDULE-AGENT=${attendee.scheduleAgent}');
    }
    
    // Add group membership
    if (attendee.memberOf != null) {
      parameters.add('MEMBER=${attendee.memberOf}');
    }
    
    // Build the ATTENDEE line
    final paramString = parameters.isNotEmpty ? ';${parameters.join(';')}' : '';
    return 'ATTENDEE$paramString:mailto:${attendee.email}';
  }

  /// Parse an ATTENDEE line according to RFC 5545
  static Attendee? _parseAttendee(String line) {
    try {
      // Split line into parameters and value parts
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) return null;
      
      final parametersPart = line.substring(0, colonIndex);
      final valuePart = line.substring(colonIndex + 1);
      
      // Extract email from value part
      String email = valuePart;
      if (email.startsWith('mailto:')) {
        email = email.substring(7);
      }
      if (email.isEmpty) return null;
      
      // Parse parameters
      final parameters = <String, String>{};
      if (parametersPart.contains(';')) {
        final paramList = parametersPart.split(';').skip(1); // Skip 'ATTENDEE' part
        for (final param in paramList) {
          final equalIndex = param.indexOf('=');
          if (equalIndex > 0) {
            final key = param.substring(0, equalIndex).trim().toUpperCase();
            final value = param.substring(equalIndex + 1).trim();
            // Remove quotes if present
            parameters[key] = value.replaceAll('"', '');
          }
        }
      }
      
      // Build Attendee object
      return Attendee(
        email: email,
        displayName: parameters['CN'],
        status: AttendeeStatus.fromString(parameters['PARTSTAT'] ?? 'NEEDS-ACTION'),
        role: AttendeeRole.fromString(parameters['ROLE'] ?? 'REQ-PARTICIPANT'),
        rsvpRequested: parameters['RSVP']?.toUpperCase() == 'TRUE',
        userType: CalendarUserType.fromString(parameters['CUTYPE'] ?? 'INDIVIDUAL'),
        delegatedFrom: parameters['DELEGATED-FROM'],
        delegatedTo: parameters['DELEGATED-TO'],
        scheduleAgent: parameters['SCHEDULE-AGENT'],
        memberOf: parameters['MEMBER'],
      );
    } catch (e) {
      AppLogger.error('VTODOParser: Failed to parse attendee line: $line', e, StackTrace.current);
      return null;
    }
  }

  /// Serialize an attachment object to RFC 5545 ATTACH line with FlowIt extensions
  static String _serializeAttachment(Map<String, dynamic> attachment) {
    final parameters = <String>[];
    final uri = attachment['uri'] as String? ?? '';
    
    // Add FlowIt-specific parameters
    final attachType = attachment['attachType'] as String?;
    if (attachType != null) {
      parameters.add('X-FLOWIT-ATTACHTYPE=$attachType');
    }
    
    final aesKey = attachment['aesKey'] as String?;
    if (aesKey != null) {
      parameters.add('X-FLOWIT-AESKEY=$aesKey');
    }
    
    // Add standard ATTACH parameters
    final filename = attachment['filename'] as String?;
    if (filename != null) {
      parameters.add('FILENAME=${_escapeCalendarText(filename)}');
    }
    
    final fmttype = attachment['fmttype'] as String?;
    if (fmttype != null) {
      parameters.add('FMTTYPE=$fmttype');
    }
    
    final size = attachment['size'] as int?;
    if (size != null) {
      parameters.add('SIZE=$size');
    }
    
    // Build the ATTACH line
    final paramString = parameters.isNotEmpty ? ';${parameters.join(';')}' : '';
    return 'ATTACH$paramString:$uri';
  }
  
  /// Serialize a media attachment object to RFC 5545 ATTACH line with FlowIt media extensions
  static String _serializeMediaAttachment(Map<String, dynamic> attachment) {
    final parameters = <String>[];
    final uri = attachment['uri'] as String? ?? '';
    
    // Add FlowIt-specific media parameters
    parameters.add('X-FLOWIT-ATTACHTYPE=media');
    
    final aesKey = attachment['aesKey'] as String?;
    if (aesKey != null) {
      parameters.add('X-FLOWIT-AESKEY=$aesKey');
    }
    
    final mediaType = attachment['mediaType'] as String?;
    if (mediaType != null) {
      parameters.add('X-FLOWIT-MEDIATYPE=$mediaType');
    }
    
    // Add standard ATTACH parameters
    final filename = attachment['filename'] as String?;
    if (filename != null) {
      parameters.add('FILENAME=${_escapeCalendarText(filename)}');
    }
    
    final fmttype = attachment['fmttype'] as String?;
    if (fmttype != null) {
      parameters.add('FMTTYPE=$fmttype');
    }
    
    final size = attachment['size'] as int?;
    if (size != null) {
      parameters.add('SIZE=$size');
    }
    
    // Build the ATTACH line
    final paramString = parameters.isNotEmpty ? ';${parameters.join(';')}' : '';
    return 'ATTACH$paramString:$uri';
  }
  
  /// Parse an ATTACH line according to RFC 5545 with FlowIt extensions
  static Map<String, dynamic>? _parseAttachment(String line) {
    try {
      // Split line into parameters and value parts
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) return null;
      
      final parametersPart = line.substring(0, colonIndex);
      final valuePart = line.substring(colonIndex + 1);
      
      // Extract URI from value part
      final uri = valuePart.trim();
      if (uri.isEmpty) return null;
      
      // Parse parameters
      final parameters = <String, String>{};
      if (parametersPart.contains(';')) {
        final paramList = parametersPart.split(';').skip(1); // Skip 'ATTACH' part
        for (final param in paramList) {
          final equalIndex = param.indexOf('=');
          if (equalIndex > 0) {
            final key = param.substring(0, equalIndex).trim().toUpperCase();
            final value = param.substring(equalIndex + 1).trim();
            // Remove quotes if present and unescape
            parameters[key] = _unescapeCalendarText(value.replaceAll('"', ''));
          }
        }
      }
      
      // Build attachment object
      final attachment = <String, dynamic>{
        'uri': uri,
      };
      
      // Add standard parameters
      if (parameters['FILENAME'] != null) {
        attachment['filename'] = parameters['FILENAME'];
      }
      if (parameters['FMTTYPE'] != null) {
        attachment['fmttype'] = parameters['FMTTYPE'];
      }
      if (parameters['SIZE'] != null) {
        final size = int.tryParse(parameters['SIZE']!);
        if (size != null) {
          attachment['size'] = size;
        }
      }
      
      // Add FlowIt-specific parameters
      if (parameters['X-FLOWIT-ATTACHTYPE'] != null) {
        attachment['attachType'] = parameters['X-FLOWIT-ATTACHTYPE'];
      }
      if (parameters['X-FLOWIT-AESKEY'] != null) {
        attachment['aesKey'] = parameters['X-FLOWIT-AESKEY'];
      }
      if (parameters['X-FLOWIT-MEDIATYPE'] != null) {
        attachment['mediaType'] = parameters['X-FLOWIT-MEDIATYPE'];
      }
      
      return attachment;
    } catch (e) {
      AppLogger.error('VTODOParser: Failed to parse attachment line: $line', e, StackTrace.current);
      return null;
    }
  }
  
  /// Parse attachments JSON array
  static List<Map<String, dynamic>> _parseAttachments(String attachmentsJson) {
    try {
      if (attachmentsJson.isEmpty || attachmentsJson == '[]') {
        return [];
      }
      
      final decoded = jsonDecode(attachmentsJson);
      if (decoded is List) {
        return decoded.map<Map<String, dynamic>>((attachment) {
          return attachment is Map<String, dynamic> ? attachment : <String, dynamic>{};
        }).toList();
      }
      
      return [];
    } catch (e) {
      AppLogger.error('VTODOParser: Failed to parse attachments JSON', e, StackTrace.current);
      return [];
    }
  }
  
  /// Serialize attachments to JSON array
  static String _serializeAttachments(List<Map<String, dynamic>> attachments) {
    try {
      return jsonEncode(attachments);
    } catch (e) {
      AppLogger.error('VTODOParser: Failed to serialize attachments', e, StackTrace.current);
      return '[]';
    }
  }
} 