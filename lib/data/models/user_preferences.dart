// User preferences model for storing customizable app settings
// Includes project ordering and future user preference options

import 'package:hive/hive.dart';
import 'package:logger/web.dart';
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

  @HiveField(5)
  final List<String> syncedProjects; // Projects marked for S3 sync

  @HiveField(6)
  final List<SharedWithMeProject> sharedWithMeProjects; // Projects shared with me

  UserPreferences({
    this.projectOrder = const [],
    this.preferredTheme,
    this.enableNotifications,
    this.defaultProjectView,
    this.customSettings,
    this.syncedProjects = const [],
    this.sharedWithMeProjects = const [],
  });

  /// Create a copy with updated values
  UserPreferences copyWith({
    List<String>? projectOrder,
    String? preferredTheme,
    bool? enableNotifications,
    String? defaultProjectView,
    Map<String, dynamic>? customSettings,
    List<String>? syncedProjects,
    List<SharedWithMeProject>? sharedWithMeProjects,
  }) {
    return UserPreferences(
      projectOrder: projectOrder ?? this.projectOrder,
      preferredTheme: preferredTheme ?? this.preferredTheme,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      defaultProjectView: defaultProjectView ?? this.defaultProjectView,
      customSettings: customSettings ?? this.customSettings,
      syncedProjects: syncedProjects ?? this.syncedProjects,
      sharedWithMeProjects: sharedWithMeProjects ?? this.sharedWithMeProjects,
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
      syncedProjects: const [],
      sharedWithMeProjects: const [],
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

  /// Add a project to the synced projects list
  UserPreferences addSyncedProject(String projectUid) {
    if (syncedProjects.contains(projectUid)) {
      return this; // Already synced
    }
    return copyWith(syncedProjects: [...syncedProjects, projectUid]);
  }

  /// Remove a project from the synced projects list
  UserPreferences removeSyncedProject(String projectUid) {
    final newSyncedProjects = syncedProjects.where((uid) => uid != projectUid).toList();
    return copyWith(syncedProjects: newSyncedProjects);
  }

  /// Check if a project is marked for sync
  bool isProjectSynced(String projectUid) {
    return syncedProjects.contains(projectUid);
  }

  /// Set the entire synced projects list
  UserPreferences withSyncedProjects(List<String> projects) {
    return copyWith(syncedProjects: projects);
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
    return 'UserPreferences(projectOrder: $projectOrder, theme: $preferredTheme, notifications: $enableNotifications, syncedProjects: ${syncedProjects.length}, sharedWithMe: ${sharedWithMeProjects.length})';
  }
} 