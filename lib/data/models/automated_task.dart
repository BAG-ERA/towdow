// Automated task model for automated execution
// Represents a task with x-flowit-type: automated-task

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'attendee.dart';

part 'automated_task.freezed.dart';
part 'automated_task.g.dart';

@HiveType(typeId: 9)
@freezed
class AutomatedTask with _$AutomatedTask {
  const factory AutomatedTask({
    @HiveField(0) required String uid,
    @HiveField(1) required String summary,
    @HiveField(2) required String description,
    @HiveField(3) required String status,
    @HiveField(4) required DateTime lastModified,
    @HiveField(5) required DateTime created,
    @HiveField(6) required DateTime dtstamp, // Required by iCalendar
    @HiveField(7) @Default([]) List<String> categories,
    @HiveField(8) String? organizer,
    @HiveField(9) @Default([]) List<Attendee> attendees,
    @HiveField(10) @Default(0) int percentComplete,
    
    // Automated task-specific FlowIt fields
    @HiveField(12) String? flowitTemplate, // UID of template
    @HiveField(13) String? flowitReversalTask, // UID of reversal task
    @HiveField(14) @Default('{"type":"default"}') String flowitValidator, // JSON string
    @HiveField(15) @Default('[]') String flowitRequirement, // JSON array string of requirement IDs
    @HiveField(16) @Default('{}') String flowitAutomate, // JSON string
    @HiveField(17) @Default('{}') String flowitContext, // JSON string
  }) = _AutomatedTask;

  factory AutomatedTask.fromJson(Map<String, dynamic> json) => _$AutomatedTaskFromJson(json);
}

// Factory methods for creating automated tasks
extension AutomatedTaskFactory on AutomatedTask {
  static AutomatedTask createNew({
    required String summary,
    String description = '',
    List<String> categories = const [],
    String? organizer,
    List<Attendee> attendees = const [],
    String? flowitTemplate,
    String? flowitReversalTask,
    String flowitValidator = '{"type":"default"}',
    String flowitRequirement = '{}',
    String flowitAutomate = '{}',
    String flowitContext = '{}',
  }) {
    final now = DateTime.now();
    final uid = 'automated-${now.millisecondsSinceEpoch}-${(summary.hashCode % 10000).abs()}';
    
    return AutomatedTask(
      uid: uid,
      summary: summary,
      description: description,
      status: 'NEEDS-ACTION',
      lastModified: now,
      created: now,
      dtstamp: now,
      categories: categories,
      organizer: organizer,
      attendees: attendees,
      flowitTemplate: flowitTemplate,
      flowitReversalTask: flowitReversalTask,
      flowitValidator: flowitValidator,
      flowitRequirement: flowitRequirement,
      flowitAutomate: flowitAutomate,
      flowitContext: flowitContext,
    );
  }
} 
