// Category chip component for task items
// Displays individual category with consistent styling using the new Category model

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/category.dart';

class CategoryChip extends ConsumerWidget {
  final String categoryId;
  final String? projectPath; // Optional project path for better performance

  const CategoryChip({
    super.key,
    required this.categoryId,
    this.projectPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Try to get category from project-specific provider first for better performance
    if (projectPath != null) {
      final viewModelState = ref.watch(projectCategoryViewModelProvider(projectPath!));
      final category = viewModelState.projectCategories
          .where((cat) => cat.id == categoryId)
          .firstOrNull;
      
      if (category != null) {
        return _buildChip(context, category.name, category.colorValue);
      }
    }
    
    // Fallback: use general category viewmodel to retrieve by id via state
    final categoryState = ref.watch(categoryViewModelProvider);
    final found = categoryState.categories.firstWhere(
      (cat) => cat.id == categoryId,
      orElse: () => const Category(id: '', name: 'Unknown Category', color: 0xFF9E9E9E),
    );
    final isUnknown = found.id.isEmpty;
    final color = isUnknown ? Colors.grey : found.colorValue;
    return _buildChip(context, isUnknown ? 'Unknown Category' : found.name, color);
  }
  
  Widget _buildChip(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
} 