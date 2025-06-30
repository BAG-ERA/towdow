// Category chip component for task items
// Displays individual category with consistent styling

import 'package:flutter/material.dart';

class CategoryChip extends StatelessWidget {
  final String category;

  const CategoryChip({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }
} 