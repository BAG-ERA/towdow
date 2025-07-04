// External CalDAV service for external calendar operations
// Provides read-only CalDAV operations for VEVENT synchronization
// Based on RFC 4791 for CalDAV and RFC 5545 for iCalendar

import 'dart:math' as math;

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/external_caldav_account.dart';
import '../models/external_calendar.dart';
import '../models/calendar_event.dart';
import '../models/caldav_account.dart';

import 'webdav_client.dart';
import 'capability_discovery_service.dart';
import 'parsers/vevent_parser.dart';
import 'parsers/xml_response_parser.dart';

class ExternalCalDAVService {
  final ExternalCaldavAccount account;
  late final WebDAVClient _client;

  ExternalCalDAVService({required this.account}) {
    _client = WebDAVClient(
      serverUrl: account.serverUrl,
      username: account.username,
      password: account.password ?? '',
    );
  }

  /// Test connection to external CalDAV server
  Future<Result<void>> testConnection() async {
    try {
      AppLogger.debug('ExternalCalDAVService: Testing connection to ${account.serverUrl}');
      
      // Try PROPFIND on common CalDAV paths - more reliable than OPTIONS
      final testPaths = ['/', '/caldav/', '/dav/', '/calendar/', '/remote.php/dav/'];
      
      for (final path in testPaths) {
        AppLogger.debug('ExternalCalDAVService: Testing path: $path');
        
        final propfindQuery = '''<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:current-user-principal />
    <D:resourcetype />
  </D:prop>
</D:propfind>''';
        
        final propfindResult = await _client.propfind(path, body: propfindQuery, depth: 0);
        final result = await propfindResult.when(
          success: (response) async {
            // Accept 207 (Multi-Status), 200 (OK), or even 401/403 as signs of a working server
            if ([200, 207, 401, 403].contains(response.statusCode)) {
              AppLogger.info('ExternalCalDAVService: Connection test successful on path: $path (HTTP ${response.statusCode})');
              return const Result.success(null);
            }
            return null; // Continue trying other paths
          },
          failure: (_) async => null, // Continue trying other paths
        );
        
        if (result != null) return result;
      }
      
      // If all paths failed, return the error
      return Result.failure(Failure(
        message: 'Connection test failed: No valid CalDAV endpoint found. Tried paths: ${testPaths.join(', ')}',
        exception: Exception('No CalDAV endpoint responded correctly'),
      ));
      
    } catch (e, stackTrace) {
      AppLogger.error('ExternalCalDAVService: Connection test failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'Connection test failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Discover external calendars that support VEVENT from a given calendar path
  Future<Result<List<ExternalCalendar>>> discoverCalendars({String? calendarPath}) async {
    try {
      final pathToQuery = calendarPath ?? '/';
      AppLogger.debug('ExternalCalDAVService: Discovering VEVENT calendars at ${account.serverUrl}$pathToQuery');
      
      // Direct PROPFIND to discover calendars with VEVENT support
      final calendarsResult = await _listEventCalendars(pathToQuery);
      return await calendarsResult.when(
        success: (calendars) async {
          AppLogger.info('ExternalCalDAVService: Discovered ${calendars.length} VEVENT-capable calendars');
          return Result.success(calendars);
        },
        failure: (failure) async {
          AppLogger.error('ExternalCalDAVService: Failed to list calendars', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );
      
    } catch (e, stackTrace) {
      AppLogger.error('ExternalCalDAVService: Calendar discovery failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'Calendar discovery failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }
  
    /// List calendars in the given path and filter for VEVENT support
  Future<Result<List<ExternalCalendar>>> _listEventCalendars(String calendarHome) async {
    try {
      AppLogger.debug('ExternalCalDAVService: Listing calendars in: $calendarHome');
      
      final propfindQuery = '''<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:CS="http://calendarserver.org/ns/" xmlns:ICAL="http://apple.com/ns/ical/">
  <D:prop>
    <D:displayname />
    <D:resourcetype />
    <C:supported-calendar-component-set />
    <C:calendar-description />
    <ICAL:calendar-color />
    <CS:getctag />
    <D:getetag />
  </D:prop>
</D:propfind>''';

      final propfindResult = await _client.propfind(calendarHome, body: propfindQuery, depth: 1);
      return await propfindResult.when(
        success: (response) async {
          if (response.statusCode == 207) {
            final calendars = _parseCalendarListResponse(response.body);
            
            // Filter for calendars that support VEVENT
            final eventCalendars = calendars.where((calendar) => 
              calendar.supportedComponents.contains('VEVENT')
            ).toList();
            
            AppLogger.info('ExternalCalDAVService: Found ${calendars.length} total calendars, ${eventCalendars.length} support VEVENT');
            
            return Result.success(eventCalendars);
          } else {
            return Result.failure(Failure(
              message: 'Failed to list calendars: HTTP ${response.statusCode}',
              exception: Exception('Server returned ${response.statusCode}'),
            ));
          }
        },
        failure: (failure) async => Result.failure(failure),
      );
      
    } catch (e, stackTrace) {
      return Result.failure(Failure(
        message: 'Failed to list event calendars: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }
  
  /// Parse calendar list response and extract ExternalCalendar objects
  List<ExternalCalendar> _parseCalendarListResponse(String xmlResponse) {
    final calendars = <ExternalCalendar>[];
    
    try {
      final responses = XMLResponseParser.parseMultiStatusResponse(xmlResponse);
      
      for (final response in responses) {
        // Check if this is a calendar collection
        final resourceType = response['resourcetype'] as String? ?? '';
        if (!resourceType.contains('calendar')) continue;
        
        // Extract calendar properties
        final href = response['href'] as String? ?? '';
        final displayName = response['displayname'] as String? ?? 'Unnamed Calendar';
        final description = response['calendar-description'] as String? ?? '';
        final color = response['calendar-color'] as String?;
        final etag = response['getetag'] as String? ?? '';
        final ctag = response['getctag'] as String? ?? '';
        
        // Extract supported components
        final supportedComponents = <String>[];
        final supportedComponentsData = response['supported-calendar-component-set'] as String? ?? '';
        if (supportedComponentsData.contains('VEVENT')) {
          supportedComponents.add('VEVENT');
        }
        if (supportedComponentsData.contains('VTODO')) {
          supportedComponents.add('VTODO');
        }
        if (supportedComponentsData.contains('VJOURNAL')) {
          supportedComponents.add('VJOURNAL');
        }
        
        // Only include calendars that support VEVENT
        if (supportedComponents.contains('VEVENT')) {
          final calendar = ExternalCalendarFactory.fromCalDAVDiscovery(
            accountId: account.id,
            path: href,
            displayName: displayName,
            description: description,
            etag: etag,
            color: color,
            supportedComponents: supportedComponents,
            uid: _generateCalendarUid(href), // Generate UID from path
          );
          
          calendars.add(calendar);
          AppLogger.debug('ExternalCalDAVService: Found VEVENT calendar: $displayName at $href');
        } else {
          AppLogger.debug('ExternalCalDAVService: Skipping calendar "$displayName" - no VEVENT support (components: ${supportedComponents.join(', ')})');
        }
      }
      
    } catch (e, stackTrace) {
      AppLogger.error('ExternalCalDAVService: Failed to parse calendar list response', e, stackTrace);
    }
    
    return calendars;
  }
  
  /// Generate a UID for the calendar based on its path
  String _generateCalendarUid(String path) {
    // Use a hash of the account ID and path to create a unique UID
    return '${account.id}_${path.replaceAll('/', '_').replaceAll(' ', '_')}';
  }

  /// Fetch all events from an external calendar using REPORT query
  Future<Result<List<CalendarEvent>>> fetchEvents({
    required String calendarPath,
    required String calendarUid,
    DateTime? timeMin,
    DateTime? timeMax,
  }) async {
    try {
      AppLogger.debug('ExternalCalDAVService: Fetching events from calendar $calendarPath');
      
      // Build time range filter if specified
      String timeRangeFilter = '';
      // Enable time range filter for future-only events
      if (timeMin != null || timeMax != null) {
        timeRangeFilter = '<C:time-range';
        if (timeMin != null) {
          timeRangeFilter += ' start="${_formatDateTime(timeMin)}"';
        }
        if (timeMax != null) {
          timeRangeFilter += ' end="${_formatDateTime(timeMax)}"';
        }
        timeRangeFilter += ' />';
        AppLogger.debug('ExternalCalDAVService: Using time range filter: $timeRangeFilter');
        if (timeMin != null) AppLogger.debug('ExternalCalDAVService: timeMin formatted as: ${_formatDateTime(timeMin)}');
        if (timeMax != null) AppLogger.debug('ExternalCalDAVService: timeMax formatted as: ${_formatDateTime(timeMax)}');
      }
      
      // CalDAV REPORT query to fetch all VEVENTs
      final reportQuery = '''<?xml version="1.0" encoding="utf-8" ?>
<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:prop>
    <D:getetag />
    <C:calendar-data />
  </D:prop>
  <C:filter>
    <C:comp-filter name="VCALENDAR">
      <C:comp-filter name="VEVENT">
        $timeRangeFilter
      </C:comp-filter>
    </C:comp-filter>
  </C:filter>
</C:calendar-query>''';

      AppLogger.debug('ExternalCalDAVService: Sending REPORT query to $calendarPath');
      AppLogger.debug('ExternalCalDAVService: Query body: $reportQuery');
      final reportResult = await _client.report(calendarPath, reportQuery);
      return await reportResult.when(
        success: (response) async {
          AppLogger.debug('ExternalCalDAVService: Server response: ${response.statusCode}');
          if (response.statusCode == 207) {
            final events = VEventParser.parseEventsFromResponse(response.body, calendarUid, account.id);
            AppLogger.info('ExternalCalDAVService: Fetched ${events.length} events from $calendarPath');
            return Result.success(events);
          } else {
            AppLogger.warning('ExternalCalDAVService: Server error ${response.statusCode}, response body: ${response.body}');
            return Result.failure(Failure(
              message: 'Failed to fetch events: HTTP ${response.statusCode}',
              exception: Exception('Server returned ${response.statusCode}'),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('ExternalCalDAVService: Failed to fetch events', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ExternalCalDAVService: Failed to fetch events', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to fetch events: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get current sync token for incremental sync
  Future<Result<String?>> getCurrentSyncToken(String calendarPath) async {
    try {
      AppLogger.debug('ExternalCalDAVService: Getting sync token for $calendarPath');
      
      // PROPFIND to get sync-token property
      final propfindQuery = '''<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:" xmlns:CS="http://calendarserver.org/ns/">
  <D:prop>
    <CS:getctag />
    <D:sync-token />
  </D:prop>
</D:propfind>''';

      final propfindResult = await _client.propfind(calendarPath, body: propfindQuery, depth: 0);
      return await propfindResult.when(
        success: (response) async {
          if (response.statusCode == 207) {
            final syncToken = XMLResponseParser.extractSyncToken(response.body);
            AppLogger.debug('ExternalCalDAVService: Retrieved sync token: $syncToken');
            return Result.success(syncToken);
          } else {
            return Result.failure(Failure(
              message: 'Failed to get sync token: HTTP ${response.statusCode}',
              exception: Exception('Server returned ${response.statusCode}'),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('ExternalCalDAVService: Failed to get sync token', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ExternalCalDAVService: Failed to get sync token', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to get sync token: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get incremental changes using sync-collection REPORT
  Future<Result<Map<String, dynamic>>> getSyncChanges(String calendarPath, String syncToken) async {
    try {
      AppLogger.debug('ExternalCalDAVService: Getting sync changes for $calendarPath with token $syncToken');
      
      // sync-collection REPORT query
      final syncQuery = '''<?xml version="1.0" encoding="utf-8" ?>
<D:sync-collection xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:sync-token>$syncToken</D:sync-token>
  <D:sync-level>1</D:sync-level>
  <D:prop>
    <D:getetag />
    <C:calendar-data />
  </D:prop>
</D:sync-collection>''';

      final reportResult = await _client.report(calendarPath, syncQuery);
      return await reportResult.when(
        success: (response) async {
          if (response.statusCode == 207) {
            final syncResult = XMLResponseParser.parseSyncCollectionResponse(response.body);
            AppLogger.info('ExternalCalDAVService: Retrieved sync changes for $calendarPath');
            return Result.success(syncResult);
          } else {
            return Result.failure(Failure(
              message: 'Failed to get sync changes: HTTP ${response.statusCode}',
              exception: Exception('Server returned ${response.statusCode}'),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('ExternalCalDAVService: Failed to get sync changes', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ExternalCalDAVService: Failed to get sync changes', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to get sync changes: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Fetch a specific event by its href
  Future<Result<CalendarEvent?>> fetchEventByHref(String href, String calendarUid) async {
    try {
      AppLogger.debug('ExternalCalDAVService: Fetching event at $href');
      
      final getResult = await _client.get(href);
      return await getResult.when(
        success: (response) async {
          if (response.statusCode == 200) {
            final event = VEventParser.parseVEventFromCalendarData(response.body, calendarUid, account.id);
            if (event != null) {
              AppLogger.debug('ExternalCalDAVService: Successfully fetched event ${event.uid}');
              return Result.success(event);
            } else {
              return Result.failure(Failure(
                message: 'Failed to parse event from response',
                exception: Exception('Event parsing failed'),
              ));
            }
          } else {
            return Result.failure(Failure(
              message: 'Failed to fetch event: HTTP ${response.statusCode}',
              exception: Exception('Server returned ${response.statusCode}'),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('ExternalCalDAVService: Failed to fetch event', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ExternalCalDAVService: Failed to fetch event', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to fetch event: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }



  /// Format DateTime to RFC 5545 iCalendar format: YYYYMMDDTHHMMSSZ
  /// Must be exactly 15 digits + "Z" for UTC time
  String _formatDateTime(DateTime dateTime) {
    // Convert to UTC first
    final utc = dateTime.toUtc();
    
    // Format as YYYYMMDDTHHMMSSZ (exactly 15 digits + Z, no microseconds)
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    
    return '${year}${month}${day}T${hour}${minute}${second}Z';
  }
}

/// External CalDAV server capabilities information
class ExternalCalDAVCapabilities {
  final bool supportsCalDAV;
  final bool supportsEvents;
  final String principal;
  final String calendarHome;
  final List<ExternalCalendar> eventCalendars;
  final String serverInfo;

  const ExternalCalDAVCapabilities({
    required this.supportsCalDAV,
    required this.supportsEvents,
    required this.principal,
    required this.calendarHome,
    required this.eventCalendars,
    required this.serverInfo,
  });
} 