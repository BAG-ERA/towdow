// Step model for project workflow steps
// Represents a step definition stored at project (VCALENDAR) level

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

part 'step.freezed.dart';
part 'step.g.dart';

/// Status values for a step lifecycle
/// Stored as UPPERCASE strings to remain compatible across storage and sync
enum StepStatus {
  waiting,
  aborted,
  completed,
  available,
  paused,
}

String stepStatusToString(StepStatus status) {
  switch (status) {
    case StepStatus.waiting:
      return 'WAITING';
    case StepStatus.aborted:
      return 'ABORTED';
    case StepStatus.completed:
      return 'COMPLETED';
    case StepStatus.available:
      return 'AVAILABLE';
    case StepStatus.paused:
      return 'PAUSED';
  }
}

StepStatus stepStatusFromString(String value) {
  switch (value.toUpperCase()) {
    case 'WAITING':
      return StepStatus.waiting;
    case 'ABORTED':
      return StepStatus.aborted;
    case 'COMPLETED':
      return StepStatus.completed;
    case 'AVAILABLE':
      return StepStatus.available;
    case 'PAUSED':
      return StepStatus.paused;
    default:
      return StepStatus.waiting;
  }
}

@HiveType(typeId: 51)
@freezed
abstract class ProjectStep with _$ProjectStep {
  const factory ProjectStep({
    @HiveField(0) required String id,
    @HiveField(1) required String name,
    @HiveField(2) @Default(0) int order,
    @HiveField(3) @Default(<String>[]) List<String> dependsOn,
    @HiveField(4) @Default(false) bool endWorkflow,
    @HiveField(5)
    @JsonKey(fromJson: stepStatusFromString, toJson: stepStatusToString)
    @Default(StepStatus.waiting)
    StepStatus status,
    @HiveField(6) DateTime? availableDate,
    @HiveField(7) DateTime? completionDate,
  }) = _ProjectStep;

  /// Convenience factory that generates a short id automatically
  factory ProjectStep.create({
    required String name,
    int order = 0,
    List<String> dependsOn = const [],
    bool endWorkflow = false,
    StepStatus status = StepStatus.waiting,
    DateTime? availableDate,
    DateTime? completionDate,
  }) {
    return ProjectStep(
      id: generateId(name),
      name: name,
      order: order,
      dependsOn: dependsOn,
      endWorkflow: endWorkflow,
      status: status,
      availableDate: availableDate,
      completionDate: completionDate,
    );
  }
  factory ProjectStep.fromJson(Map<String, dynamic> json) => _$ProjectStepFromJson(json);
}

String generateId(String name) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '$name-$timestamp';
}

extension ProjectStepCopy on ProjectStep {
  ProjectStep withOrder(int newOrder) => copyWith(order: newOrder);
}



