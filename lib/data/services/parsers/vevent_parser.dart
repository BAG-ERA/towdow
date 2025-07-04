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
      // Handle line folding according to RFC 5545 BEFORE trimming lines
      // Lines can be continued by starting the next line with a space or tab
      AppLogger.debug('VEventParser: VEVENT before unfolding: \n$vevent');

      // Use regex to properly handle line folding (RFC 5545)
      // Pattern: newline followed by one or more whitespace characters
      final unfoldedVevent = vevent.replaceAll(RegExp(r'\r?\n[\s]+'), '');

      AppLogger.debug('VEventParser: VEVENT after unfolding: \n$unfoldedVevent');
      final lines = unfoldedVevent.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty);
      
      String? uid, summary, description, status, organizer, location, contact, url;
      String? transparency, classification, timeZone, recurrenceRule, recurrenceId, duration;
      DateTime? created, lastModified, dtstart, dtend;
      List<String> categories = [];
      List<String> resources = [];
      List<String> alarms = [];
      List<Attendee> attendees = [];
      List<DateTime> recurrenceDates = [];
      List<DateTime> exceptionDates = [];
      int sequence = 0;
      int priority = 0;
      bool isAllDay = false;
      
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
        } else if (line.startsWith('DTSTART')) {
          final dtStartLine = line.substring(7);
          if (dtStartLine.startsWith(';VALUE=DATE:')) {
            isAllDay = true;
            dtstart = _parseDate(dtStartLine.substring(12));
          } else if (dtStartLine.startsWith(':')) {
            dtstart = _parseDateTime(dtStartLine.substring(1));
          } else {
            // Handle DTSTART with timezone or other parameters
            final colonIndex = dtStartLine.indexOf(':');
            if (colonIndex != -1) {
              final params = dtStartLine.substring(0, colonIndex);
              final value = dtStartLine.substring(colonIndex + 1);
              if (params.contains('VALUE=DATE')) {
                isAllDay = true;
                dtstart = _parseDate(value);
              } else {
                // Extract timezone parameter if present
                String? tzid;
                if (params.contains('TZID=')) {
                  tzid = _extractParameter(params, 'TZID');
                  timeZone = tzid; // Store for calendar event
                }
                // Use timezone-aware parsing
                dtstart = _parseDateTimeWithTimezone(value, tzid);
              }
            }
          }
        } else if (line.startsWith('DTEND')) {
          final dtEndLine = line.substring(5);
          if (dtEndLine.startsWith(';VALUE=DATE:')) {
            dtend = _parseDate(dtEndLine.substring(12));
          } else if (dtEndLine.startsWith(':')) {
            dtend = _parseDateTime(dtEndLine.substring(1));
          } else {
            // Handle DTEND with timezone or other parameters
            final colonIndex = dtEndLine.indexOf(':');
            if (colonIndex != -1) {
              final params = dtEndLine.substring(0, colonIndex);
              final value = dtEndLine.substring(colonIndex + 1);
              if (params.contains('VALUE=DATE')) {
                dtend = _parseDate(value);
              } else {
                // Extract timezone parameter if present (should match DTSTART timezone)
                String? tzid;
                if (params.contains('TZID=')) {
                  tzid = _extractParameter(params, 'TZID');
                }
                // Use timezone-aware parsing
                dtend = _parseDateTimeWithTimezone(value, tzid);
              }
            }
          }
        } else if (line.startsWith('DURATION:')) {
          duration = line.substring(9);
        } else if (line.startsWith('LOCATION:')) {
          location = _unescapeCalendarText(line.substring(9));
        } else if (line.startsWith('CATEGORIES:')) {
          categories = line.substring(11).split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        } else if (line.startsWith('RESOURCES:')) {
          resources = line.substring(10).split(',').map((r) => r.trim()).where((r) => r.isNotEmpty).toList();
        } else if (line.startsWith('SEQUENCE:')) {
          sequence = int.tryParse(line.substring(9)) ?? 0;
        } else if (line.startsWith('PRIORITY:')) {
          priority = int.tryParse(line.substring(9)) ?? 0;
        } else if (line.startsWith('TRANSP:')) {
          transparency = line.substring(7);
        } else if (line.startsWith('CLASS:')) {
          classification = line.substring(6);
        } else if (line.startsWith('CONTACT:')) {
          contact = _unescapeCalendarText(line.substring(8));
        } else if (line.startsWith('URL:')) {
          url = line.substring(4);
        } else if (line.startsWith('RRULE:')) {
          recurrenceRule = line.substring(6);
        } else if (line.startsWith('RECURRENCE-ID:')) {
          recurrenceId = line.substring(14);
        } else if (line.startsWith('RDATE:')) {
          final rdateValue = line.substring(6);
          final dates = _parseMultipleDates(rdateValue);
          recurrenceDates.addAll(dates);
        } else if (line.startsWith('EXDATE:')) {
          final exdateValue = line.substring(7);
          final dates = _parseMultipleDates(exdateValue);
          exceptionDates.addAll(dates);
        } else if (line.startsWith('ORGANIZER:')) {
          // Parse organizer (remove mailto: prefix if present)
          organizer = line.substring(10);
          if (organizer.startsWith('mailto:')) {
            organizer = organizer.substring(7);
          }
          AppLogger.debug('VEventParser: Found organizer: $organizer');
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
            AppLogger.debug('VEventParser: Added attendee: ${attendee.email} (${attendee.displayName ?? 'no name'})');
          }
        } else if (line.startsWith('BEGIN:VALARM')) {
          // Simple alarm parsing - just store the type for now
          alarms.add('ALARM');
        }
      }
      
      if (uid != null && summary != null && dtstart != null) {
        AppLogger.debug('VEventParser: Successfully parsed VEVENT: $uid');
        AppLogger.debug('VEventParser: - Summary: $summary');
        AppLogger.debug('VEventParser: - Start: $dtstart');
        AppLogger.debug('VEventParser: - End: $dtend');
        AppLogger.debug('VEventParser: - All Day: $isAllDay');
        AppLogger.debug('VEventParser: - Organizer: $organizer');
        AppLogger.debug('VEventParser: - Attendees count: ${attendees.length}');
        
        return CalendarEvent(
          uid: uid,
          summary: summary,
          description: description ?? '',
          status: status ?? 'CONFIRMED',
          lastModified: lastModified ?? DateTime.now(),
          created: created ?? DateTime.now(),
          dtstamp: DateTime.now(), // Required by iCalendar specification
          dtstart: dtstart,
          dtend: dtend,
          duration: duration,
          transparency: transparency ?? 'OPAQUE',
          classification: classification ?? 'PUBLIC',
          sequence: sequence,
          priority: priority,
          location: location,
          organizer: organizer,
          attendees: attendees,
          contact: contact,
          url: url,
          categories: categories,
          resources: resources,
          timeZone: timeZone,
          recurrenceRule: recurrenceRule,
          recurrenceDates: recurrenceDates,
          exceptionDates: exceptionDates,
          recurrenceId: recurrenceId,
          alarms: alarms,
          sourceCalendarUid: sourceCalendarUid,
          accountId: accountId,
          isAllDay: isAllDay,
          isRecurring: recurrenceRule != null,
          isException: recurrenceId != null,
          computedDuration: dtend != null ? dtend.difference(dtstart) : null,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('VEventParser: Failed to parse VEVENT', e, stackTrace);
    }
    
    return null;
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
      } else if (dateTimeStr.length >= 15) {
        // Handle local datetime format YYYYMMDDTHHMMSS
        return DateTime(
          int.parse(dateTimeStr.substring(0, 4)),
          int.parse(dateTimeStr.substring(4, 6)),
          int.parse(dateTimeStr.substring(6, 8)),
          int.parse(dateTimeStr.substring(9, 11)),
          int.parse(dateTimeStr.substring(11, 13)),
          int.parse(dateTimeStr.substring(13, 15)),
        );
      }
      // Try ISO format as fallback
      return DateTime.tryParse(dateTimeStr);
    } catch (e) {
      AppLogger.error('VEventParser: Failed to parse date time: $dateTimeStr', e, StackTrace.current);
      return null;
    }
  }

  /// Parse Date from iCalendar format (for all-day events)
  static DateTime? _parseDate(String dateStr) {
    try {
      // Handle YYYYMMDD format
      if (dateStr.length == 8) {
        return DateTime(
          int.parse(dateStr.substring(0, 4)),
          int.parse(dateStr.substring(4, 6)),
          int.parse(dateStr.substring(6, 8)),
        );
      }
      // Try ISO format as fallback
      return DateTime.tryParse(dateStr);
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
        status: AttendeeStatus.fromString(parameters['PARTSTAT'] ?? 'NEEDS-ACTION'),
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
      
      // Convert to UTC and return as proper UTC DateTime
      final utcDateTime = sourceDateTime.toUtc();
      
      // Log the conversion details
      AppLogger.debug('VEventParser: Source datetime: $sourceDateTime (${sourceDateTime.timeZoneOffset})');
      AppLogger.debug('VEventParser: UTC datetime: $utcDateTime');
      AppLogger.debug('VEventParser: Conversion: ${sourceDateTime.hour}:${sourceDateTime.minute.toString().padLeft(2, '0')} ${sourceDateTime.timeZoneName} → ${utcDateTime.hour}:${utcDateTime.minute.toString().padLeft(2, '0')} UTC');
      
      return utcDateTime;
      
    } catch (e) {
      AppLogger.warning('VEventParser: Error converting timezone "$timezoneId": $e - treating as local time and converting to UTC');
      return baseDateTime.toUtc();
    }
  }
} 