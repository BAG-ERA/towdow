// Kanban model for project kanban board configurations
// Represents a kanban board with title, ordered categories, filters, and regex patterns
// Supports serialization for storage in TaskCalendar and UserPreferences

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'kanban.freezed.dart';
part 'kanban.g.dart';

@HiveType(typeId: 12)
@freezed
class Kanban with _$Kanban {
  const factory Kanban({
    @HiveField(0) required String title,
    @HiveField(1) @Default([]) List<String> orderedList, // List of category IDs in order
    @HiveField(2) @Default([]) List<String> filter, // List of category IDs to filter by
    @HiveField(3) String? regex, // Regex pattern to capture category names
  }) = _Kanban;

  factory Kanban.fromJson(Map<String, dynamic> json) => _$KanbanFromJson(json);
}

// Extension methods for Kanban
extension KanbanExtension on Kanban {
  /// Check if kanban has any configuration
  bool get hasConfiguration => 
      orderedList.isNotEmpty || filter.isNotEmpty || regex != null;
  
  /// Check if kanban is empty (no meaningful configuration)
  bool get isEmpty => 
      title.isEmpty && orderedList.isEmpty && filter.isEmpty && regex == null;
  
  /// Create a default kanban configuration
  static Kanban createDefault({String title = 'Default Kanban'}) {
    return Kanban(title: title);
  }
  
  /// Create a kanban with category-based columns
  static Kanban createCategoryBased({
    required String title,
    required List<String> categoryIds,
  }) {
    return Kanban(
      title: title,
      orderedList: categoryIds,
      filter: categoryIds, // Include all categories in filter by default
    );
  }
  
  /// Create a kanban with regex-based category detection
  static Kanban createRegexBased({
    required String title,
    required String regexPattern,
    List<String>? filterCategories,
  }) {
    return Kanban(
      title: title,
      filter: filterCategories ?? [],
      regex: regexPattern,
    );
  }
} 