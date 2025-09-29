// User preferences model for storing customizable app settings
// Includes project ordering and future user preference options

import 'package:hive_ce/hive.dart';
import 'shared_with_me_project.dart';

part 'user_preferences.g.dart';

@HiveType(typeId: 11) 
class UserPreferences extends HiveObject {
  @HiveField(0)
  final List<String> projectOrder;

  @HiveField(1)
  final String? preferredTheme; // Future: 'system', 'light', 'dark'

  @HiveField(2)
  final bool? enableNotifications; // Future: notification preferences

  @HiveField(3)
  final String? defaultProjectView; // Future: 'list', 'timing', 'kanban', etc.

  @HiveField(4)
  final Map<String, dynamic>? customSettings; // Future: extensible settings

  @HiveField(6)
  final List<SharedWithMeProject> sharedWithMeProjects; // Projects shared with me

  @HiveField(7)
  final String? etag; // S3 MinIO file etag for sync tracking

  @HiveField(8)
  final String? userPrincipal; // User principal for constructing project paths

  // Removed excludedProjects: all projects are synchronized by default

  // UI appearance: global font scale preference ('small' | 'medium' | 'large')
  @HiveField(10)
  final String? fontScale;

  UserPreferences({
    this.projectOrder = const [],
    this.preferredTheme,
    this.enableNotifications,
    this.defaultProjectView,
    this.customSettings,
    this.sharedWithMeProjects = const [],
    this.etag,
    this.userPrincipal,
    this.fontScale,
  });

  /// Create a copy with updated values
  UserPreferences copyWith({
    List<String>? projectOrder,
    String? preferredTheme,
    bool? enableNotifications,
    String? defaultProjectView,
    Map<String, dynamic>? customSettings,
    List<SharedWithMeProject>? sharedWithMeProjects,
    String? etag,
    String? userPrincipal,
    String? fontScale,
  }) {
    return UserPreferences(
      projectOrder: projectOrder ?? this.projectOrder,
      preferredTheme: preferredTheme ?? this.preferredTheme,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      defaultProjectView: defaultProjectView ?? this.defaultProjectView,
      customSettings: customSettings ?? this.customSettings,
      sharedWithMeProjects: sharedWithMeProjects ?? this.sharedWithMeProjects,
      etag: etag ?? this.etag,
      userPrincipal: userPrincipal ?? this.userPrincipal,
      fontScale: fontScale ?? this.fontScale,
    );
  }

  /// Create default preferences for new users
  factory UserPreferences.defaultPreferences() {
    return UserPreferences(
      projectOrder: const [],
      preferredTheme: 'system',
      enableNotifications: true,
      defaultProjectView: 'list',
      customSettings: const {},
      sharedWithMeProjects: const [],
      fontScale: 'medium',
    );
  }

  /// Update project order while preserving other settings
  UserPreferences withProjectOrder(List<String> newOrder) {
    return copyWith(projectOrder: newOrder);
  }

  /// Add a new project to the end of the order
  UserPreferences addProject(String projectUid) {
    if (projectOrder.contains(projectUid)) {
      return this; // Already in order
    }
    return copyWith(projectOrder: [...projectOrder, projectUid]);
  }

  /// Remove a project from the order
  UserPreferences removeProject(String projectUid) {
    final newOrder = projectOrder.where((uid) => uid != projectUid).toList();
    return copyWith(projectOrder: newOrder);
  }

  /// Reorder a project from one position to another
  UserPreferences reorderProject(String projectUid, int newIndex) {
    final currentOrder = List<String>.from(projectOrder);
    
    // Remove from current position
    currentOrder.remove(projectUid);
    
    // Insert at new position (clamp to valid range)
    final clampedIndex = newIndex.clamp(0, currentOrder.length);
    currentOrder.insert(clampedIndex, projectUid);
    
    return copyWith(projectOrder: currentOrder);
  }




  

  /// Update shared with me projects list
  UserPreferences withSharedWithMeProjects(List<SharedWithMeProject> projects) {
    return copyWith(sharedWithMeProjects: projects);
  }

  /// Check if a project is shared with me
  bool isProjectSharedWithMe(String projectId) {
    return sharedWithMeProjects.any((project) => project.projectId == projectId);
  }

  /// Get shared project details if it exists
  SharedWithMeProject? getSharedProject(String projectId) {
    try {
      return sharedWithMeProjects.firstWhere((project) => project.projectId == projectId);
    } catch (e) {
      return null;
    }
  }

  /// Acknowledge a shared project
  UserPreferences acknowledgeSharedProject(String projectId) {
    final updatedProjects = sharedWithMeProjects.map((project) {
      if (project.projectId == projectId) {
        return project.acknowledge();
      }
      return project;
    }).toList();
    return copyWith(sharedWithMeProjects: updatedProjects);
  }

  @override
  String toString() {
    return 'UserPreferences(projectOrder: $projectOrder, theme: $preferredTheme, fontScale: $fontScale, notifications: $enableNotifications, sharedWithMe: ${sharedWithMeProjects.length})';
  }
} 