// Column drop zone widget for kanban board column reordering
// Provides visual feedback for drop targets between columns
// Handles column drop events and delegates to ViewModel

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ColumnDropZone extends ConsumerWidget {
  final int dropIndex;
  final bool isVisible;
  final Function(String, int) onColumnDropped;

  const ColumnDropZone({
    super.key,
    required this.dropIndex,
    required this.isVisible,
    required this.onColumnDropped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        return true;
      },
      onAcceptWithDetails: (details) {
        onColumnDropped(details.data, dropIndex);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isVisible ? 80.0 : 0.0,
          height: double.infinity, // Take full height
          margin: const EdgeInsets.only(left: 0, right: 12),
          decoration: BoxDecoration(
            color: isHovering 
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)
                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: isHovering
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: isHovering
              ? Center(
                  child: Icon(
                    Icons.add,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 20,
                  ),
                )
              : null,
        );
      },
    );
  }
}
