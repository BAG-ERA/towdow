// CalDavTaskService: CRUD on VTODO

import '../../../core/logger.dart';
import '../../../core/result.dart';
import '../../models/caldav_account.dart';
import '../../models/task.dart';
import '../parsers/vtodo_parser.dart';
import '../webdav_client.dart';

class CalDavTaskService {
  final CaldavAccount account;
  final WebDAVClient _client;

  CalDavTaskService({required this.account, WebDAVClient? client})
      : _client = client ?? WebDAVClient.fromAccount(account);

  Future<Result<String>> createTask(Task task, String calendarPath) async {
    try {
      final vtodo = VTODOParser.serializeTask(task);
      final taskUrl = '$calendarPath${task.uid}.ics';
      final put = await _client.put(taskUrl, vtodo);
      return put.when(
        success: (r) async {
          if (r.statusCode == 201 || r.statusCode == 204) return Result.success(taskUrl);
          return Result.failure(Failure(message: 'HTTP ${r.statusCode}'));
        },
        failure: (f) async => Result.failure(f),
      );
    } catch (e, st) {
      AppLogger.error('CalDavTaskService: createTask failed', e, st);
      return Result.failure(Failure(message: 'createTask: $e'));
    }
  }

  Future<Result<void>> updateTask(Task task, String taskUrl, {String? etag}) async {
    try {
      final vtodo = VTODOParser.serializeTask(task);
      final put = await _client.put(taskUrl, vtodo, etag: etag);
      return put.when(
        success: (r) async {
          if (r.statusCode == 200 || r.statusCode == 204 || r.statusCode == 201) {
            return const Result.success(null);
          }
          return Result.failure(Failure(message: 'HTTP ${r.statusCode}'));
        },
        failure: (f) async => Result.failure(f),
      );
    } catch (e, st) {
      AppLogger.error('CalDavTaskService: updateTask failed', e, st);
      return Result.failure(Failure(message: 'updateTask: $e'));
    }
  }

  Future<Result<void>> deleteTask(String taskUrl, {String? etag}) async {
    try {
      final del = await _client.delete(taskUrl, etag: etag);
      return del.when(
        success: (r) async {
          if (r.statusCode == 204 || r.statusCode == 200) return const Result.success(null);
          return Result.failure(Failure(message: 'HTTP ${r.statusCode}'));
        },
        failure: (f) async => Result.failure(f),
      );
    } catch (e, st) {
      AppLogger.error('CalDavTaskService: deleteTask failed', e, st);
      return Result.failure(Failure(message: 'deleteTask: $e'));
    }
  }

  Future<Result<List<Task>>> fetchTasks(String calendarPath) async {
    try {
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
      final res = await _client.report(calendarPath, reportQuery);
      return res.when(
        success: (r) async {
          if (r.statusCode == 207) {
            final tasks = VTODOParser.parseTasksFromResponse(r.body);
            return Result.success(tasks);
          }
          return Result.failure(Failure(message: 'HTTP ${r.statusCode}'));
        },
        failure: (f) async => Result.failure(f),
      );
    } catch (e, st) {
      AppLogger.error('CalDavTaskService: fetchTasks failed', e, st);
      return Result.failure(Failure(message: 'fetchTasks: $e'));
    }
  }
}


