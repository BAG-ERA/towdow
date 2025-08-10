// Task calendar model for CalDAV calendar information
// Represents projects at VCALENDAR level according to FlowIt specifications
// Supports persistent storage with Hive and synchronization tracking

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'task.dart';
import 'attendee.dart';
import 'category.dart';
  import 'requirement.dart';
import 'step.dart';
import '../providers/providers.dart';

part 'task_calendar.freezed.dart';
part 'task_calendar.g.dart';

@HiveType(typeId: 10)
@freezed
class TaskCalendar with _$TaskCalendar {
  const factory TaskCalendar({
    // CalDAV server properties
    @HiveField(0) required String path,
    @HiveField(1) required String displayName,
    @HiveField(2) @Default('') String description,
    @HiveField(3) @Default(true) bool supportsTodos,
    @HiveField(4) String? etag,
    @HiveField(5) String? color,
    @HiveField(6) DateTime? lastSyncAt,
    @HiveField(7) @Default(false) bool isReadOnly,
    @HiveField(8) String? syncToken,
    
    // Required VCALENDAR properties for FlowIt projects
    @HiveField(9) required DateTime dtstamp,
    @HiveField(10) required DateTime created,
    @HiveField(11) required DateTime lastModified,
    @HiveField(13) required String status,
    @HiveField(14) @Default(0) int percentComplete,
    
    // FlowIt-specific VCALENDAR properties
    @HiveField(15) @Default('PROJECT') String flowitType, // X-FLOWIT-TYPE
    @HiveField(16) @Default(false) bool flowitAsFlow, // X-FLOWIT-ASFLOW
    @HiveField(17) @Default('[]') String flowitKanban, // X-FLOWIT-KANBAN JSON array
    @HiveField(18) String? flowitTemplate, // X-FLOWIT-TEMPLATE
    @HiveField(19) @Default(1) int calendarOrder, // CALENDAR-ORDER
    @HiveField(21) @Default([]) List<Attendee> attendees, // ATTENDEE
    @HiveField(22) @Default('[]') String projectCategories, // JSON array of Category objects for project-level categories
     @HiveField(31) @Default('[]') String projectRequirements, // JSON array of Requirement objects for project-level requirements
    @HiveField(23) @Default('[]') String projectSteps, // JSON array of Step objects for project-level steps
    @HiveField(24) String? flowitDomain, // X-FLOWIT-DOMAIN - domain for grouping projects
    @HiveField(25) String? flowitStatus, // X-FLOWIT-STATUS - project status (DRAFT, CANCELED, ONGOING, STOPPED, ARCHIVE, COMPLETED, NEEDACTION, FAILED)
    @HiveField(26) @Default('[]') String sharedWith, // JSON array of SharedProjectMember objects for project sharing
    
    // Project management fields
    @HiveField(27) String? flowitAuthor, // X-FLOWIT-AUTHOR - project author (user who created it)
    @HiveField(28) String? flowitOwner, // X-FLOWIT-OWNER - project owner (responsible person)
    @HiveField(29) DateTime? flowitStartedAt, // X-FLOWIT-STARTED-AT - when project was started (defaults to created)
    @HiveField(30) DateTime? flowitEndedAt, // X-FLOWIT-ENDED-AT - when project was completed/ended
    
    // Computed fields (set during sync)
    @HiveField(33) @Default(false) bool isSharedWithMe, // Whether this calendar is shared with the current user (computed during sync)
  }) = _TaskCalendar;

  factory TaskCalendar.fromJson(Map<String, dynamic> json) => _$TaskCalendarFromJson(json);
}

// UID extraction extension
extension TaskCalendarUID on TaskCalendar {
  /// Extract project UID from calendar path
  /// Path format: /user-uuid/project-uuid/ -> returns project-uuid
  String get uid {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return '';
    
    // If last segment is empty (path ends with /), take the one before
    // Otherwise take the last segment
    final lastSegment = segments.last;
    return lastSegment.isEmpty && segments.length > 1 ? segments[segments.length - 2] : lastSegment;
  }
}

