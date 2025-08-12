// CalDavPropertiesService: PROPFIND/PROPPATCH for calendar properties

import '../../../core/logger.dart';
import '../../../core/result.dart';
import '../../models/task_calendar.dart';
import '../parsers/xml_response_parser.dart';
import '../webdav_client.dart';

class CalDavPropertiesService {
  final WebDAVClient _client;

  CalDavPropertiesService({required WebDAVClient client}) : _client = client;

  Future<Result<TaskCalendar>> getCalendarProperties(TaskCalendar calendar) async {
    try {
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
      return result.when(
        success: (response) async {
          if (response.statusCode != 207) {
            return Result.failure(Failure(message: 'HTTP ${response.statusCode}'));
          }
          final responses = XMLResponseParser.parseMultiStatusResponse(response.body);
          if (responses.isEmpty) {
            return Result.failure(Failure(message: 'Empty PROPFIND response'));
          }
          final data = responses.first;
          final updated = calendar.copyWith(
            etag: data['getetag'],
            syncToken: data['sync-token'],
            displayName: data['displayname'] ?? calendar.displayName,
            description: data['calendar-description'] ?? calendar.description,
            flowitDomain: data['flowit-domain'] ?? calendar.flowitDomain,
            flowitStatus: data['flowit-status'],
            flowitKanban: data['flowit-kanban'] ?? calendar.flowitKanban,
            projectCategories: data['flowit-categories'] ?? calendar.projectCategories,
            projectRequirements: data['flowit-requirements'] ?? calendar.projectRequirements,
            projectSteps: data['flowit-steps'] ?? calendar.projectSteps,
            sharedWith: data['flowit-sharedWith'] ?? calendar.sharedWith,
            flowitAuthor: data['flowit-author'] ?? calendar.flowitAuthor,
            flowitOwner: data['flowit-owner'] ?? calendar.flowitOwner,
            flowitStartedAt: data['flowit-started-at'] != null
                ? DateTime.tryParse(data['flowit-started-at']) ?? calendar.flowitStartedAt
                : calendar.flowitStartedAt,
            flowitEndedAt: data['flowit-ended-at'] != null
                ? DateTime.tryParse(data['flowit-ended-at']) ?? calendar.flowitEndedAt
                : calendar.flowitEndedAt,
            lastSyncAt: DateTime.now(),
          );
          return Result.success(updated);
        },
        failure: (f) async => Result.failure(f),
      );
    } catch (e, st) {
      AppLogger.error('CalDavPropertiesService: getCalendarProperties failed', e, st);
      return Result.failure(Failure(message: 'getCalendarProperties: $e'));
    }
  }
}


