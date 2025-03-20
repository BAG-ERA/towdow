import 'dart:convert';

/// Represents the status of a task according to iCalendar specification
enum TaskStatus {
  needsAction('NEEDS-ACTION'),
  completed('COMPLETED'),
  cancelled('CANCELLED');

  final String value;
  const TaskStatus(this.value);

  static TaskStatus fromString(String value) {
    return TaskStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TaskStatus.needsAction,
    );
  }
}

/// Represents the type of a FlowIt item
enum FlowItType {
  task('task'),
  taskGroup('task-group'),
  automatedTask('automated-task'),
  flow('flow');

  final String value;
  const FlowItType(this.value);

  static FlowItType fromString(String value) {
    return FlowItType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => FlowItType.task,
    );
  }
}

/// Represents a task in the FlowIt app, corresponding to a VTODO item
class TaskModel {
  /// Standard iCalendar fields
  final String uid;
  String summary;
  String description;
  TaskStatus status;
  DateTime? dueDate;
  DateTime lastModified;
  DateTime created;
  List<String> attendees;
  List<String> attachments;

  /// FlowIt-specific fields (x-flowit-*)
  FlowItType type;
  Map<String, dynamic> validator;
  Map<String, dynamic> requirement;
  String? templateUid;
  String? processUid;
  String? reversalTaskUid;
  Map<String, dynamic>? automation;
  Map<String, dynamic> context;

  TaskModel({
    required this.uid,
    required this.summary,
    this.description = '',
    this.status = TaskStatus.needsAction,
    this.dueDate,
    DateTime? lastModified,
    DateTime? created,
    this.attendees = const [],
    this.attachments = const [],
    this.type = FlowItType.task,
    Map<String, dynamic>? validator,
    Map<String, dynamic>? requirement,
    this.templateUid,
    this.processUid,
    this.reversalTaskUid,
    this.automation,
    Map<String, dynamic>? context,
  })  : lastModified = lastModified ?? DateTime.now(),
        created = created ?? DateTime.now(),
        validator = validator ?? {'type': 'default'},
        requirement = requirement ?? {},
        context = context ?? {};

  /// Creates a TaskModel from a JSON map
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> _castMap(dynamic map) {
      if (map == null) return {};
      if (map is Map<String, dynamic>) return map;
      return Map<String, dynamic>.from(map as Map);
    }

    return TaskModel(
      uid: json['uid'] as String,
      summary: json['summary'] as String,
      description: json['description'] as String? ?? '',
      status: TaskStatus.fromString(json['status'] as String? ?? 'NEEDS-ACTION'),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      lastModified: DateTime.parse(json['lastModified'] as String),
      created: DateTime.parse(json['created'] as String),
      attendees: List<String>.from(json['attendees'] as List? ?? []),
      attachments: List<String>.from(json['attachments'] as List? ?? []),
      type: FlowItType.fromString(json['x-flowit-type'] as String? ?? 'task'),
      validator: _castMap(json['x-flowit-validator']),
      requirement: _castMap(json['x-flowit-requirement']),
      templateUid: json['x-flowit-template'] as String?,
      processUid: json['x-flowit-process'] as String?,
      reversalTaskUid: json['x-flowit-reversaltask'] as String?,
      automation: json['x-flowit-automate'] != null ? _castMap(json['x-flowit-automate']) : null,
      context: _castMap(json['x-flowit-context']),
    );
  }

  /// Converts the TaskModel to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'summary': summary,
      'description': description,
      'status': status.value,
      'dueDate': dueDate?.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'created': created.toIso8601String(),
      'attendees': attendees,
      'attachments': attachments,
      'x-flowit-type': type.value,
      'x-flowit-validator': validator,
      'x-flowit-requirement': requirement,
      'x-flowit-template': templateUid,
      'x-flowit-process': processUid,
      'x-flowit-reversaltask': reversalTaskUid,
      'x-flowit-automate': automation,
      'x-flowit-context': context,
    };
  }

  /// Creates a copy of this TaskModel with the given fields replaced with new values
  TaskModel copyWith({
    String? summary,
    String? description,
    TaskStatus? status,
    DateTime? dueDate,
    DateTime? lastModified,
    List<String>? attendees,
    List<String>? attachments,
    FlowItType? type,
    Map<String, dynamic>? validator,
    Map<String, dynamic>? requirement,
    String? templateUid,
    String? processUid,
    String? reversalTaskUid,
    Map<String, dynamic>? automation,
    Map<String, dynamic>? context,
  }) {
    return TaskModel(
      uid: uid,
      summary: summary ?? this.summary,
      description: description ?? this.description,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      lastModified: lastModified ?? DateTime.now(),
      created: created,
      attendees: attendees ?? this.attendees,
      attachments: attachments ?? this.attachments,
      type: type ?? this.type,
      validator: validator ?? this.validator,
      requirement: requirement ?? this.requirement,
      templateUid: templateUid ?? this.templateUid,
      processUid: processUid ?? this.processUid,
      reversalTaskUid: reversalTaskUid ?? this.reversalTaskUid,
      automation: automation ?? this.automation,
      context: context ?? this.context,
    );
  }
} 