// Factory methods for creating task calendars
extension TaskCalendarFactory on TaskCalendar {
  static TaskCalendar createNew({
    required String path,
    required String displayName,
    String description = '',
    List<String> categories = const [],
    List<Attendee> attendees = const [],
    String? domain,
    String? author,
    String? owner,
  }) {
    final now = DateTime.now();
    return TaskCalendar(
      path: path,
      displayName: displayName,
      description: description,
      dtstamp: now,
      created: now,
      lastModified: now,
      status: 'NEEDS-ACTION',
      attendees: attendees,
      // categories field removed - project categories now stored in projectCategories JSON
      flowitOwner: owner,
      flowitDomain: domain,
      flowitStatus: 'ONGOING', // Default status as ONGOING
      flowitAuthor: author, // Set author
      flowitStartedAt: now, // Set start time (defaults to creation time)
    );
  }
  
  static TaskCalendar fromCalDAVDiscovery({
    required String path,
    required String displayName,
    String description = '',
    String? etag,
    String? color,
    bool isReadOnly = false,
    String? domain,
    String? flowitType,
    bool? flowitAsFlow,
    String? flowitOwner,
    String? flowitTemplate,
    String? flowitStatus,
    String? flowitKanban,
    String? sharedWith,
    String? flowitAuthor,
    DateTime? flowitStartedAt,
    DateTime? flowitEndedAt,
    bool isSharedWithMe = false,
  }) {
    final now = DateTime.now();
    return TaskCalendar(
      path: path,
      displayName: displayName,
      description: description,
      etag: etag,
      color: color,
      isReadOnly: isReadOnly,
      dtstamp: now,
      created: now,
      lastModified: now,
      status: 'NEEDS-ACTION',
      flowitDomain: domain,
      flowitType: flowitType ?? 'PROJECT',
      flowitAsFlow: flowitAsFlow ?? false,
      flowitOwner: flowitOwner,
      flowitTemplate: flowitTemplate,
      flowitStatus: flowitStatus ?? 'ONGOING', // Default status as ONGOING
      flowitKanban: flowitKanban ?? '[]',
      sharedWith: sharedWith ?? '[]',
      flowitAuthor: flowitAuthor,
      flowitStartedAt: flowitStartedAt,
      flowitEndedAt: flowitEndedAt,
      isSharedWithMe: isSharedWithMe,
    );
  }
}

// Extension for dynamic project progress calculation
extension TaskCalendarProgress on TaskCalendar {
  /// Calculate project progress based on actual tasks
  int calculateProgress(List<Task> projectTasks) {
    if (projectTasks.isEmpty) return 0;
    
    final completedTasks = projectTasks.where((task) => task.status == 'COMPLETED').length;
    return (completedTasks * 100 / projectTasks.length).round();
  }
  
  /// Get project statistics
  ProjectStats getStats(List<Task> projectTasks) {
    final totalTasks = projectTasks.length;
    final completedTasks = projectTasks.where((task) => task.status == 'COMPLETED').length;
    final inProgressTasks = projectTasks.where((task) => task.status == 'IN-PROCESS').length;
    final pendingTasks = totalTasks - completedTasks - inProgressTasks;
    final progress = calculateProgress(projectTasks);
    
    return ProjectStats(
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      inProgressTasks: inProgressTasks,
      pendingTasks: pendingTasks,
      progressPercentage: progress,
    );
  }
  
  /// Check if project is completed
  bool isCompleted(List<Task> projectTasks) {
    if (projectTasks.isEmpty) return false;
    return projectTasks.every((task) => task.status == 'COMPLETED');
  }
  
  /// Get dynamic status based on tasks
  String getDynamicStatus(List<Task> projectTasks) {
    if (projectTasks.isEmpty) return 'NEEDS-ACTION';
    if (isCompleted(projectTasks)) return 'COMPLETED';
    if (projectTasks.any((task) => task.status == 'IN-PROCESS')) return 'IN-PROCESS';
    return 'NEEDS-ACTION';
  }
}

