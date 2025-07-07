// VEVENT parser for external CalDAV operations
// Centralizes all VEVENT parsing logic for external calendar integration
// Based on RFC 5545 specification

import '../../../core/logger.dart';
import '../../models/calendar_event.dart';
import '../../models/attendee.dart';
import 'package:timezone/timezone.dart' as tz;

class VEventParser {
  /// Parse a single VEVENT string into a CalendarEvent object
  static CalendarEvent? parseVEvent(String vevent, String sourceCalendarUid, String accountId) {
    try {
      AppLogger.debug('VEventParser: VEVENT after unfolding:');
      AppLogger.debug(vevent);

      // Unfold the VEVENT (remove line continuations)
      final unfoldedVevent = _unfoldCalendarText(vevent);
      final lines = unfoldedVevent.split('\n');

      String? uid;
      String? summary;
      DateTime? dtstart;
      DateTime? dtend;
      bool isAllDay = false;
      String? description;
      String? location;
      String? organizer;
      List<Attendee> attendees = [];
      String? recurrenceRule;
      String? recurrenceId;
      List<DateTime> recurrenceDates = [];
      List<DateTime> exceptionDates = [];

      for (String line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        if (line.startsWith('UID:')) {
          uid = _unescapeCalendarText(line.substring(4));
        } else if (line.startsWith('SUMMARY:')) {
          summary = _unescapeCalendarText(line.substring(8));
        } else if (line.startsWith('DTSTART')) {
          final dtstartLine = line;
          AppLogger.debug('VEventParser: DTSTART line: $dtstartLine');
          
          if (dtstartLine.contains('VALUE=DATE:')) {
            // All-day event
            final dateStr = dtstartLine.split('VALUE=DATE:')[1];
            dtstart = _parseDate(dateStr);
            isAllDay = true;
            AppLogger.debug('VEventParser: All-day DTSTART, dtstart: $dtstart');
          } else if (dtstartLine.contains(':')) {
            // Regular event
            final dateStr = dtstartLine.split(':')[1];
            dtstart = _parseDateTime(dateStr);
            AppLogger.debug('VEventParser: Simple DTSTART, dtstart: $dtstart (isUtc: ${dtstart?.isUtc})');
          }
        } else if (line.startsWith('DTEND')) {
          if (line.contains('VALUE=DATE:')) {
            // All-day event
            final dateStr = line.split('VALUE=DATE:')[1];
            dtend = _parseDate(dateStr);
          } else if (line.contains(':')) {
            // Regular event
            final dateStr = line.split(':')[1];
            dtend = _parseDateTime(dateStr);
          }
        } else if (line.startsWith('DESCRIPTION:')) {
          description = _unescapeCalendarText(line.substring(12));
        } else if (line.startsWith('LOCATION:')) {
          location = _unescapeCalendarText(line.substring(9));
        } else if (line.startsWith('ORGANIZER:')) {
          organizer = _parseOrganizer(line.substring(10));
        } else if (line.startsWith('ATTENDEE:')) {
          final attendee = _parseAttendee(line.substring(9));
          if (attendee != null) {
            attendees.add(attendee);
            AppLogger.debug('VEventParser: Added attendee: ${attendee.email} (${attendee.displayName ?? 'no name'})');
          }
        } else if (line.startsWith('RECURRENCE-ID:')) {
          recurrenceId = _unescapeCalendarText(line.substring(14));
          AppLogger.debug('VEventParser: Found RECURRENCE-ID: $recurrenceId');
        }
        // Note: We're intentionally ignoring RRULE, RDATE, EXDATE since the CalDAV server
        // handles expansion and returns individual instances
      }

      if (uid != null && summary != null && dtstart != null) {
        AppLogger.debug('VEventParser: Successfully parsed VEVENT: $uid');

        return CalendarEvent(
          uid: uid,
          summary: summary,
          dtstart: dtstart,
          dtend: dtend,
          isAllDay: isAllDay,
          description: description ?? '',
          location: location,
          organizer: organizer,
          attendees: attendees,
          sourceCalendarUid: sourceCalendarUid,
          accountId: accountId,
          isRecurring: false, // Server handles expansion, so all events are treated as individual
          recurrenceRule: null, // Not needed since server handles expansion
          recurrenceId: recurrenceId,
          recurrenceDates: [],
          exceptionDates: [],
          dtstamp: DateTime.now(),
          created: DateTime.now(),
          lastModified: DateTime.now(),
        );
      } else {
        AppLogger.warning('VEventParser: Failed to parse VEVENT - missing required fields');
        AppLogger.warning('VEventParser: uid: $uid, summary: $summary, dtstart: $dtstart');
        return null;
      }
    } catch (e, stackTrace) {
      AppLogger.error('VEventParser: Error parsing VEVENT: $e');
      AppLogger.error('VEventParser: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Parse multiple VEVENT objects from CalDAV response
  static List<CalendarEvent> parseEventsFromResponse(String xmlResponse, String sourceCalendarUid, String accountId) {
    final events = <CalendarEvent>[];
    
    try {
      // Simple regex parsing - extract VEVENT blocks from XML response
      final veventPattern = RegExp(r'BEGIN:VEVENT.*?END:VEVENT', dotAll: true);
      final vevents = veventPattern.allMatches(xmlResponse);
      
      for (final match in vevents) {
        final veventContent = match.group(0)!;
        final event = parseVEvent(veventContent, sourceCalendarUid, accountId);
        if (event != null) {
          events.add(event);
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('VEventParser: Failed to parse VEVENT response', e, stackTrace);
    }
    
    return events;
  }

  /// Parse VEVENT from calendar data (for sync operations)
  static CalendarEvent? parseVEventFromCalendarData(String calendarData, String sourceCalendarUid, String accountId) {
    try {
      // Extract VEVENT block from calendar data
      final veventPattern = RegExp(r'BEGIN:VEVENT.*?END:VEVENT', dotAll: true);
      final match = veventPattern.firstMatch(calendarData);
      
      if (match != null) {
        final veventContent = match.group(0)!;
        return parseVEvent(veventContent, sourceCalendarUid, accountId);
      }
    } catch (e, stackTrace) {
      AppLogger.error('VEventParser: Failed to parse VEVENT from calendar data', e, stackTrace);
    }
    return null;
  }

  /// Parse DateTime from iCalendar format
  static DateTime? _parseDateTime(String dateTimeStr) {
    try {
      // Unescape HTML entities first
      final cleanDateTimeStr = _unescapeCalendarText(dateTimeStr);
      
      // Handle both YYYYMMDDTHHMMSSZ and YYYYMMDD formats
      if (cleanDateTimeStr.endsWith('Z')) {
        final cleanStr = cleanDateTimeStr.substring(0, cleanDateTimeStr.length - 1);
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
      } else if (cleanDateTimeStr.length >= 15) {
        // Handle local datetime format YYYYMMDDTHHMMSS
        return DateTime(
          int.parse(cleanDateTimeStr.substring(0, 4)),
          int.parse(cleanDateTimeStr.substring(4, 6)),
          int.parse(cleanDateTimeStr.substring(6, 8)),
          int.parse(cleanDateTimeStr.substring(9, 11)),
          int.parse(cleanDateTimeStr.substring(11, 13)),
          int.parse(cleanDateTimeStr.substring(13, 15)),
        );
      }
      // Try ISO format as fallback
      return DateTime.tryParse(cleanDateTimeStr);
    } catch (e) {
      AppLogger.error('VEventParser: Failed to parse date time: $dateTimeStr', e, StackTrace.current);
      return null;
    }
  }

  /// Parse Date from iCalendar format (for all-day events)
  static DateTime? _parseDate(String dateStr) {
    try {
      // Unescape HTML entities first
      final cleanDateStr = _unescapeCalendarText(dateStr);
      
      // Handle YYYYMMDD format
      if (cleanDateStr.length == 8) {
        return DateTime(
          int.parse(cleanDateStr.substring(0, 4)),
          int.parse(cleanDateStr.substring(4, 6)),
          int.parse(cleanDateStr.substring(6, 8)),
        );
      }
      // Try ISO format as fallback
      return DateTime.tryParse(cleanDateStr);
    } catch (e) {
      AppLogger.error('VEventParser: Failed to parse date: $dateStr', e, StackTrace.current);
      return null;
    }
  }

  /// Parse multiple dates from RDATE or EXDATE
  static List<DateTime> _parseMultipleDates(String dateStr) {
    final dates = <DateTime>[];
    try {
      final dateValues = dateStr.split(',');
      for (final dateValue in dateValues) {
        final date = _parseDateTime(dateValue.trim());
        if (date != null) {
          dates.add(date);
        }
      }
    } catch (e) {
      AppLogger.error('VEventParser: Failed to parse multiple dates: $dateStr', e, StackTrace.current);
    }
    return dates;
  }

  /// Extract parameter value from parameter string
  static String? _extractParameter(String params, String paramName) {
    try {
      final parts = params.split(';');
      for (final part in parts) {
        if (part.startsWith('$paramName=')) {
          return part.substring(paramName.length + 1);
        }
      }
    } catch (e) {
      AppLogger.error('VEventParser: Failed to extract parameter $paramName from: $params', e, StackTrace.current);
    }
    return null;
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
        status: AttendeeStatus.fromString(_unescapeCalendarText(parameters['PARTSTAT'] ?? 'NEEDS-ACTION')),
        role: AttendeeRole.fromString(parameters['ROLE'] ?? 'REQ-PARTICIPANT'),
        rsvpRequested: parameters['RSVP']?.toUpperCase() == 'TRUE',
        userType: CalendarUserType.fromString(parameters['CUTYPE'] ?? 'INDIVIDUAL'),
        delegatedFrom: parameters['DELEGATED-FROM'],
        delegatedTo: parameters['DELEGATED-TO'],
        scheduleAgent: parameters['SCHEDULE-AGENT'],
        memberOf: parameters['MEMBER'],
      );
    } catch (e, stackTrace) {
      AppLogger.error('VEventParser: Failed to parse attendee line: $line', e, stackTrace);
      return null;
    }
  }

  /// Ensure timezone database is initialized (for testing and first usage)
  static void _ensureTimezonesInitialized() {
    try {
      // This will throw if no timezone data is loaded
      tz.getLocation('UTC');
    } catch (e) {
      // Initialize with basic timezone data if not already done
      AppLogger.warning('VEventParser: Timezone database not initialized, this may cause issues in production');
    }
  }

  /// Map common timezone names to IANA timezone identifiers
  static String _mapToIANATimezone(String timezoneName) {
    // Common timezone mappings (Windows timezone names to IANA)
    final timezoneMap = {
      // US Timezones
      'Eastern Standard Time': 'America/New_York',
      'Eastern Daylight Time': 'America/New_York',
      'Central Standard Time': 'America/Chicago',
      'Central Daylight Time': 'America/Chicago',
      'Mountain Standard Time': 'America/Denver',
      'Mountain Daylight Time': 'America/Denver',
      'Pacific Standard Time': 'America/Los_Angeles',
      'Pacific Daylight Time': 'America/Los_Angeles',
      'Alaska Standard Time': 'America/Anchorage',
      'Hawaii-Aleutian Standard Time': 'Pacific/Honolulu',
      
      // European timezones
      'GMT Standard Time': 'Europe/London',
      'Greenwich Standard Time': 'Europe/London',
      'Central European Time': 'Europe/Paris',
      'W. Europe Standard Time': 'Europe/Paris',
      'Romance Standard Time': 'Europe/Paris',
      'Central Europe Standard Time': 'Europe/Berlin',
      'E. Europe Standard Time': 'Europe/Bucharest',
      'GTB Standard Time': 'Europe/Athens',
      'Russian Standard Time': 'Europe/Moscow',
      
      // Other common timezones
      'UTC': 'UTC',
      'GMT': 'UTC',
      'Tokyo Standard Time': 'Asia/Tokyo',
      'China Standard Time': 'Asia/Shanghai',
      'India Standard Time': 'Asia/Kolkata',
      'Australian Eastern Standard Time': 'Australia/Sydney',
      'Cen. Australia Standard Time': 'Australia/Adelaide',
      'AUS Eastern Standard Time': 'Australia/Sydney',
    };
    
    // Try direct mapping first
    if (timezoneMap.containsKey(timezoneName)) {
      return timezoneMap[timezoneName]!;
    }
    
    // Try case-insensitive mapping
    final lowerTimezoneName = timezoneName.toLowerCase();
    for (final entry in timezoneMap.entries) {
      if (entry.key.toLowerCase() == lowerTimezoneName) {
        return entry.value;
      }
    }
    
    // If it's already an IANA timezone, return as-is
    try {
      tz.getLocation(timezoneName);
      return timezoneName;
    } catch (e) {
      // Default to UTC if timezone is unknown
      AppLogger.warning('VEventParser: Unknown timezone "$timezoneName", defaulting to UTC');
      return 'UTC';
    }
  }

  /// Parse DateTime with timezone conversion - always returns UTC
  static DateTime? _parseDateTimeWithTimezone(String dateTimeStr, String? timezoneId) {
    final baseDateTime = _parseDateTime(dateTimeStr);
    if (baseDateTime == null) return null;
    
    // If already UTC, return as-is
    if (dateTimeStr.endsWith('Z')) {
      return baseDateTime;
    }
    
    // If no timezone is specified, treat as local and convert to UTC
    if (timezoneId == null || timezoneId.isEmpty) {
      return baseDateTime.toUtc();
    }
    
    try {
      // Ensure timezone database is initialized
      _ensureTimezonesInitialized();
      
      // Map timezone name to IANA timezone identifier
      final ianaTimezone = _mapToIANATimezone(timezoneId);
      AppLogger.debug('VEventParser: Mapped "$timezoneId" to IANA timezone "$ianaTimezone"');
      
      // Get the source timezone location
      final sourceLocation = tz.getLocation(ianaTimezone);
      
      // Create TZDateTime in the source timezone
      final sourceDateTime = tz.TZDateTime(
        sourceLocation, 
        baseDateTime.year,
        baseDateTime.month,
        baseDateTime.day,
        baseDateTime.hour,
        baseDateTime.minute,
        baseDateTime.second,
      );
      
      // Convert to UTC and return as proper regular DateTime (not TZDateTime)
      final tzUtcDateTime = sourceDateTime.toUtc();
      final utcDateTime = DateTime.utc(
        tzUtcDateTime.year,
        tzUtcDateTime.month,
        tzUtcDateTime.day,
        tzUtcDateTime.hour,
        tzUtcDateTime.minute,
        tzUtcDateTime.second,
        tzUtcDateTime.millisecond,
        tzUtcDateTime.microsecond,
      );
      
      // Log the conversion details
      AppLogger.debug('VEventParser: Source datetime: $sourceDateTime (${sourceDateTime.timeZoneOffset})');
      AppLogger.debug('VEventParser: UTC datetime: $utcDateTime (isUtc: ${utcDateTime.isUtc})');
      AppLogger.debug('VEventParser: Conversion: ${sourceDateTime.hour}:${sourceDateTime.minute.toString().padLeft(2, '0')} ${sourceDateTime.timeZoneName} → ${utcDateTime.hour}:${utcDateTime.minute.toString().padLeft(2, '0')} UTC');
      
      return utcDateTime;
      
    } catch (e) {
      AppLogger.warning('VEventParser: Error converting timezone "$timezoneId": $e - treating as local time and converting to UTC');
      return baseDateTime.toUtc();
    }
  }

  /// Unfold the VEVENT (remove line continuations)
  static String _unfoldCalendarText(String vevent) {
    // Use regex to properly handle line folding (RFC 5545)
    // Pattern: newline followed by one or more whitespace characters
    return vevent.replaceAll(RegExp(r'\r?\n[\s]+'), '');
  }

  /// Parse organizer from ORGANIZER line
  static String _parseOrganizer(String line) {
    // Remove mailto: prefix if present
    if (line.startsWith('mailto:')) {
      return _unescapeCalendarText(line.substring(7));
    }
    return line;
  }
} 