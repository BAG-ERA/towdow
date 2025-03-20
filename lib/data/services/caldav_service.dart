import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ical/serializer.dart';
import '../models/task_model.dart';

/// Service for interacting with a CalDAV server
class CalDAVService {
  final String serverUrl;
  final String username;
  final String password;
  final http.Client _client;

  CalDAVService({
    required this.serverUrl,
    required this.username,
    required this.password,
  }) : _client = http.Client();

  /// Formats a task as a VTODO string
  String _taskToVTODO(TaskModel task) {
    final cal = ICalendar();
    final vtodo = ITodo(
      uid: task.uid,
      summary: task.summary,
      description: task.description,
      status: task.status.value,
      due: task.dueDate,
      lastModified: task.lastModified,
      created: task.created,
    );

    // Add FlowIt-specific properties
    vtodo.addProperty(IProperty(name: 'x-flowit-type', value: task.type.value));
    vtodo.addProperty(IProperty(name: 'x-flowit-validator', value: jsonEncode(task.validator)));
    vtodo.addProperty(IProperty(name: 'x-flowit-requirement', value: jsonEncode(task.requirement)));
    
    if (task.templateUid != null) {
      vtodo.addProperty(IProperty(name: 'x-flowit-template', value: task.templateUid!));
    }
    if (task.processUid != null) {
      vtodo.addProperty(IProperty(name: 'x-flowit-process', value: task.processUid!));
    }
    if (task.reversalTaskUid != null) {
      vtodo.addProperty(IProperty(name: 'x-flowit-reversaltask', value: task.reversalTaskUid!));
    }
    if (task.automation != null) {
      vtodo.addProperty(IProperty(name: 'x-flowit-automate', value: jsonEncode(task.automation)));
    }
    vtodo.addProperty(IProperty(name: 'x-flowit-context', value: jsonEncode(task.context)));

    cal.addElement(vtodo);
    return cal.serialize();
  }

  /// Converts a VTODO string to a TaskModel
  TaskModel _vtodoToTask(String vtodo) {
    final cal = ICalendar.fromString(vtodo);
    final todo = cal.todos.first;

    // Extract FlowIt-specific properties
    final type = todo.getProperty('x-flowit-type')?.value ?? 'task';
    final validator = todo.getProperty('x-flowit-validator')?.value ?? '{}';
    final requirement = todo.getProperty('x-flowit-requirement')?.value ?? '{}';
    final templateUid = todo.getProperty('x-flowit-template')?.value;
    final processUid = todo.getProperty('x-flowit-process')?.value;
    final reversalTaskUid = todo.getProperty('x-flowit-reversaltask')?.value;
    final automation = todo.getProperty('x-flowit-automate')?.value;
    final context = todo.getProperty('x-flowit-context')?.value ?? '{}';

    return TaskModel(
      uid: todo.uid,
      summary: todo.summary ?? '',
      description: todo.description ?? '',
      status: TaskStatus.fromString(todo.status ?? 'NEEDS-ACTION'),
      dueDate: todo.due,
      lastModified: todo.lastModified ?? DateTime.now(),
      created: todo.created ?? DateTime.now(),
      type: FlowItType.fromString(type),
      validator: jsonDecode(validator) as Map<String, dynamic>,
      requirement: jsonDecode(requirement) as Map<String, dynamic>,
      templateUid: templateUid,
      processUid: processUid,
      reversalTaskUid: reversalTaskUid,
      automation: automation != null ? jsonDecode(automation) as Map<String, dynamic> : null,
      context: jsonDecode(context) as Map<String, dynamic>,
    );
  }

  /// Fetches all tasks from the CalDAV server
  Future<List<TaskModel>> fetchTasks() async {
    final response = await _client.report(
      Uri.parse('$serverUrl/calendar'),
      headers: {
        'Depth': '1',
        'Content-Type': 'application/xml',
        'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      },
      body: '''<?xml version="1.0" encoding="utf-8" ?>
        <C:calendar-query xmlns:C="urn:ietf:params:xml:ns:caldav">
          <D:prop xmlns:D="DAV:">
            <D:getetag/>
            <C:calendar-data/>
          </D:prop>
          <C:filter>
            <C:comp-filter name="VCALENDAR">
              <C:comp-filter name="VTODO"/>
            </C:comp-filter>
          </C:filter>
        </C:calendar-query>''',
    );

    if (response.statusCode != 207) {
      throw Exception('Failed to fetch tasks: ${response.statusCode}');
    }

    // Parse the response and extract VTODOs
    // This is a simplified version - in reality, we'd need to parse the XML response
    // and extract the calendar-data nodes
    final tasks = <TaskModel>[];
    // TODO: Implement proper XML parsing
    return tasks;
  }

  /// Creates a new task on the CalDAV server
  Future<void> createTask(TaskModel task) async {
    final vtodo = _taskToVTODO(task);
    final response = await _client.put(
      Uri.parse('$serverUrl/calendar/${task.uid}.ics'),
      headers: {
        'Content-Type': 'text/calendar',
        'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      },
      body: vtodo,
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create task: ${response.statusCode}');
    }
  }

  /// Updates an existing task on the CalDAV server
  Future<void> updateTask(TaskModel task) async {
    final vtodo = _taskToVTODO(task);
    final response = await _client.put(
      Uri.parse('$serverUrl/calendar/${task.uid}.ics'),
      headers: {
        'Content-Type': 'text/calendar',
        'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}',
        'If-Match': '*', // This should ideally use the actual ETag
      },
      body: vtodo,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to update task: ${response.statusCode}');
    }
  }

  /// Deletes a task from the CalDAV server
  Future<void> deleteTask(String uid) async {
    final response = await _client.delete(
      Uri.parse('$serverUrl/calendar/$uid.ics'),
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      },
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete task: ${response.statusCode}');
    }
  }

  /// Closes the HTTP client
  void dispose() {
    _client.close();
  }
}

/// Extension to add CalDAV-specific methods to http.Client
extension CalDAVClientExtension on http.Client {
  Future<http.Response> report(Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return send(http.Request('REPORT', url)
      ..headers.addAll(headers ?? {})
      ..body = body?.toString() ?? ''
      ..encoding = encoding ?? utf8
    ).then(http.Response.fromStream);
  }
} 