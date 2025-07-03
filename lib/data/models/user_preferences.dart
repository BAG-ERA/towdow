// User preferences model for storing customizable app settings
// Includes project ordering and future user preference options

import 'package:hive/hive.dart';

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

  UserPreferences({
    this.projectOrder = const [],
    this.preferredTheme,
    this.enableNotifications,
    this.defaultProjectView,
    this.customSettings,
  });

  /// Create a copy with updated values
  UserPreferences copyWith({
    List<String>? projectOrder,
    String? preferredTheme,
    bool? enableNotifications,
    String? defaultProjectView,
    Map<String, dynamic>? customSettings,
  }) {
    return UserPreferences(
      projectOrder: projectOrder ?? this.projectOrder,
      preferredTheme: preferredTheme ?? this.preferredTheme,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      defaultProjectView: defaultProjectView ?? this.defaultProjectView,
      customSettings: customSettings ?? this.customSettings,
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

  @override
  String toString() {
    return 'UserPreferences(projectOrder: $projectOrder, theme: $preferredTheme, notifications: $enableNotifications)';
  }
} 