// Shared with me project model for tracking projects shared with current user
// Represents a project shared with the current user with acknowledgment tracking

import 'package:hive/hive.dart';

part 'shared_with_me_project.g.dart';

@HiveType(typeId: 12)
class SharedWithMeProject extends HiveObject {
  @HiveField(0)
  final String projectId; // Corresponds to projectPath in API response

  @HiveField(1)
  final bool allTasks;

  @HiveField(2)
  final String projectRight;

  @HiveField(3)
  final String sourceUserEmail;

  @HiveField(4)
  final bool ack; // User acknowledgment of the share

  SharedWithMeProject({
    required this.projectId,
    required this.allTasks,
    required this.projectRight,
    required this.sourceUserEmail,
    this.ack = false, // Default to false as specified
  });

  /// Create from API response (SharedProjectMember)
  factory SharedWithMeProject.fromSharedProjectMember({
    required String projectPath,
    required bool allTasks,
    required String projectRight,
    required String sourceUserEmail,
    bool ack = false,
  }) {
    return SharedWithMeProject(
      projectId: projectPath,
      allTasks: allTasks,
      projectRight: projectRight,
      sourceUserEmail: sourceUserEmail,
      ack: ack,
    );
  }

  /// Create a copy with updated values
  SharedWithMeProject copyWith({
    String? projectId,
    bool? allTasks,
    String? projectRight,
    String? sourceUserEmail,
    bool? ack,
  }) {
    return SharedWithMeProject(
      projectId: projectId ?? this.projectId,
      allTasks: allTasks ?? this.allTasks,
      projectRight: projectRight ?? this.projectRight,
      sourceUserEmail: sourceUserEmail ?? this.sourceUserEmail,
      ack: ack ?? this.ack,
    );
  }

  /// Mark as acknowledged
  SharedWithMeProject acknowledge() {
    return copyWith(ack: true);
  }

  @override
  String toString() {
    return 'SharedWithMeProject(projectId: $projectId, sourceUser: $sourceUserEmail, ack: $ack)';
  }
} 