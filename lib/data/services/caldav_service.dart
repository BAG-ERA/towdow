// CalDAV service implementing RFC 4791 for calendar operations
// Provides high-level CalDAV operations for VTODO synchronization

import 'dart:math' as math;

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/caldav_account.dart';
import '../models/task.dart';
import '../models/task_calendar.dart';

import 'webdav_client.dart';
import 'capability_discovery_service.dart';
import 'parsers/vtodo_parser.dart';
import 'parsers/xml_response_parser.dart';

class CalDAVService {
  final CaldavAccount account;
  late final WebDAVClient _client;

  CalDAVService({required this.account}) {
    _client = WebDAVClient.fromAccount(account);
  }

  /// Test connection to CalDAV server
  Future<Result<CalDAVCapabilities>> testConnection() async {
    try {
      // AppLogger.debug('CalDAVService: Testing connection to ${account.serverUrl}');
      
      // Use the dedicated capability discovery service
      final discoveryService = CapabilityDiscoveryService(account: account);
      final discoveryResult = await discoveryService.discoverCapabilities();
      
      return await discoveryResult.when(
        success: (discovery) async {
          // AppLogger.info('CalDAVService: Connection test and discovery completed');
          
          return Result.success(CalDAVCapabilities(
            supportsCalDAV: discovery.capabilities.supportsCalDAV,
            supportsTasks: true,
            principal: discovery.capabilities.principal ?? '/principals/users/${account.username}/',
            calendarHome: discovery.capabilities.calendarHome ?? '/calendars/${account.username}/',
            taskCalendars: discovery.availableCalendars,
            serverInfo: discovery.capabilities.serverInfo,
          ));
        },
        failure: (failure) async {
          AppLogger.error('CalDAVService: Connection test failed', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVService: Failed to test connection', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to test CalDAV connection: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Create a task (VTODO) on the server - RFC 4791 Section 5.3.2
  Future<Result<String>> createTask(Task task, {String? calendarPath}) async {
    try {
      // AppLogger.debug('CalDAVService: Creating task ${task.summary}');
      
      // Use default calendar path if none specified
      calendarPath ??= '/calendars/${account.username}/tasks/';
      
      // Generate iCalendar VTODO content
      final vtodoContent = VTODOParser.serializeTask(task);
      
      // Generate unique URL for the task
      final taskUrl = '$calendarPath${task.uid}.ics';
      
      // PUT the task to the server
      final putResult = await _client.put(taskUrl, vtodoContent);
      return await putResult.when(
        success: (response) async {
          if (response.statusCode == 201 || response.statusCode == 204) {
            // AppLogger.info('CalDAVService: Task created successfully');
            return Result.success(taskUrl);
          } else {
            return Result.failure(Failure(
              message: 'Failed to create task: HTTP ${response.statusCode}',
              exception: Exception('Server returned ${response.statusCode}'),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('CalDAVService: Failed to create task', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVService: Failed to create task', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to create task: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Update a task on the server
  Future<Result<void>> updateTask(Task task, String taskUrl, {String? etag}) async {
    try {
      // AppLogger.debug('CalDAVService: Updating task ${task.summary}');
      
      final vtodoContent = VTODOParser.serializeTask(task);
      
      final putResult = await _client.put(taskUrl, vtodoContent, etag: etag);
      return await putResult.when(
        success: (response) async {
          if (response.statusCode == 204 || response.statusCode == 200) {
            // AppLogger.info('CalDAVService: Task updated successfully');
            return Result.success(null);
          } else {
            return Result.failure(Failure(
              message: 'Failed to update task: HTTP ${response.statusCode}',
              exception: Exception('Server returned ${response.statusCode}'),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('CalDAVService: Failed to update task', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVService: Failed to update task', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to update task: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Delete a task from the server
  Future<Result<void>> deleteTask(String taskUrl, {String? etag}) async {
    try {
      // AppLogger.debug('CalDAVService: Deleting task at $taskUrl');
      
      final deleteResult = await _client.delete(taskUrl, etag: etag);
      return await deleteResult.when(
        success: (response) async {
          if (response.statusCode == 204 || response.statusCode == 200) {
            // AppLogger.info('CalDAVService: Task deleted successfully');
            return Result.success(null);
          } else {
            return Result.failure(Failure(
              message: 'Failed to delete task: HTTP ${response.statusCode}',
              exception: Exception('Server returned ${response.statusCode}'),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('CalDAVService: Failed to delete task', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVService: Failed to delete task', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to delete task: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Fetch all tasks from a calendar using REPORT query
  Future<Result<List<Task>>> fetchTasks({String? calendarPath}) async {
    try {
      // AppLogger.debug('CalDAVService: Fetching tasks from calendar');
      
      calendarPath ??= '/calendars/${account.username}/tasks/';
      
      // CalDAV REPORT query to fetch all VTODOs
      final reportQuery = '''<?xml version="1.0" encoding="utf-8" ?>
<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:prop>
    <D:getetag />
    <C:calendar-data />
  </D:prop>
  <C:filter>
    <C:comp-filter name="VCALENDAR">
      <C:comp-filter name="VTODO" />
    </C:comp-filter>
  </C:filter>
</C:calendar-query>''';

      final reportResult = await _client.report(calendarPath, reportQuery);
      return await reportResult.when(
        success: (response) async {
          if (response.statusCode == 207) {
            final tasks = VTODOParser.parseTasksFromResponse(response.body);
            // AppLogger.info('CalDAVService: Fetched ${tasks.length} tasks');
            return Result.success(tasks);
          } else {
            return Result.failure(Failure(
              message: 'Failed to fetch tasks: HTTP ${response.statusCode}',
              exception: Exception('Server returned ${response.statusCode}'),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('CalDAVService: Failed to fetch tasks', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVService: Failed to fetch tasks', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to fetch tasks: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Discover calendar capabilities and available calendars
  Future<Result<CalDAVCapabilities>> discoverCapabilities() async {
    try {
      // AppLogger.debug('CalDAVService: Discovering CalDAV capabilities');
      
      // Step 1: Discover principal URL
           final principalResult = await _discoverPrincipal();
           return await principalResult.when(
             success: (principal) async {
               String calendarHome;
               String actualPrincipal = principal;
               
               // Check if we got calendar home directly from root
               if (principal.startsWith('CALENDAR_HOME:')) {
                 calendarHome = principal.substring('CALENDAR_HOME:'.length);
                 actualPrincipal = '/'; // Use root as principal
                 // AppLogger.info('CalDAVService: Got calendar home directly: $calendarHome');
               } else {
                 // AppLogger.info('CalDAVService: Found principal: $principal');
                 
                 // Step 2: Find calendar home set from the discovered principal
                 final calendarHomeResult = await _findCalendarHome(principal);
                 final homeResult = calendarHomeResult.when(
                   success: (home) => home,
                   failure: (failure) => null,
                 );
                 
                 if (homeResult == null) {
                   return Result.failure(Failure(
                     message: 'Could not find calendar home set',
                   ));
                 }
                 
                 calendarHome = homeResult;
                 // AppLogger.info('CalDAVService: Found calendar home: $calendarHome');
               }
               
               // Step 3: List available calendars
               final calendarsResult = await _listCalendars(calendarHome);
               return await calendarsResult.when(
                 success: (calendars) async {
                   return Result.success(CalDAVCapabilities(
                     supportsCalDAV: true,
                     supportsTasks: calendars.any((cal) => cal.supportsTodos),
                     principal: actualPrincipal,
                     calendarHome: calendarHome,
                     taskCalendars: calendars,
                     serverInfo: 'CalDAV discovery completed successfully',
                   ));
                 },
                 failure: (failure) async => Result.failure(failure),
               );
             },
             failure: (failure) async => Result.failure(failure),
           );
      
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVService: Failed to discover capabilities', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to discover CalDAV capabilities: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Discover the principal URL for the current user
  Future<Result<String>> _discoverPrincipal() async {
    // AppLogger.debug('CalDAVService: Discovering user principal using current-user-principal');
    
    // Step 1: PROPFIND on user URL to get current-user-principal only
    final propfindQuery = '''<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:current-user-principal/>
  </D:prop>
</D:propfind>''';

    final propfindResult = await _client.propfind('/', body: propfindQuery, depth: 0);
    return await propfindResult.when(
      success: (response) async {
        // AppLogger.debug('CalDAVService: Current user principal response ${response.statusCode}');
        // AppLogger.debug('CalDAVService: Principal response body:\n${response.body}');
        
        if (response.statusCode == 207) {
          // Parse XML to extract current-user-principal
          final principal = XMLResponseParser.extractCurrentUserPrincipal(response.body);
          if (principal != null) {
            // AppLogger.info('CalDAVService: Found current user principal: $principal');
            return Result.success(principal);
          } else {
             AppLogger.warning('CalDAVService: Could not find current-user-principal in response');
             return Result.failure(Failure(
               message: 'Could not discover user principal - server may not support CalDAV properly',
             ));
           }
        } else {
          return Result.failure(Failure(
            message: 'Failed to discover principal: HTTP ${response.statusCode}',
            exception: Exception('Server returned ${response.statusCode}'),
          ));
        }
      },
      failure: (failure) async => Result.failure(failure),
    );
  }

  /// Find the calendar home collection for the user
  Future<Result<String>> _findCalendarHome(String principal) async {
    // AppLogger.debug('CalDAVService: Finding calendar home for principal: $principal');
    
    final propfindQuery = '''<D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:prop>
    <C:calendar-home-set/>
  </D:prop>
</D:propfind>''';

    final propfindResult = await _client.propfind(principal, body: propfindQuery, depth: 0);
    return await propfindResult.when(
      success: (response) async {
        // AppLogger.debug('CalDAVService: Calendar home discovery response ${response.statusCode}');
        // AppLogger.debug('CalDAVService: Calendar home response body:\n${response.body}');
        
        if (response.statusCode == 207) {
          // Parse the response to extract calendar-home-set
          final calendarHome = XMLResponseParser.extractCalendarHomeSet(response.body);
          if (calendarHome != null) {
            // AppLogger.info('CalDAVService: Found calendar home: $calendarHome');
            return Result.success(calendarHome);
          } else {
            return Result.failure(Failure(
              message: 'No calendar-home-set found in response',
              exception: Exception('Missing calendar-home-set in XML response'),
            ));
          }
        } else {
          return Result.failure(Failure(
            message: 'Failed to find calendar home: HTTP ${response.statusCode}',
            exception: Exception('Server returned ${response.statusCode}'),
          ));
        }
      },
      failure: (failure) async => Result.failure(failure),
    );
  }

  /// List available calendars that support VTODO
  Future<Result<List<TaskCalendar>>> _listCalendars(String calendarHome) async {
    // AppLogger.debug('CalDAVService: Listing calendars in: $calendarHome');
    
    final propfindQuery = '''<D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:FLOWIT="https://flowit.app/ns/">
  <D:prop>
    <D:resourcetype/>
    <D:displayname/>
    <C:supported-calendar-component-set/>
    <C:calendar-description/>
    <FLOWIT:domain/>
    <FLOWIT:type/>
    <FLOWIT:asflow/>
    <FLOWIT:owner/>
    <FLOWIT:template/>
  </D:prop>
</D:propfind>''';

    final propfindResult = await _client.propfind(calendarHome, body: propfindQuery, depth: 1);
    return await propfindResult.when(
      success: (response) async {
        // AppLogger.debug('CalDAVService: Calendar listing response ${response.statusCode}');
        // AppLogger.debug('CalDAVService: Calendar listing response body:\n${response.body}');
        
        if (response.statusCode == 207) {
          final calendars = XMLResponseParser.parseCalendarsFromResponse(response.body, calendarHome);
          // AppLogger.info('CalDAVService: Successfully parsed ${calendars.length} calendars');
          return Result.success(calendars);
        } else {
          return Result.failure(Failure(
            message: 'Failed to list calendars: HTTP ${response.statusCode}',
            exception: Exception('Server returned ${response.statusCode}'),
          ));
        }
      },
      failure: (failure) async => Result.failure(failure),
    );
  }

  /// Delete a calendar collection from the server using DELETE
  Future<Result<void>> deleteCalendar(String calendarPath) async {
    try {
      // Normalize calendar path to ensure it ends with /
      final normalizedPath = calendarPath.endsWith('/') ? calendarPath : '$calendarPath/';
      AppLogger.info('CalDAVService: Deleting calendar collection at $normalizedPath');
      
      // Send DELETE request to remove the calendar collection
      final response = await _client.delete(normalizedPath);
      return await response.when(
        success: (webDavResponse) async {
          AppLogger.debug('CalDAVService: DELETE response status: ${webDavResponse.statusCode}');
          AppLogger.debug('CalDAVService: DELETE response body: ${webDavResponse.body}');
          
          // According to RFC 4918, successful collection deletion should return 204 No Content
          // Some servers might return 200 OK or 202 Accepted
          if (webDavResponse.statusCode == 204 || 
              webDavResponse.statusCode == 200 || 
              webDavResponse.statusCode == 202) {
            AppLogger.info('CalDAVService: Calendar collection deleted successfully with status ${webDavResponse.statusCode}');
            return Result.success(null);
          } else if (webDavResponse.statusCode == 404) {
            // 404 Not Found - calendar doesn't exist (consider this success)
            AppLogger.warning('CalDAVService: Calendar not found at $normalizedPath (already deleted?)');
            return Result.success(null);
          } else if (webDavResponse.statusCode == 403) {
            // 403 Forbidden - no permission to delete calendar
            AppLogger.warning('CalDAVService: No permission to delete calendar at $normalizedPath');
            return Result.failure(Failure(
              message: 'Permission denied - cannot delete calendar at this location',
              exception: Exception('HTTP 403 Forbidden'),
            ));
          } else {
            AppLogger.error('CalDAVService: Failed to delete calendar with status ${webDavResponse.statusCode}');
            return Result.failure(Failure(
              message: 'Failed to delete calendar: HTTP ${webDavResponse.statusCode}\nResponse: ${webDavResponse.body}',
              exception: Exception('Server returned ${webDavResponse.statusCode}'),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('CalDAVService: DELETE request failed', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );

    } catch (e, stackTrace) {
      AppLogger.error('CalDAVService: Failed to delete calendar', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to delete calendar: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Create a new calendar on the server using MKCALENDAR
  Future<Result<TaskCalendar>> createCalendar({
    required String calendarPath,
    required String displayName,
    String? description,
    String? uid,
  }) async {
    try {
      // Normalize calendar path to ensure it ends with /
      final normalizedPath = calendarPath.endsWith('/') ? calendarPath : '$calendarPath/';
      // AppLogger.debug('CalDAVService: Creating calendar $displayName at $normalizedPath (original: $calendarPath)');
      
      // Build MKCALENDAR request body (RFC 4791 Section 5.3.1)
      final mkCalendarBody = '''<?xml version="1.0" encoding="utf-8"?>
<C:mkcalendar xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:set>
    <D:prop>
      <D:displayname><![CDATA[$displayName]]></D:displayname>
      <D:resourcetype>
        <D:collection/>
        <C:calendar/>
      </D:resourcetype>
      <C:supported-calendar-component-set>
        <C:comp name="VTODO"/>
        <C:comp name="VEVENT"/>
      </C:supported-calendar-component-set>
      <C:calendar-description><![CDATA[${description ?? 'Created by FlowIt'}]]></C:calendar-description>
    </D:prop>
  </D:set>
</C:mkcalendar>''';

      // Send MKCALENDAR request
      // AppLogger.debug('CalDAVService: Sending MKCALENDAR request to: $normalizedPath');
      // AppLogger.debug('CalDAVService: MKCALENDAR body:\n$mkCalendarBody');
      
      final response = await _client.mkcalendar(normalizedPath, mkCalendarBody);
      return await response.when(
        success: (webDavResponse) async {
          // AppLogger.debug('CalDAVService: MKCALENDAR response status: ${webDavResponse.statusCode}');
          // AppLogger.debug('CalDAVService: MKCALENDAR response body: ${webDavResponse.body}');
          
          // According to RFC 4791, successful calendar creation should return 201 Created
          // Some servers might return 204 No Content or 200 OK
          if (webDavResponse.statusCode == 201 || 
              webDavResponse.statusCode == 204 || 
              webDavResponse.statusCode == 200) {
                         // AppLogger.info('CalDAVService: Calendar created successfully with status ${webDavResponse.statusCode}');
             return Result.success(TaskCalendarFactory.fromCalDAVDiscovery(
               path: normalizedPath,
               displayName: displayName,
               description: description ?? 'Created by FlowIt',
               uid: uid,
             ));
                     } else if (webDavResponse.statusCode == 409) {
             // 409 Conflict - calendar already exists
             AppLogger.warning('CalDAVService: Calendar already exists at $normalizedPath');
             return Result.failure(Failure(
               message: 'Calendar already exists at this location',
               exception: Exception('HTTP 409 Conflict - Calendar already exists'),
             ));
           } else if (webDavResponse.statusCode == 403) {
             // 403 Forbidden - no permission to create calendar
             AppLogger.warning('CalDAVService: No permission to create calendar at $normalizedPath');
            return Result.failure(Failure(
              message: 'Permission denied - cannot create calendar at this location',
              exception: Exception('HTTP 403 Forbidden'),
            ));
          } else {
            AppLogger.error('CalDAVService: Failed to create calendar with status ${webDavResponse.statusCode}');
            return Result.failure(Failure(
              message: 'Failed to create calendar: HTTP ${webDavResponse.statusCode}\nResponse: ${webDavResponse.body}',
              exception: Exception('Server returned ${webDavResponse.statusCode}'),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('CalDAVService: MKCALENDAR request failed', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );

    } catch (e, stackTrace) {
      AppLogger.error('CalDAVService: Failed to create calendar', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to create calendar: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Update calendar properties (standard + FlowIt properties) on server using PROPPATCH
  Future<Result<void>> updateCalendarProperties(TaskCalendar calendar) async {
    try {
      AppLogger.info('CalDAVService: Starting calendar properties PROPPATCH for ${calendar.displayName}');
      AppLogger.info('CalDAVService: Calendar path: ${calendar.path}');
      AppLogger.info('CalDAVService: Calendar UID: ${calendar.uid}');
      AppLogger.info('CalDAVService: Description: ${calendar.description.isNotEmpty ? calendar.description.substring(0, math.min(50, calendar.description.length)) + "..." : "(empty)"}');
      AppLogger.info('CalDAVService: Domain value: ${calendar.flowitDomain ?? "(null)"}');
      AppLogger.info('CalDAVService: Status value: ${calendar.flowitStatus ?? "(null)"}');
      
      // First update WebDAV properties with PROPPATCH
      final proppatchXml = _generateFlowItPropertiesPropPatch(calendar);
      AppLogger.info('CalDAVService: Generated PROPPATCH XML:\n$proppatchXml');
      
      AppLogger.info('CalDAVService: Sending PROPPATCH request to: ${calendar.path}');
      
      final proppatchResult = await _client.proppatch(calendar.path, proppatchXml);
      
      final proppatchSuccess = await proppatchResult.when(
        success: (response) async {
          AppLogger.info('CalDAVService: PROPPATCH completed with status: ${response.statusCode}');
          AppLogger.info('CalDAVService: Response headers: ${response.headers}');
          
          // Log response body only if it's not too long
          final responseBody = response.body;
          if (responseBody.length > 500) {
            AppLogger.info('CalDAVService: Response body (truncated): ${responseBody.substring(0, 500)}...');
          } else {
            AppLogger.info('CalDAVService: Response body: $responseBody');
          }
          
          if (response.statusCode == 207 || response.statusCode == 200) {
            AppLogger.info('CalDAVService: Calendar WebDAV properties updated successfully');
            return true;
          } else {
            final errorMsg = 'PROPPATCH returned ${response.statusCode}: ${responseBody.isNotEmpty ? responseBody : "No error details"}';
            AppLogger.warning('CalDAVService: $errorMsg');
            return false;
          }
        },
        failure: (failure) async {
          AppLogger.error('CalDAVService: PROPPATCH failed: ${failure.message}');
          return false;
        },
      );
      
      // Also update the calendar content (VCALENDAR) with PUT
      final contentUpdateResult = await updateCalendarContent(calendar);
      final contentSuccess = await contentUpdateResult.when(
        success: (_) async {
          AppLogger.info('CalDAVService: Calendar content updated successfully');
          return true;
        },
        failure: (failure) async {
          AppLogger.error('CalDAVService: Calendar content update failed: ${failure.message}');
          return false;
        },
      );
      
      // Return success if at least one update succeeded
      if (proppatchSuccess || contentSuccess) {
        AppLogger.info('CalDAVService: Calendar update completed (properties: $proppatchSuccess, content: $contentSuccess)');
        return Result.success(null);
      } else {
        return Result.failure(Failure(
          message: 'Both property and content updates failed',
          code: 'UPDATE_FAILED',
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVService: Exception during calendar update', e, stackTrace);
      return Result.failure(Failure(
        message: 'Exception during calendar update: $e',
        code: 'EXCEPTION',
      ));
    }
  }

  /// Update calendar content (VCALENDAR) on server using PUT
  Future<Result<void>> updateCalendarContent(TaskCalendar calendar) async {
    try {
      AppLogger.info('CalDAVService: Starting calendar content update for ${calendar.displayName}');
      
      // Generate VCALENDAR content
      final vcalendarContent = _serializeCalendarProperties(calendar);
      AppLogger.info('CalDAVService: Generated VCALENDAR content (${vcalendarContent.length} chars)');
      
      // Construct calendar URL (path + .ics)
      final calendarUrl = '${calendar.path}.ics';
      AppLogger.info('CalDAVService: Updating calendar content at: $calendarUrl');
      
      // PUT calendar content to server
      final result = await _client.put(
        calendarUrl,
        vcalendarContent,
      );
      
      return await result.when(
        success: (response) async {
          AppLogger.info('CalDAVService: PUT calendar content completed with status: ${response.statusCode}');
          
          if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
            AppLogger.info('CalDAVService: Calendar content updated successfully');
            return Result.success(null);
          } else {
            final errorMsg = 'PUT calendar content returned ${response.statusCode}: ${response.body}';
            AppLogger.warning('CalDAVService: $errorMsg');
            return Result.failure(Failure(
              message: errorMsg,
              code: response.statusCode.toString(),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('CalDAVService: PUT calendar content failed: ${failure.message}');
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVService: Exception during calendar content update', e, stackTrace);
      return Result.failure(Failure(
        message: 'Exception during calendar content update: $e',
        code: 'EXCEPTION',
      ));
    }
  }

  /// Generate PROPPATCH XML for setting both standard and FlowIt properties
  String _generateFlowItPropertiesPropPatch(TaskCalendar calendar) {
    final xml = StringBuffer();
    
    xml.writeln('<?xml version="1.0" encoding="utf-8"?>');
    xml.writeln('<D:propertyupdate xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:FLOWIT="https://flowit.app/ns/">');
    
    xml.writeln('  <D:set>');
    xml.writeln('    <D:prop>');
    
    // Set standard CalDAV properties
    xml.writeln('      <D:displayname><![CDATA[${calendar.displayName}]]></D:displayname>');
    
    if (calendar.description.isNotEmpty) {
      xml.writeln('      <C:calendar-description><![CDATA[${calendar.description}]]></C:calendar-description>');
    } else {
      xml.writeln('      <C:calendar-description></C:calendar-description>');
    }
    
    // Set FlowIt properties if they exist
    if (calendar.flowitDomain != null && calendar.flowitDomain!.isNotEmpty) {
      xml.writeln('      <FLOWIT:domain>${_escapeXmlText(calendar.flowitDomain!)}</FLOWIT:domain>');
    }
    
    if (calendar.flowitStatus != null && calendar.flowitStatus!.isNotEmpty) {
      xml.writeln('      <FLOWIT:status>${_escapeXmlText(calendar.flowitStatus!)}</FLOWIT:status>');
    }
    
    xml.writeln('    </D:prop>');
    xml.writeln('  </D:set>');
    
    // Remove FlowIt properties if they're null/empty
    if ((calendar.flowitDomain == null || calendar.flowitDomain!.isEmpty) || 
        (calendar.flowitStatus == null || calendar.flowitStatus!.isEmpty)) {
      xml.writeln('  <D:remove>');
      xml.writeln('    <D:prop>');
      
      if (calendar.flowitDomain == null || calendar.flowitDomain!.isEmpty) {
        xml.writeln('      <FLOWIT:domain/>');
      }
      
      if (calendar.flowitStatus == null || calendar.flowitStatus!.isEmpty) {
        xml.writeln('      <FLOWIT:status/>');
      }
      
      xml.writeln('    </D:prop>');
      xml.writeln('  </D:remove>');
    }
    
    xml.writeln('</D:propertyupdate>');
    return xml.toString();
  }

  /// Escape XML text to prevent injection
  String _escapeXmlText(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Serialize calendar properties to VCALENDAR format
  String _serializeCalendarProperties(TaskCalendar calendar) {
    final vcalendar = StringBuffer();
    
    // Start VCALENDAR
    vcalendar.writeln('BEGIN:VCALENDAR');
    vcalendar.writeln('VERSION:2.0');
    vcalendar.writeln('PRODID:-//FlowIt//FlowIt v1.0//EN');
    
    // Standard calendar properties
    vcalendar.writeln('UID:${calendar.uid}');
    vcalendar.writeln('DTSTAMP:${_formatDateTime(calendar.dtstamp)}');
    vcalendar.writeln('CREATED:${_formatDateTime(calendar.created)}');
    vcalendar.writeln('LAST-MODIFIED:${_formatDateTime(calendar.lastModified)}');
    vcalendar.writeln('SUMMARY:${_escapeCalendarText(calendar.displayName)}');
    vcalendar.writeln('STATUS:${calendar.status}');
    vcalendar.writeln('PERCENT-COMPLETE:${calendar.percentComplete}');
    
    if (calendar.description.isNotEmpty) {
      vcalendar.writeln('DESCRIPTION:${_escapeCalendarText(calendar.description)}');
    }
    
    if (calendar.organizer != null) {
      vcalendar.writeln('ORGANIZER:${calendar.organizer}');
    }
    
    // FlowIt-specific properties
    vcalendar.writeln('X-FLOWIT-TYPE:${calendar.flowitType}');
    vcalendar.writeln('X-FLOWIT-ASFLOW:${calendar.flowitAsFlow.toString().toUpperCase()}');
    
    if (calendar.flowitDomain != null && calendar.flowitDomain!.isNotEmpty) {
      vcalendar.writeln('X-FLOWIT-DOMAIN:${_escapeCalendarText(calendar.flowitDomain!)}');
    }
    
    if (calendar.flowitStatus != null && calendar.flowitStatus!.isNotEmpty) {
      vcalendar.writeln('X-FLOWIT-STATUS:${_escapeCalendarText(calendar.flowitStatus!)}');
    }
    
    if (calendar.flowitKanban.isNotEmpty && calendar.flowitKanban != '[]') {
      vcalendar.writeln('X-FLOWIT-KANBAN:${_escapeCalendarText(calendar.flowitKanban)}');
    }
    
    if (calendar.flowitOwner != null) {
      vcalendar.writeln('X-FLOWIT-OWNER:${_escapeCalendarText(calendar.flowitOwner!)}');
    }
    
    if (calendar.flowitTemplate != null) {
      vcalendar.writeln('X-FLOWIT-TEMPLATE:${calendar.flowitTemplate}');
    }
    
    vcalendar.writeln('CALENDAR-ORDER:${calendar.calendarOrder}');
    
    // Categories
    if (calendar.categories.isNotEmpty) {
      vcalendar.writeln('CATEGORIES:${calendar.categories.map(_escapeCalendarText).join(',')}');
    }
    
    // End VCALENDAR
    vcalendar.writeln('END:VCALENDAR');
    
    return vcalendar.toString();
  }

  /// Parse calendar properties from VCALENDAR response
  TaskCalendar? _parseCalendarProperties(String vcalendarContent, String path, String displayName) {
    try {
      final lines = vcalendarContent.split('\n').map((line) => line.trim()).toList();
      final properties = <String, String>{};
      
      for (final line in lines) {
        if (line.contains(':') && !line.startsWith('BEGIN:') && !line.startsWith('END:')) {
          final colonIndex = line.indexOf(':');
          final key = line.substring(0, colonIndex).trim();
          final value = line.substring(colonIndex + 1).trim();
          properties[key] = _unescapeCalendarText(value);
        }
      }
      
      // Extract standard properties
      final uid = properties['UID'] ?? 'generated-${DateTime.now().millisecondsSinceEpoch}';
      final dtstamp = _parseDateTime(properties['DTSTAMP']) ?? DateTime.now();
      final created = _parseDateTime(properties['CREATED']) ?? DateTime.now();
      final lastModified = _parseDateTime(properties['LAST-MODIFIED']) ?? DateTime.now();
      final summary = properties['SUMMARY'] ?? displayName;
      final status = properties['STATUS'] ?? 'NEEDS-ACTION';
      final percentComplete = int.tryParse(properties['PERCENT-COMPLETE'] ?? '0') ?? 0;
      final description = properties['DESCRIPTION'] ?? '';
      final organizer = properties['ORGANIZER'];
      
      // Extract FlowIt-specific properties
      final flowitType = properties['X-FLOWIT-TYPE'] ?? 'PROJECT';
      final flowitAsFlow = properties['X-FLOWIT-ASFLOW']?.toLowerCase() == 'true';
      final flowitDomain = properties['X-FLOWIT-DOMAIN'];
      final flowitStatus = properties['X-FLOWIT-STATUS'];
      final flowitKanban = properties['X-FLOWIT-KANBAN'] ?? '[]';
      final flowitOwner = properties['X-FLOWIT-OWNER'];
      final flowitTemplate = properties['X-FLOWIT-TEMPLATE'];
      final calendarOrder = int.tryParse(properties['CALENDAR-ORDER'] ?? '1') ?? 1;
      
      // Parse categories
      final categoriesStr = properties['CATEGORIES'];
      final categories = categoriesStr?.split(',').map((c) => c.trim()).toList() ?? <String>[];
      
      return TaskCalendar(
        path: path,
        displayName: displayName,
        description: description,
        uid: uid,
        dtstamp: dtstamp,
        created: created,
        lastModified: lastModified,
        status: status,
        percentComplete: percentComplete,
        organizer: organizer,
        flowitType: flowitType,
        flowitAsFlow: flowitAsFlow,
        flowitDomain: flowitDomain,
        flowitStatus: flowitStatus,
        flowitKanban: flowitKanban,
        flowitOwner: flowitOwner,
        flowitTemplate: flowitTemplate,
        calendarOrder: calendarOrder,
        categories: categories,
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVService: Failed to parse calendar properties', e, stackTrace);
      return null;
    }
  }

  /// Helper method to format DateTime for iCalendar
  String _formatDateTime(DateTime dateTime) {
    return dateTime.toUtc().toIso8601String().replaceAll(RegExp(r'[:\-]'), '').replaceAll('.000Z', 'Z');
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
      AppLogger.warning('CalDAVService: Failed to parse datetime: $dateTimeStr');
    }
    return null;
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
  
  /// Helper method to unescape calendar text and decode HTML entities
  String _unescapeCalendarText(String text) {
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
        .replaceAll('\\r', '\r')
        .replaceAll('\\,', ',')
        .replaceAll('\\;', ';')
        .replaceAll('\\\\', '\\');
  }
}

/// CalDAV server capabilities information
class CalDAVCapabilities {
  final bool supportsCalDAV;
  final bool supportsTasks;
  final String principal;
  final String calendarHome;
  final List<TaskCalendar> taskCalendars;
  final String serverInfo;

  CalDAVCapabilities({
    required this.supportsCalDAV,
    required this.supportsTasks,
    required this.principal,
    required this.calendarHome,
    required this.taskCalendars,
    required this.serverInfo,
  });
}
   