// Project statistics class
class ProjectStats {
  final int totalTasks;
  final int completedTasks;
  final int inProgressTasks;
  final int pendingTasks;
  final int progressPercentage;
  
  const ProjectStats({
    required this.totalTasks,
    required this.completedTasks,
    required this.inProgressTasks,
    required this.pendingTasks,
    required this.progressPercentage,
  });
}

// Extension for domain-related operations
extension TaskCalendarDomain on TaskCalendar {
  /// Check if this calendar has a domain assigned
  bool get hasDomain => flowitDomain != null && flowitDomain!.isNotEmpty;
  
  /// Get the domain name, or "No Domain" if none assigned
  String get domainDisplayName => flowitDomain?.isNotEmpty == true ? flowitDomain! : 'No Domain';
  
  /// Check if this calendar belongs to a specific domain (case-insensitive)
  bool belongsToDomain(String domain) {
    if (!hasDomain) return domain.toLowerCase() == 'no domain';
    return flowitDomain!.toLowerCase() == domain.toLowerCase();
  }
  
  /// Create a copy with a new domain
  TaskCalendar withDomain(String? newDomain) {
    return copyWith(
      flowitDomain: newDomain?.isEmpty == true ? null : newDomain,
      lastModified: DateTime.now(),
    );
  }
  
  /// Remove domain from this calendar
  TaskCalendar withoutDomain() {
    return copyWith(
      flowitDomain: null,
      lastModified: DateTime.now(),
    );
  }
}

