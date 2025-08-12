// CalDAV service implementing RFC 4791 for calendar operations
// Provides high-level CalDAV operations for VTODO synchronization

import 'dart:math' as math;
import 'dart:convert';

import 'package:uuid/uuid.dart';
 

import '../../../core/result.dart';
import '../../../core/logger.dart';
import '../../models/caldav_account.dart';
import '../../models/task.dart';
import '../../models/task_calendar.dart';
import '../../models/step.dart';

import '../webdav_client.dart';
import 'capability_discovery_service.dart';
import '../parsers/vtodo_parser.dart';
import '../parsers/xml_response_parser.dart';
import '../share/sharing_sync_service.dart';
/// Interface for CalDAV operations used across the app.
///
/// Why this exists
/// - Testability: Allows mocking CalDAV calls (create/update/delete/report)
///   without performing real network I/O. Queue-processing tests depend on this.
/// - Decoupling: UI/ViewModels/Services can depend on an interface instead of
///   the concrete `CalDAVService`, making it easier to evolve/replace.
/// - DI compatibility: Combined with `SyncService.caldavFactory` and the
///   `caldavServiceProvider`, this enables dependency injection.
///
/// How to use
/// - Production: Use the provider returning `ICalDAVService` or the default
///   factory in `SyncService` which constructs `CalDAVService`.
/// - Tests: Override `SyncService.caldavFactory` to return a mock
///   (e.g., Mockito) or override the provider to inject a fake.
/// - Prefer typing against `ICalDAVService` everywhere. Only the DI composition
///   code should reference `CalDAVService` directly.
abstract class ICalDAVService {
  CaldavAccount get account;
  Future<Result<CalDAVCapabilities>> testConnection();
  Future<Result<String>> createTask(Task task, String calendarPath);
  Future<Result<void>> updateTask(Task task, String taskUrl, {String? etag});
  Future<Result<void>> deleteTask(String taskUrl, {String? etag});
  Future<Result<List<Task>>> fetchTasks({required String calendarPath});
  Future<Result<void>> deleteCalendar(String calendarPath);
  Future<Result<TaskCalendar>> getCalendarProperties(TaskCalendar calendar);
  Future<Result<TaskCalendar>> createCalendar({
    required String displayName,
    String? description,
    String? domain,
    String? kanban,
    String? categ,
    String? author,
    String? owner,
    bool asWorkflow = false,
  });
  Future<Result<void>> updateCalendarProperties(TaskCalendar calendar);
}

class CalDAVService implements ICalDAVService {
  @override
  final CaldavAccount account;
  late final WebDAVClient _client;
  late final SharingSyncService _sharingSyncService;

  CalDAVService({required this.account, WebDAVClient? client, SharingSyncService? sharingSyncService}) {
    _client = client ?? WebDAVClient.fromAccount(account);
    _sharingSyncService = sharingSyncService ?? const SharingSyncService();
  }

