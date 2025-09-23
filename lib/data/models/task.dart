// Task model for individual tasks
// Represents a single actionable item with x-flowit-type: task

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';
import 'attendee.dart';

part 'task.freezed.dart';
part 'task.g.dart';
// No json_serializable generation; custom (de)serialization implemented below

@HiveType(typeId: 6)
@freezed
abstract class Task with _$Task {
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
    @HiveField(16) @Default('[]') String flowitRequirement, // JSON array string of requirement IDs
    @HiveField(17) @Default('[]') String flowitKanbanColumn, // JSON array
    @HiveField(18) @Default('[]') String attachments, // JSON array of ATTACH field data with x-flowit-* parameters
    @HiveField(19) @Default('[]') String mediaAttachments, // JSON array of media attachments with image preview support

    // Steps
    @HiveField(20) String? stepId, // Reference to project step id
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) {
        try { return DateTime.parse(v); } catch (_) {}
      }
      if (v is int) {
        try { return DateTime.fromMillisecondsSinceEpoch(v); } catch (_) {}
      }
      return DateTime.now();
    }

    List<String> parseStringList(dynamic v) {
      if (v is List) {
        return v.map((e) => e.toString()).toList();
      }
      return <String>[];
    }

    List<Attendee> parseAttendees(dynamic v) {
      if (v is List) {
        return v.map((e) {
          if (e is Attendee) return e;
          if (e is Map<String, dynamic>) return Attendee.fromJson(e);
          if (e is Map) return Attendee.fromJson(Map<String, dynamic>.from(e));
          return null;
        }).whereType<Attendee>().toList();
      }
      return <Attendee>[];
    }

    return Task(
      uid: (json['uid'] ?? json['id'] ?? '') as String,
      summary: (json['summary'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      status: (json['status'] ?? 'NEEDS-ACTION') as String,
      lastModified: parseDate(json['lastModified'] ?? json['last_modified'] ?? json['updatedAt']),
      created: parseDate(json['created'] ?? json['createdAt']),
      dtstamp: parseDate(json['dtstamp'] ?? json['dtStamp'] ?? json['timestamp']),
      due: json['due'] != null ? parseDate(json['due']) : null,
      categoryIds: parseStringList(json['categoryIds'] ?? json['category_ids']),
      organizer: json['organizer'] as String?,
      attendees: parseAttendees(json['attendees']),
      percentComplete: ((json['percentComplete'] ?? json['percent_complete'] ?? 0) as num).toInt(),
      projectPath: json['projectPath'] as String?,
      flowitTemplate: json['flowitTemplate'] as String?,
      flowitReversalTask: json['flowitReversalTask'] as String?,
      flowitValidator: (json['flowitValidator'] ?? '{"type":"default"}') as String,
      flowitRequirement: (json['flowitRequirement'] ?? '[]') as String,
      flowitKanbanColumn: (json['flowitKanbanColumn'] ?? '[]') as String,
      attachments: (json['attachments'] ?? '[]') as String,
      mediaAttachments: (json['mediaAttachments'] ?? '[]') as String,
      stepId: json['stepId'] as String?,
    );
  }
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
extension TaskJson on Task {
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'summary': summary,
      'description': description,
      'status': status,
      'lastModified': lastModified.toIso8601String(),
      'created': created.toIso8601String(),
      'dtstamp': dtstamp.toIso8601String(),
      'due': due?.toIso8601String(),
      'categoryIds': categoryIds,
      'organizer': organizer,
      'attendees': attendees.map((e) => e.toJson()).toList(),
      'percentComplete': percentComplete,
      'projectPath': projectPath,
      'flowitTemplate': flowitTemplate,
      'flowitReversalTask': flowitReversalTask,
      'flowitValidator': flowitValidator,
      'flowitRequirement': flowitRequirement,
      'flowitKanbanColumn': flowitKanbanColumn,
      'attachments': attachments,
      'mediaAttachments': mediaAttachments,
      'stepId': stepId,
    };
  }
}

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