// Extension for sharing-related operations  
extension TaskCalendarSharing on TaskCalendar {
  /// Parse shared project members from JSON
  List<Map<String, dynamic>> get sharedWithMembers {
    try {
      if (sharedWith.isEmpty || sharedWith == '[]') return [];
      final decoded = jsonDecode(sharedWith);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Check if project is shared with others
  bool get isSharedWith => sharedWithMembers.isNotEmpty;

  /// Check if project is shared with me and return the source user email
  /// Returns empty string if not shared, otherwise returns sourceUserEmail
  Future<String> isSharedWithMeBy(WidgetRef ref) async {
    try {
      final userRepository = ref.read(userRepositoryProvider);
      final preferencesResult = await userRepository.getUserPreferences();
      
      return preferencesResult.when(
        success: (preferences) {
          final sharedProject = preferences.getSharedProject(uid);
          return sharedProject?.sourceUserEmail ?? '';
        },
        failure: (_) => '',
      );
    } catch (e) {
      // Fallback to empty string if anything goes wrong
      return '';
    }
  }

  /// Check if this project is a new unacknowledged shared project
  /// Returns true if project is shared with me but not yet acknowledged
  Future<bool> hasNewSharedProjectNotification(WidgetRef ref) async {
    try {
      final userRepository = ref.read(userRepositoryProvider);
      final preferencesResult = await userRepository.getUserPreferences();
      
      return preferencesResult.when(
        success: (preferences) {
          final sharedProject = preferences.getSharedProject(uid);
          return sharedProject != null && !sharedProject.ack;
        },
        failure: (_) => false,
      );
    } catch (e) {
      // Fallback to false if anything goes wrong
      return false;
    }
  }

  /// Computed property: Check if this project is shared with others  
  /// This is a project I own but have shared with other users
  bool get isSharedWithOthers => sharedWithMembers.isNotEmpty;

  /// Get list of users this project is shared with
  List<String> get sharedWithEmails {
    return sharedWithMembers
        .map((member) => member['targetUserEmail'] as String?)
        .where((email) => email != null)
        .cast<String>()
        .toList();
  }

  /// Create a copy with updated sharing info
  TaskCalendar withSharedWith(List<Map<String, dynamic>> members) {
    return copyWith(
      sharedWith: jsonEncode(members),
      lastModified: DateTime.now(),
    );
  }

  /// Create a copy with no sharing
  TaskCalendar withoutSharing() {
    return copyWith(
      sharedWith: '[]',
      lastModified: DateTime.now(),
    );
  }
}

// Extension for status-related operations
extension TaskCalendarStatus on TaskCalendar {
  /// Valid FlowIt project statuses
  static const List<String> validStatuses = [
    'DRAFT',
    'CANCELED', 
    'ONGOING',
    'STOPPED',
    'ARCHIVE',
    'COMPLETED',
    'NEEDACTION',
    'FAILED'
  ];

  /// Check if this calendar has a status assigned
  bool get hasStatus => flowitStatus != null && flowitStatus!.isNotEmpty;
  
  /// Get the status name, or "ONGOING" if none assigned (default)
  String get statusDisplayName => flowitStatus?.isNotEmpty == true ? flowitStatus! : 'ONGOING';
  
  /// Check if this calendar has a specific status (case-insensitive)
  bool hasProjectStatus(String status) {
    return statusDisplayName.toLowerCase() == status.toLowerCase();
  }
  
  /// Check if this calendar is archived
  bool get isArchived => hasProjectStatus('ARCHIVE');
  
  /// Check if this calendar is active (not archived, not canceled, not failed)
  bool get isActive => !isArchived && !hasProjectStatus('CANCELED') && !hasProjectStatus('FAILED');
  
  /// Create a copy with a new status
  TaskCalendar withStatus(String? newStatus) {
    // Validate status if provided
    if (newStatus != null && newStatus.isNotEmpty && !validStatuses.contains(newStatus.toUpperCase())) {
      throw ArgumentError('Invalid status: $newStatus. Valid statuses are: ${validStatuses.join(', ')}');
    }
    
    return copyWith(
      flowitStatus: newStatus?.isEmpty == true ? null : newStatus?.toUpperCase(),
      lastModified: DateTime.now(),
    );
  }
  
  /// Remove status from this calendar (will default to ONGOING)
  TaskCalendar withoutStatus() {
    return copyWith(
      flowitStatus: null,
      lastModified: DateTime.now(),
    );
  }
  
  /// Set this calendar as archived
  TaskCalendar withArchiveStatus() {
    return withStatus('ARCHIVE');
  }
  
  /// Set this calendar as ongoing
  TaskCalendar withOngoingStatus() {
    return withStatus('ONGOING');
  }
  
  /// Get parsed project categories from JSON string
  List<Category> get projectCategoriesList {
    try {
      if (projectCategories.isEmpty || projectCategories == '[]') {
        return [];
      }
      final List<dynamic> jsonList = json.decode(projectCategories);
      return jsonList.map((json) => Category.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Get parsed project requirements from JSON string
  List<Requirement> get projectRequirementsList {
    try {
      if (projectRequirements.isEmpty || projectRequirements == '[]') {
        return [];
      }
      final List<dynamic> jsonList = json.decode(projectRequirements);
      return jsonList.map((json) => Requirement.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Update project requirements with a list of Requirement objects
  TaskCalendar withProjectRequirements(List<Requirement> requirements) {
    final jsonString = json.encode(requirements.map((r) => r.toJson()).toList());
    return copyWith(
      projectRequirements: jsonString,
      lastModified: DateTime.now(),
    );
  }
  
  /// Add or update a requirement in the project
  TaskCalendar addOrUpdateRequirement(Requirement requirement) {
    final current = projectRequirementsList;
    final index = current.indexWhere((r) => r.id == requirement.id);
    if (index != -1) {
      current[index] = requirement;
    } else {
      current.add(requirement);
    }
    return withProjectRequirements(current);
  }
  
  /// Remove a requirement by id
  TaskCalendar removeRequirement(String requirementId) {
    final current = projectRequirementsList;
    current.removeWhere((r) => r.id == requirementId);
    return withProjectRequirements(current);
  }
  
  /// Check if project has a requirement id
  bool hasRequirement(String requirementId) => projectRequirementsList.any((r) => r.id == requirementId);
  
  /// Get a requirement by id
  Requirement? getRequirementById(String requirementId) {
    try {
      return projectRequirementsList.firstWhere((r) => r.id == requirementId);
    } catch (_) {
      return null;
    }
  }
  
  /// Update project categories with a list of Category objects
  TaskCalendar withProjectCategories(List<Category> categories) {
    final jsonString = json.encode(categories.map((cat) => cat.toJson()).toList());
    return copyWith(
      projectCategories: jsonString,
      lastModified: DateTime.now(),
    );
  }
  
  /// Add a category to the project
  TaskCalendar addCategory(Category category) {
    final currentCategories = projectCategoriesList;
    final existingIndex = currentCategories.indexWhere((cat) => cat.id == category.id);
    
    if (existingIndex != -1) {
      // Update existing category
      currentCategories[existingIndex] = category;
    } else {
      // Add new category
      currentCategories.add(category);
    }
    
    return withProjectCategories(currentCategories);
  }
  
  /// Remove a category from the project
  TaskCalendar removeCategory(String categoryId) {
    final currentCategories = projectCategoriesList;
    currentCategories.removeWhere((cat) => cat.id == categoryId);
    return withProjectCategories(currentCategories);
  }
  
  /// Update a category in the project
  TaskCalendar updateCategory(Category updatedCategory) {
    final currentCategories = projectCategoriesList;
    final index = currentCategories.indexWhere((cat) => cat.id == updatedCategory.id);
    
    if (index != -1) {
      currentCategories[index] = updatedCategory;
      return withProjectCategories(currentCategories);
    }
    
    return this; // Category not found, return unchanged
  }
  
  /// Check if the project has a specific category
  bool hasCategory(String categoryId) {
    return projectCategoriesList.any((cat) => cat.id == categoryId);
  }
  
  /// Get a category by ID
  Category? getCategoryById(String categoryId) {
    try {
      return projectCategoriesList.firstWhere((cat) => cat.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  /// Get parsed project steps from JSON string
  List<ProjectStep> get projectStepsList {
    try {
      if (projectSteps.isEmpty || projectSteps == '[]') {
        return [];
      }
      final List<dynamic> jsonList = json.decode(projectSteps);
      final List<ProjectStep> steps = [];
      for (final item in jsonList) {
        if (item is Map<String, dynamic>) {
          final normalized = <String, dynamic>{...item};
          // Normalize common alternate keys to expected names
          if (!normalized.containsKey('id') && normalized.containsKey('stepId')) {
            normalized['id'] = normalized['stepId'];
          }
          if (!normalized.containsKey('name') && normalized.containsKey('title')) {
            normalized['name'] = normalized['title'];
          }
          if (normalized.containsKey('depends_on') && !normalized.containsKey('dependsOn')) {
            final depends = normalized['depends_on'];
            if (depends is List) {
              normalized['dependsOn'] = depends.cast<String>();
            }
          }
          if (normalized.containsKey('end_workflow') && !normalized.containsKey('endWorkflow')) {
            normalized['endWorkflow'] = normalized['end_workflow'];
          }
          if (normalized.containsKey('available_date') && !normalized.containsKey('availableDate')) {
            normalized['availableDate'] = normalized['available_date'];
          }
          if (normalized.containsKey('completion_date') && !normalized.containsKey('completionDate')) {
            normalized['completionDate'] = normalized['completion_date'];
          }
          if (normalized.containsKey('order') && normalized['order'] is String) {
            final str = normalized['order'] as String;
            final parsed = int.tryParse(str);
            if (parsed != null) normalized['order'] = parsed;
          }
          // Default status if missing
          normalized['status'] = normalized['status'] ?? 'WAITING';
          try {
            steps.add(ProjectStep.fromJson(normalized));
          } catch (_) {
            // Skip invalid step entries silently to keep UI resilient
          }
        }
      }
      steps.sort((a, b) => a.order.compareTo(b.order));
      return steps;
    } catch (e) {
      return [];
    }
  }
  
  /// Update project steps with a list of Step objects
  TaskCalendar withProjectSteps(List<ProjectStep> steps) {
    final jsonString = json.encode(steps.map((s) => s.toJson()).toList());
    return copyWith(
      projectSteps: jsonString,
      lastModified: DateTime.now(),
    );
  }
  
  /// Add or update a step in the project
  TaskCalendar addOrUpdateStep(ProjectStep step) {
    final current = projectStepsList;
    final index = current.indexWhere((s) => s.id == step.id);
    if (index != -1) {
      current[index] = step;
    } else {
      current.add(step);
    }
    return withProjectSteps(current);
  }
  
  /// Remove a step from the project by id
  TaskCalendar removeStep(String stepId) {
    final current = projectStepsList;
    current.removeWhere((s) => s.id == stepId);
    return withProjectSteps(current);
  }
  
  /// Reorder steps using provided ordered list of ids
  TaskCalendar reorderSteps(List<String> orderedIds) {
    final current = projectStepsList;
    final byId = {for (final s in current) s.id: s};
    final reordered = <ProjectStep>[];
    for (int i = 0; i < orderedIds.length; i++) {
      final id = orderedIds[i];
      final step = byId[id];
      if (step != null) {
        reordered.add(step.withOrder(i));
      }
    }
    // append any missing ones at the end preserving relative order
    for (final s in current) {
      if (!orderedIds.contains(s.id)) {
        reordered.add(s);
      }
    }
    return withProjectSteps(reordered);
  }
  
  /// Lookup helpers
  ProjectStep? getStepById(String stepId) {
    try {
      return projectStepsList.firstWhere((s) => s.id == stepId);
    } catch (_) {
      return null;
    }
  }
  
  bool hasStep(String stepId) => projectStepsList.any((s) => s.id == stepId);
} 

// Extension for project management operations
extension TaskCalendarProjectManagement on TaskCalendar {
  /// Check if this calendar has an author assigned
  bool get hasAuthor => flowitAuthor != null && flowitAuthor!.isNotEmpty;
  
  /// Check if this calendar has an owner assigned  
  bool get hasOwner => flowitOwner != null && flowitOwner!.isNotEmpty;
  
  /// Check if this calendar has a start date
  bool get hasStartDate => flowitStartedAt != null;
  
  /// Check if this calendar has an end date
  bool get hasEndDate => flowitEndedAt != null;
  
  /// Check if this calendar is completed (has end date)
  bool get isEnded => flowitEndedAt != null;
  
  /// Get the author name, or "Unknown" if none assigned
  String get authorDisplayName => flowitAuthor?.isNotEmpty == true ? flowitAuthor! : 'Unknown';
  
  /// Get the owner name, or "Unknown" if none assigned  
  String get ownerDisplayName => flowitOwner?.isNotEmpty == true ? flowitOwner! : 'Unknown';
  
  /// Create a copy with a new author
  TaskCalendar withAuthor(String? newAuthor) {
    return copyWith(
      flowitAuthor: newAuthor?.isEmpty == true ? null : newAuthor,
      lastModified: DateTime.now(),
    );
  }
  
  /// Create a copy with a new owner
  TaskCalendar withOwner(String? newOwner) {
    return copyWith(
      flowitOwner: newOwner?.isEmpty == true ? null : newOwner,
      lastModified: DateTime.now(),
    );
  }
  
  /// Create a copy with project ended at current time
  TaskCalendar markAsEnded() {
    return copyWith(
      flowitEndedAt: DateTime.now(),
      lastModified: DateTime.now(),
    );
  }
  
  /// Create a copy removing the end date (mark as ongoing)
  TaskCalendar markAsOngoing() {
    return copyWith(
      flowitEndedAt: null,
      lastModified: DateTime.now(),
    );
  }
} 
