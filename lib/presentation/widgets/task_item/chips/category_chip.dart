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
    
    // Fallback to general category repository
    final categoryRepository = ref.watch(categoryRepositoryProvider);
    
    return FutureBuilder(
      future: categoryRepository.getCategoryById(categoryId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final result = snapshot.data!;
          return result.when(
            success: (category) {
              if (category != null) {
                return _buildChip(context, category.name, category.colorValue);
              } else {
                return _buildChip(context, 'Unknown Category', Colors.grey);
              }
            },
            failure: (_) => _buildChip(context, 'Error', Colors.red),
          );
        } else if (snapshot.hasError) {
          return _buildChip(context, 'Error', Colors.red);
        } else {
          // Loading or unknown category
          return _buildChip(context, 'Loading...', Colors.grey);
        }
      },
    );
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