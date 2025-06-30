// Base model for all FlowIt items (tasks, projects, automated tasks)
// Contains common VTODO fields and FlowIt-specific extensions

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'flowit_item.freezed.dart';
part 'flowit_item.g.dart';

@HiveType(typeId: 0)
@freezed
class FlowitItem with _$FlowitItem {
  const factory FlowitItem({
    @HiveField(0) required String uid,
    @HiveField(1) required String summary,
    @HiveField(2) required String description,
    @HiveField(3) required String status,
    @HiveField(4) required DateTime lastModified,
    @HiveField(5) required DateTime created,
    @HiveField(6) DateTime? due,
    @HiveField(7) @Default([]) List<String> categories,
    @HiveField(8) String? organizer,
    @HiveField(9) @Default([]) List<String> attendees,
    @HiveField(10) @Default(0) int percentComplete,
    
    // FlowIt-specific fields
    @HiveField(11) required String flowitType, // project, task, automated-task
    @HiveField(12) String? flowitProcess, // UID of parent project/flow
    @HiveField(13) String? flowitTemplate, // UID of template
    @HiveField(14) String? flowitReversalTask, // UID of reversal task
    @HiveField(15) @Default('{}') String flowitValidator, // JSON string
    @HiveField(16) @Default('{}') String flowitRequirement, // JSON string
    @HiveField(17) @Default('{}') String flowitContext, // JSON string
    @HiveField(18) @Default('{}') String flowitAutomate, // JSON string (automated-task only)
    @HiveField(19) @Default('[]') String flowitKanban, // JSON array (project only)
    @HiveField(20) @Default('[]') String flowitKanbanColumn, // JSON array (task only)
    @HiveField(21) @Default(false) bool flowitAsFlow, // project as flow flag
  }) = _FlowitItem;

  factory FlowitItem.fromJson(Map<String, dynamic> json) => _$FlowitItemFromJson(json);
} 
