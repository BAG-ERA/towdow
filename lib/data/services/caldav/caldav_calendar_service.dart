// CalDavCalendarService: Calendar lifecycle ops (create/delete)

import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../core/logger.dart';
import '../../../core/result.dart';
import '../../models/caldav_account.dart';
import '../../models/step.dart';
import '../../models/task_calendar.dart';
import '../webdav_client.dart';

class CalDavCalendarService {
  final CaldavAccount account;
  final WebDAVClient _client;

  CalDavCalendarService({required this.account, WebDAVClient? client})
      : _client = client ?? WebDAVClient.fromAccount(account);

  Future<Result<TaskCalendar>> createCalendar({
    required String calendarHome,
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
      final calendarUuid = const Uuid().v4();
      final path = '$calendarHome$calendarUuid/';

      final stepsJson = asWorkflow
          ? jsonEncode([
              ProjectStep.create(name: 'Step 1', order: 0).toJson(),
            ])
          : null;

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
        <C:comp name="VJOURNAL"/>
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

      final response = await _client.mkcalendar(path, mkCalendarBody);
      return response.when(
        success: (r) async {
          if (r.statusCode == 201 || r.statusCode == 204 || r.statusCode == 200) {
            return Result.success(TaskCalendarFactory.fromCalDAVDiscovery(
              path: path,
              displayName: displayName,
              description: description ?? 'Created by FlowIt',
              flowitAuthor: author,
              flowitOwner: owner,
              flowitStartedAt: DateTime.now(),
              flowitType: asWorkflow ? 'WORKFLOW' : 'PROJECT',
              flowitAsFlow: asWorkflow,
              flowitStatus: asWorkflow ? 'DRAFT' : 'ONGOING',
            ));
          }
          return Result.failure(Failure(message: 'HTTP ${r.statusCode}'));
        },
        failure: (f) async => Result.failure(f),
      );
    } catch (e, st) {
      AppLogger.error('CalDavCalendarService: createCalendar failed', e, st);
      return Result.failure(Failure(message: 'createCalendar: $e'));
    }
  }

  Future<Result<void>> deleteCalendar(String calendarPath) async {
    try {
      final normalizedPath = calendarPath.endsWith('/') ? calendarPath : '$calendarPath/';
      final response = await _client.delete(normalizedPath);
      return response.when(
        success: (r) async {
          if ({200, 202, 204}.contains(r.statusCode)) return const Result.success(null);
          if (r.statusCode == 404) return const Result.success(null);
          return Result.failure(Failure(message: 'HTTP ${r.statusCode}'));
        },
        failure: (f) async => Result.failure(f),
      );
    } catch (e, st) {
      AppLogger.error('CalDavCalendarService: deleteCalendar failed', e, st);
      return Result.failure(Failure(message: 'deleteCalendar: $e'));
    }
  }
}


