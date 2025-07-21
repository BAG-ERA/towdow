// Shared project member model for project sharing functionality
// Represents a user who has access to a shared project

/// Model for shared project member information
class SharedProjectMember {
  final String projectPath;
  final bool allTasks;
  final String projectRight;
  final String sourceUserEmail;
  final String targetUserEmail;

  const SharedProjectMember({
    required this.projectPath,
    required this.allTasks,
    required this.projectRight,
    required this.sourceUserEmail,
    required this.targetUserEmail,
  });

  factory SharedProjectMember.fromJson(Map<String, dynamic> json) {
    return SharedProjectMember(
      projectPath: json['projectPath'] as String,
      allTasks: json['allTasks'] as bool,
      projectRight: json['projectRight'] as String,
      sourceUserEmail: json['sourceUserEmail'] as String,
      targetUserEmail: json['targetUserEmail'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projectPath': projectPath,
      'allTasks': allTasks,
      'projectRight': projectRight,
      'sourceUserEmail': sourceUserEmail,
      'targetUserEmail': targetUserEmail,
    };
  }
} 