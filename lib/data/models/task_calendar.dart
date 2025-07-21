// Task calendar model for CalDAV calendar information
// Represents projects at VCALENDAR level according to FlowIt specifications
// Supports persistent storage with Hive and synchronization tracking

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'dart:convert';
import 'task.dart';
import 'attendee.dart';
import 'category.dart';

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
    @HiveField(24) String? syncToken,
    
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
    @HiveField(18) String? flowitOwner, // X-FLOWIT-OWNER
    @HiveField(19) String? flowitTemplate, // X-FLOWIT-TEMPLATE
    @HiveField(20) @Default(1) int calendarOrder, // CALENDAR-ORDER
    @HiveField(21) String? organizer, // ORGANIZER
    @HiveField(22) @Default([]) List<Attendee> attendees, // ATTENDEE
    @HiveField(23) @Default('[]') String projectCategories, // JSON array of Category objects for project-level categories
    @HiveField(25) String? flowitDomain, // X-FLOWIT-DOMAIN - domain for grouping projects
    @HiveField(26) String? flowitStatus, // X-FLOWIT-STATUS - project status (DRAFT, CANCELED, ONGOING, STOPPED, ARCHIVE, COMPLETED, NEEDACTION, FAILED)
  }) = _TaskCalendar;

  factory TaskCalendar.fromJson(Map<String, dynamic> json) => _$TaskCalendarFromJson(json);
}

// Factory methods for creating task calendars
extension TaskCalendarFactory on TaskCalendar {
  static TaskCalendar createNew({
    required String path,
    required String displayName,
    String description = '',
    String? organizer,
    List<String> categories = const [],
    List<Attendee> attendees = const [],
    String? domain,
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
      organizer: organizer,
      attendees: attendees,
      // categories field removed - project categories now stored in projectCategories JSON
      flowitOwner: organizer,
      flowitDomain: domain,
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
      flowitStatus: flowitStatus,
      flowitKanban: flowitKanban ?? '[]',
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
} 
