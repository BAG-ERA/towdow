// Reorder drop zone widget for project reordering within the same domain
// Shows small spaces between projects that expand when hovering with a project from the same domain

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logger.dart';
import 'project_item_widget.dart';
import 'drag_state_provider.dart';

class ReorderDropZone extends ConsumerStatefulWidget {
  final String? targetDomain; // Domain this drop zone belongs to (null for no-domain)
  final int insertIndex; // Index where the project will be inserted
  final Function(ProjectDragData dragData, int insertIndex) onProjectReorder;

  const ReorderDropZone({
    super.key,
    required this.targetDomain,
    required this.insertIndex,
    required this.onProjectReorder,
  });

  @override
  ConsumerState<ReorderDropZone> createState() => _ReorderDropZoneState();
}

class _ReorderDropZoneState extends ConsumerState<ReorderDropZone> {
  /// Check if the dragged project can be reordered in this zone
  bool _canAcceptProject(ProjectDragData dragData) {
    return _isSameDomain(dragData.currentDomain, widget.targetDomain);
  }

  /// Check if two domains are the same (treating null as 'NO_DOMAIN')
  bool _isSameDomain(String? domain1, String? domain2) {
    final normalizedDomain1 = domain1 ?? 'NO_DOMAIN';
    final normalizedDomain2 = domain2 ?? 'NO_DOMAIN';
    return normalizedDomain1 == normalizedDomain2;
  }

  void _handleProjectDrop(ProjectDragData dragData) {
    if (!_canAcceptProject(dragData)) {
      return;
    }
    
          AppLogger.info('ReorderDropZone: Reordering project ${dragData.project.displayName} to index ${widget.insertIndex}');
    
    // Provide haptic feedback
    HapticFeedback.lightImpact();
    
    // Call the reorder callback
    widget.onProjectReorder(dragData, widget.insertIndex);
  }

  @override
  Widget build(BuildContext context) {
    final dragState = ref.watch(dragStateProvider);
    
    return DragTarget<ProjectDragData>(
      onWillAcceptWithDetails: (details) {
        final canAccept = _canAcceptProject(details.data);
        AppLogger.debug('ReorderDropZone: Will accept? $canAccept for project ${details.data.project.displayName}');
        return canAccept;
      },
      onAcceptWithDetails: (details) => _handleProjectDrop(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        final isDraggingCompatibleProject = dragState.isDraggingProject && 
            _isDraggingCompatibleProject(dragState.draggedProjectDomain);
        
        // Determine height: 0 when not dragging, 4px when dragging but not hovering, 48px when hovering
        double height = 0;
        if (isDraggingCompatibleProject) {
          height = isHovering ? 48 : 4; // Minimal separator when dragging, full height when hovering
        }
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isHovering 
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(isHovering ? 8 : 2),
            border: isHovering 
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                    width: 2,
                  )
                : null,
          ),
          child: isHovering 
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Drop here to reorder',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : null, // Transparent separator when dragging but not hovering
        );
      },
    );
  }

  /// Check if the currently dragged project is compatible with this drop zone
  bool _isDraggingCompatibleProject(String? draggedProjectDomain) {
    return _isSameDomain(draggedProjectDomain, widget.targetDomain);
  }
} 