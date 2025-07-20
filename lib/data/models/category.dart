// Category model for task and project categorization
// Represents a category with id, name, and color attributes for task organization

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import '../../core/theme/chart_theme.dart';

part 'category.freezed.dart';
part 'category.g.dart';

@HiveType(typeId: 50)
@freezed
class Category with _$Category {
  const factory Category({
    @HiveField(0) required String id,
    @HiveField(1) required String name,
    @HiveField(2) required int color, // Color value as int for JSON serialization
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) => _$CategoryFromJson(json);
}

// Extension methods for Category
extension CategoryExtension on Category {
  /// Get the Color object from the int value
  Color get colorValue => Color(this.color);
  
  /// Create a new Category with a Color object
  static Category createWithColor({
    required String id,
    required String name,
    required Color color,
  }) {
    return Category(
      id: id,
      name: name,
      color: color.value,
    );
  }
  
  /// Generate a unique ID for a category based on its name
  static String generateId(String name) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$name-$timestamp';
  }
  
  /// Generate a color for a category based on its position
  /// Uses FlowIt chart color series for consistent branding
  static Color generateCategoryColor(int index) {
    // Use FlowIt chart series colors for consistent branding
    final colors = [
      FlowItColors.primary,           // Blue Medium
      FlowItColors.waterGreen,        // Water Green
      FlowItColors.violet,            // Violet
      FlowItColors.greenApple,        // Green Apple
      FlowItColors.yellowDark,        // Yellow Dark
      FlowItColors.pink,              // Pink
      FlowItColors.coral,             // Coral
      FlowItColors.greenAnis,         // Green Anis
      FlowItColors.blueLight,         // Blue Light
      FlowItColors.violetLight,       // Violet Light
    ];
    return colors[index % colors.length];
  }
  
  /// Copy with a new color
  Category copyWithColor(Color newColor) {
    return copyWith(color: newColor.value);
  }
} 