  /// Test connection to CalDAV server
  @override
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
  @override
  Future<Result<String>> createTask(Task task, String calendarPath) async {
    try {
      // AppLogger.debug('CalDAVService: Creating task ${task.summary}');
         
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
    } on RefreshTokenExpiredException {
      rethrow;
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
  @override
  Future<Result<void>> updateTask(Task task, String taskUrl, {String? etag}) async {
    try {
      // AppLogger.debug('CalDAVService: Updating task ${task.summary}');
      
      final vtodoContent = VTODOParser.serializeTask(task);
      
      final putResult = await _client.put(taskUrl, vtodoContent, etag: etag);
      return await putResult.when(
        success: (response) async {
          if (response.statusCode == 204 || response.statusCode == 200 || response.statusCode == 201) {
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
    } on RefreshTokenExpiredException {
      rethrow;
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
  @override
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
    } on RefreshTokenExpiredException {
      rethrow;
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
  @override
  Future<Result<List<Task>>> fetchTasks({required String calendarPath}) async {
    try {
      // AppLogger.debug('CalDAVService: Fetching tasks from calendar');
            
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
    } on RefreshTokenExpiredException {
      rethrow;
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
      
    } on RefreshTokenExpiredException {
      rethrow;
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
    <FLOWIT:status/>
    <FLOWIT:categories/>
    <FLOWIT:requirements/>
    <FLOWIT:steps/>
    <FLOWIT:sharedWith/>
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
  @override
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

  /// Generate a calendar path with UUID (for local calendar creation)
  Future<Result<String>> generateCalendarPath() async {
    try {
      final capabilitiesResult = await discoverCapabilities();
      return await capabilitiesResult.when(
        success: (capabilities) async {
          final calendarUuid = const Uuid().v4();
          final calendarHome = capabilities.calendarHome;
          final calendarPath = '$calendarHome$calendarUuid/';
          return Result.success(calendarPath);
        },
        failure: (failure) async => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      return Result.failure(Failure(
        message: 'Failed to generate calendar path: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<TaskCalendar>> getCalendarProperties(TaskCalendar calendar) async {
    try {
      AppLogger.debug('CalDAVService: Resyncing calendar info for ${calendar.displayName}');
      
      // Get ALL calendar properties from server (including custom namespaces)
    final propfindBody = '''<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:FLOWIT="https://flowit.app/ns/">
  <D:prop>
    <D:displayname />
    <D:getetag />
    <D:sync-token />
    <C:supported-calendar-component-set />
    <C:calendar-description />
    <FLOWIT:domain />
    <FLOWIT:type />
    <FLOWIT:asflow />
    <FLOWIT:owner />
    <FLOWIT:template />
    <FLOWIT:status />
    <FLOWIT:kanban />
    <FLOWIT:categories />
    <FLOWIT:requirements />
    <FLOWIT:steps />
    <FLOWIT:sharedWith />
    <FLOWIT:author />
    <FLOWIT:manager />
    <FLOWIT:created-at />
    <FLOWIT:ended-at />
  </D:prop>
</D:propfind>''';

      final result = await _client.propfind(calendar.path, body: propfindBody, depth: 0);
      return await result.when(
        success: (response) async {
          if (response.statusCode == 207) {
            // Use existing parser to get all properties including custom namespaces
            final responses = XMLResponseParser.parseMultiStatusResponse(response.body);
            
            if (responses.isNotEmpty) {
              final responseData = responses.first;
              
              // Update the calendar with new properties (only non-null values)
              final updatedCalendar = calendar.copyWith(
                etag: responseData['getetag'],
                syncToken: responseData['sync-token'],
                displayName: responseData['displayname'] ?? calendar.displayName,
                description: responseData['calendar-description'] ?? calendar.description,

                flowitDomain: responseData['flowit-domain'] ?? calendar.flowitDomain,
                flowitStatus: responseData['flowit-status'],
                flowitKanban: responseData['flowit-kanban'] ?? calendar.flowitKanban,
                projectCategories: responseData['flowit-categories'] ?? calendar.projectCategories,
                projectRequirements: responseData['flowit-requirements'] ?? calendar.projectRequirements,
                projectSteps: responseData['flowit-steps'] ?? calendar.projectSteps,
                sharedWith: responseData['flowit-sharedWith'] ?? calendar.sharedWith,
                flowitAuthor: responseData['flowit-author'] ?? calendar.flowitAuthor,
                flowitOwner: responseData['flowit-owner'] ?? calendar.flowitOwner,
                flowitStartedAt: responseData['flowit-started-at'] != null
                  ? DateTime.tryParse(responseData['flowit-started-at']) ?? calendar.flowitStartedAt
                  : calendar.flowitStartedAt,
                flowitEndedAt: responseData['flowit-ended-at'] != null 
                    ? DateTime.tryParse(responseData['flowit-ended-at']) ?? calendar.flowitEndedAt
                    : calendar.flowitEndedAt,
                lastSyncAt: DateTime.now(),
              );
              
              
              return Result.success(updatedCalendar);
            } else {
              return Result.failure(Failure(
                message: 'No calendar properties found in response',
                exception: Exception('Empty response data'),
              ));
            }
          } else {
            return Result.failure(Failure(
              message: 'Failed to resync calendar info: HTTP ${response.statusCode}',
              exception: Exception('Server returned ${response.statusCode}'),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('CalDAVService: Failed to resync calendar info', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVService: Failed to resync calendar info', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to resync calendar info: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Create a new calendar on the server using MKCALENDAR
  @override
  Future<Result<TaskCalendar>> createCalendar({
    required String displayName,
    String? description,
    String? domain,
    String? kanban,
    String? categ,
    String? author,
    String? owner,
    bool asWorkflow = false,
  }) async {
    try {
      // First discover the proper calendar home for this account
      final capabilitiesResult = await testConnection();
      return await capabilitiesResult.when(
        success: (capabilities) async {
          // Generate a new calendar collection path under the discovered home
          final calendarUuid = const Uuid().v4();
          final calendarHome = capabilities.calendarHome;
          final normalizedPath = '$calendarHome$calendarUuid/';
          AppLogger.info('CalDAVService: Creating calendar $displayName at $normalizedPath');
          
          return await _performCalendarCreation(
            normalizedPath, 
            displayName, 
            description,
            domain: domain,
            kanban: kanban,
            categ: categ,
            author: author,
            owner: owner,
            asWorkflow: asWorkflow,
          );
        },
        failure: (failure) async {
          AppLogger.error('CalDAVService: Failed to discover capabilities for calendar creation', failure.exception, failure.stackTrace);
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

  /// Perform the actual calendar creation after path discovery
  Future<Result<TaskCalendar>> _performCalendarCreation(
    String normalizedPath,
    String displayName,
    String? description,
    {String? domain, String? kanban, String? categ, String? author, String? owner, bool asWorkflow = false}
  ) async {
    try {
      // Default steps for workflow calendars
      // For workflows, seed with a single default step using model + toJson
      final stepsJson = asWorkflow
          ? jsonEncode([
              ProjectStep.create(name: 'Step 1', order: 0).toJson(),
            ])
          : null;
      
      // Build MKCALENDAR request body (RFC 4791 Section 5.3.1)
      final mkCalendarBody = '''<?xml version="1.0" encoding="utf-8"?>
<C:mkcalendar xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:FLOWIT="https://flowit.app/ns/">
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
      <FLOWIT:type>${asWorkflow ? 'WORKFLOW' : 'PROJECT'}</FLOWIT:type>
      <FLOWIT:asflow>${asWorkflow ? 'true' : 'false'}</FLOWIT:asflow>
      <FLOWIT:status>${asWorkflow ? 'DRAFT' : 'ONGOING'}</FLOWIT:status>
      ${domain != null && domain.isNotEmpty ? '<FLOWIT:domain>$domain</FLOWIT:domain>' : ''}
      ${kanban != null && kanban.isNotEmpty ? '<FLOWIT:kanban>$kanban</FLOWIT:kanban>' : ''}
      ${categ != null && categ.isNotEmpty ? '<FLOWIT:categories>$categ</FLOWIT:categories>' : ''}
      ${stepsJson != null ? '<FLOWIT:steps><![CDATA[$stepsJson]]></FLOWIT:steps>' : ''}
      ${author != null && author.isNotEmpty ? '<FLOWIT:author>$author</FLOWIT:author>' : ''}
      ${owner != null && owner.isNotEmpty ? '<FLOWIT:owner>$owner</FLOWIT:owner>' : ''}
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
               flowitAuthor: author,
               flowitOwner: owner,
               flowitStartedAt: DateTime.now(),
               flowitType: asWorkflow ? 'WORKFLOW' : 'PROJECT',
               flowitAsFlow: asWorkflow,
               flowitStatus: asWorkflow ? 'DRAFT' : 'ONGOING',
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
  @override
  Future<Result<void>> updateCalendarProperties(TaskCalendar calendar) async {
    try {
      AppLogger.info('CalDAVService: Starting calendar properties PROPPATCH for ${calendar.displayName}');
      AppLogger.info('CalDAVService: Calendar path: ${calendar.path}');
      AppLogger.info('CalDAVService: Calendar UID: ${calendar.path}');
      AppLogger.info('CalDAVService: Description: ${calendar.description.isNotEmpty ? "${calendar.description.substring(0, math.min(50, calendar.description.length))}..." : "(empty)"}');
      AppLogger.info('CalDAVService: Domain value: ${calendar.flowitDomain ?? "(null)"}');
      AppLogger.info('CalDAVService: Status value: ${calendar.flowitStatus ?? "(null)"}');
      
      // Update WebDAV properties with PROPPATCH
      final proppatchXml = _generateFlowItPropertiesPropPatch(calendar);
      AppLogger.info('CalDAVService: Generated PROPPATCH XML:\n$proppatchXml');
      
      AppLogger.info('CalDAVService: Sending PROPPATCH request to: ${calendar.path}');
      
      final proppatchResult = await _client.proppatch(calendar.path, proppatchXml);
      
      return await proppatchResult.when(
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
            // Delegate sharing synchronization to SharingSyncService (best-effort)
            final sharingResult = await _sharingSyncService.syncCalendarSharing(
              calendar: calendar,
              account: account,
            );
            sharingResult.when(
              success: (_) {
                // no-op
              },
              failure: (f) {
                AppLogger.warning('CalDAVService: Sharing sync failed but PROPPATCH succeeded: ${f.message}');
              },
            );
            
            return Result.success(null);
          } else {
            final errorMsg = 'PROPPATCH returned ${response.statusCode}: ${responseBody.isNotEmpty ? responseBody : "No error details"}';
            AppLogger.warning('CalDAVService: $errorMsg');
            return Result.failure(Failure(
              message: errorMsg,
              code: response.statusCode.toString(),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('CalDAVService: PROPPATCH failed: ${failure.message}');
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVService: Exception during calendar update', e, stackTrace);
      return Result.failure(Failure(
        message: 'Exception during calendar update: $e',
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
    
    // Set kanban configuration as JSON
    if (calendar.flowitKanban.isNotEmpty && calendar.flowitKanban != '[]') {
      xml.writeln('      <FLOWIT:kanban><![CDATA[${calendar.flowitKanban}]]></FLOWIT:kanban>');
    }
    
    // Set project categories as JSON
    if (calendar.projectCategories.isNotEmpty && calendar.projectCategories != '[]') {
      xml.writeln('      <FLOWIT:categories><![CDATA[${calendar.projectCategories}]]></FLOWIT:categories>');
    }
    // Set project requirements as JSON
    if (calendar.projectRequirements.isNotEmpty && calendar.projectRequirements != '[]') {
      xml.writeln('      <FLOWIT:requirements><![CDATA[${calendar.projectRequirements}]]></FLOWIT:requirements>');
    }
    // Set project steps as JSON
    if (calendar.projectSteps.isNotEmpty && calendar.projectSteps != '[]') {
      xml.writeln('      <FLOWIT:steps><![CDATA[${calendar.projectSteps}]]></FLOWIT:steps>');
    }
    
    // Set shared project members as JSON
    if (calendar.sharedWith.isNotEmpty && calendar.sharedWith != '[]') {
      xml.writeln('      <FLOWIT:sharedWith><![CDATA[${calendar.sharedWith}]]></FLOWIT:sharedWith>');
    }
    
    xml.writeln('    </D:prop>');
    xml.writeln('  </D:set>');
    
    // Remove FlowIt properties if they're null/empty
    if ((calendar.flowitDomain == null || calendar.flowitDomain!.isEmpty) || 
        (calendar.flowitStatus == null || calendar.flowitStatus!.isEmpty) ||
        (calendar.flowitKanban.isEmpty || calendar.flowitKanban == '[]') ||
        (calendar.projectCategories.isEmpty || calendar.projectCategories == '[]') ||
        (calendar.projectRequirements.isEmpty || calendar.projectRequirements == '[]') ||
        (calendar.sharedWith.isEmpty || calendar.sharedWith == '[]')) {
      xml.writeln('  <D:remove>');
      xml.writeln('    <D:prop>');
      
      if (calendar.flowitDomain == null || calendar.flowitDomain!.isEmpty) {
        xml.writeln('      <FLOWIT:domain/>');
      }
      
      if (calendar.flowitStatus == null || calendar.flowitStatus!.isEmpty) {
        xml.writeln('      <FLOWIT:status/>');
      }
      
      if (calendar.flowitKanban.isEmpty || calendar.flowitKanban == '[]') {
        xml.writeln('      <FLOWIT:kanban/>');
      }
      
      if (calendar.projectCategories.isEmpty || calendar.projectCategories == '[]') {
        xml.writeln('      <FLOWIT:categories/>');
      }
      if (calendar.projectRequirements.isEmpty || calendar.projectRequirements == '[]') {
        xml.writeln('      <FLOWIT:requirements/>');
      }
      if (calendar.projectSteps.isEmpty || calendar.projectSteps == '[]') {
        xml.writeln('      <FLOWIT:steps/>');
      }
      
      if (calendar.sharedWith.isEmpty || calendar.sharedWith == '[]') {
        xml.writeln('      <FLOWIT:sharedWith/>');
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


  // Unused helpers removed; keep class minimal and focused on CalDAV ops.
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
   
