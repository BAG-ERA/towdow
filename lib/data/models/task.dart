// Task model for individual tasks
// Represents a single actionable item with x-flowit-type: task

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'attendee.dart';

part 'task.freezed.dart';
part 'task.g.dart';

@HiveType(typeId: 6)
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
    @HiveField(8) @Default([]) List<String> categoryIds,
    @HiveField(9) String? organizer,
    @HiveField(10) @Default([]) List<Attendee> attendees,
    @HiveField(11) @Default(0) int percentComplete,
    
    // Task-specific FlowIt fields
    @HiveField(12) String? projectPath, // Path of source project calendar
    @HiveField(13) String? flowitTemplate, // UID of template
    @HiveField(14) String? flowitReversalTask, // UID of reversal task
    @HiveField(15) @Default('{"type":"default"}') String flowitValidator, // JSON string
    @HiveField(16) @Default('{}') String flowitRequirement, // JSON string
    @HiveField(17) @Default('[]') String flowitKanbanColumn, // JSON array
    @HiveField(18) @Default('[]') String attachments, // JSON array of ATTACH field data with x-flowit-* parameters
    @HiveField(19) @Default('[]') String mediaAttachments, // JSON array of media attachments with image preview support

    // Steps
    @HiveField(20) String? stepId, // Reference to project step id
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}

// Factory methods for creating tasks
extension TaskFactory on Task {
  static Task createNew({
    required String summary,
    String description = '',
    DateTime? due,
    List<String> categoryIds = const [],
    String? projectPath,
    String? organizer,
    List<Attendee> attendees = const [],
    String? flowitTemplate,
    String? flowitReversalTask,
    String flowitValidator = '{"type":"default"}',
    String flowitRequirement = '{}',
    String flowitKanbanColumn = '[]',
    String attachments = '[]',
  }) {
    final now = DateTime.now();
    final uid = 'task-${now.millisecondsSinceEpoch}-${(summary.hashCode % 10000).abs()}';
    
    return Task(
      uid: uid,
      summary: summary,
      description: description,
      status: 'NEEDS-ACTION',
      lastModified: now,
      created: now,
      dtstamp: now,
      due: due,
      categoryIds: categoryIds,
      projectPath: projectPath,
      organizer: organizer,
      attendees: attendees,
      flowitTemplate: flowitTemplate,
      flowitReversalTask: flowitReversalTask,
      flowitValidator: flowitValidator,
      flowitRequirement: flowitRequirement,
      flowitKanbanColumn: flowitKanbanColumn,
      attachments: attachments,
    );
  }
}

/// Extension for Task category management
extension TaskCategoryExtension on Task {
  /// Add a category ID to the task
  Task addCategoryId(String categoryId) {
    if (categoryIds.contains(categoryId)) {
      return this; // Already has this category
    }
    
    final updatedCategoryIds = List<String>.from(categoryIds)..add(categoryId);
    return copyWith(
      categoryIds: updatedCategoryIds,
      lastModified: DateTime.now(),
    );
  }
  
  /// Remove a category ID from the task
  Task removeCategoryId(String categoryId) {
    final updatedCategoryIds = List<String>.from(categoryIds)..remove(categoryId);
    return copyWith(
      categoryIds: updatedCategoryIds,
      lastModified: DateTime.now(),
    );
  }
  
  /// Replace all category IDs
  Task withCategoryIds(List<String> newCategoryIds) {
    return copyWith(
      categoryIds: newCategoryIds,
      lastModified: DateTime.now(),
    );
  }
  
  /// Check if task has a specific category ID
  bool hasCategoryId(String categoryId) {
    return categoryIds.contains(categoryId);
  }
} 
