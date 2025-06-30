// Task model for individual tasks
// Represents a single actionable item with x-flowit-type: task

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'attendee.dart';

part 'task.freezed.dart';
part 'task.g.dart';

@HiveType(typeId: 6) // Incremented due to addition of dtstamp field
@freezed
class Task with _$Task {
  const factory Task({
    @HiveField(0) required String uid,
    @HiveField(1) required String summary,
    @HiveField(2) required String description,
    @HiveField(3) required String status,
    @HiveField(4) required DateTime lastModified,
    @HiveField(5) required DateTime created,
    @HiveField(6) required DateTime dtstamp, // Required by iCalendar
    @HiveField(7) DateTime? due,
    @HiveField(8) @Default([]) List<String> categories,
    @HiveField(9) String? organizer,
    @HiveField(10) @Default([]) List<Attendee> attendees,
    @HiveField(11) @Default(0) int percentComplete,
    
    // Task-specific FlowIt fields
    @HiveField(12) String? sourceCalendarUid, // UID of source calendar (project)
    @HiveField(13) String? flowitTemplate, // UID of template
    @HiveField(14) String? flowitReversalTask, // UID of reversal task
    @HiveField(15) @Default('{"type":"default"}') String flowitValidator, // JSON string
    @HiveField(16) @Default('{}') String flowitRequirement, // JSON string
    @HiveField(17) @Default('[]') String flowitKanbanColumn, // JSON array
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}

// Factory methods for creating tasks
extension TaskFactory on Task {
  static Task createNew({
    required String summary,
    String description = '',
    DateTime? due,
    List<String> categories = const [],
    String? sourceCalendarUid,
    String? organizer,
  }) {
    final now = DateTime.now();
    return Task(
      uid: 'task-${now.millisecondsSinceEpoch}-${summary.hashCode}',
      summary: summary,
      description: description,
      status: 'NEEDS-ACTION',
      lastModified: now,
      created: now,
      dtstamp: now,
      due: due,
      categories: categories,
      sourceCalendarUid: sourceCalendarUid,
      organizer: organizer,
    );
  }
} 
