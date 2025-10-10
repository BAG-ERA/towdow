// Reusable Kanban board component for different project views
// Supports dynamic columns with custom grouping logic

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task.dart';
import 'task_item/task_item.dart';
import 'utils/mobile_delayed_draggable.dart';
import 'kanban_board/draggable_column_header.dart';
import 'kanban_board/column_drop_zone.dart';

class KanbanColumn {
  final String id;
  final String title;
  final String subtitle;
  final List<Task> tasks;
  final Color color;
  final IconData icon;
  final VoidCallback? onAddTask;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const KanbanColumn({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tasks,
    required this.color,
    required this.icon,
    this.onAddTask,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });
}

class KanbanBoard extends ConsumerWidget {
  final List<KanbanColumn> columns;
  final Function(Task, String)? onTaskMoved;
  final Function(Task)? onTaskTap;
  final Function(Task)? onTaskToggle;
  final Function(Task)? onTaskUpdated;
  final Function(Task)? onTaskDeleted;
  final Function(String)? onColumnHide;
  final double? height;
  final Widget? hiddenColumnsButton;
  final VoidCallback? onAddCategory;
  // Column drag and drop callbacks
  final Function(String, int)? onColumnMoved;
  final String? draggingColumnId;
  final bool isReorderingColumns;
  final Function(String)? onColumnDragStarted;
  final VoidCallback? onColumnDragEnded;

  const KanbanBoard({
    super.key,
    required this.columns,
    this.onTaskMoved,
    this.onTaskTap,
    this.onTaskToggle,
    this.onTaskUpdated,
    this.onTaskDeleted,
    this.onColumnHide,
    this.height,
    this.hiddenColumnsButton,
    this.onAddCategory,
    this.onColumnMoved,
    this.draggingColumnId,
    this.isReorderingColumns = false,
    this.onColumnDragStarted,
    this.onColumnDragEnded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = ScrollController();
    
    return GestureDetector(
      onTap: () {
        // Reset drag state when clicking anywhere on the board
        if (isReorderingColumns) {
          onColumnDragEnded?.call();
        }
      },
      child: SizedBox(
        height: height ?? MediaQuery.of(context).size.height * 0.7,
        child: LayoutBuilder(
        builder: (context, constraints) {
          const targetColumnWidth = 360.0;
          const collapsedColumnWidth = 60.0;
          const columnSpacing = 16.0;
          
          // Calculate total width needed for all columns (considering collapsed columns)
          final totalColumns = columns.length + (hiddenColumnsButton != null ? 1 : 0) + (onAddCategory != null ? 1 : 0);
          final totalSpacing = (totalColumns - 1) * columnSpacing;
          
          // Calculate width based on collapsed/expanded columns
          double totalWidth = totalSpacing;
          for (final column in columns) {
            totalWidth += column.isCollapsed ? collapsedColumnWidth : targetColumnWidth;
          }
          if (hiddenColumnsButton != null) totalWidth += targetColumnWidth;
          if (onAddCategory != null) totalWidth += targetColumnWidth;
          
          return ScrollbarTheme(
            data: ScrollbarThemeData(
              thumbColor: MaterialStateProperty.resolveWith((states) {
                final base = Theme.of(context).colorScheme.onSurface;
                if (states.contains(MaterialState.dragged)) {
                  return base.withOpacity(0.55);
                }
                if (states.contains(MaterialState.hovered)) {
                  return base.withOpacity(0.28);
                }
                return base.withOpacity(0.06);
              }),
              trackColor: MaterialStateProperty.resolveWith((states) {
                final base = Theme.of(context).colorScheme.onSurface;
                if (states.contains(MaterialState.dragged)) {
                  return base.withOpacity(0.18);
                }
                if (states.contains(MaterialState.hovered)) {
                  return base.withOpacity(0.10);
                }
                return base.withOpacity(0.03);
              }),
              trackBorderColor: MaterialStateProperty.all(Colors.transparent),
              thickness: MaterialStateProperty.all(8.0),
              radius: const Radius.circular(4.0),
            ),
            child: Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 8.0,
              radius: const Radius.circular(4.0),
              controller: scrollController,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: totalWidth),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Build columns with drop zones between them
                      ..._buildColumnsWithDropZones(context),
                      if (hiddenColumnsButton != null) ...[
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 200,
                          child: hiddenColumnsButton!,
                        ),
                      ],
                      if (onAddCategory != null) ...[
                        const SizedBox(width: 16),
                        Container(
                          width: 60,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onAddCategory,
                              borderRadius: BorderRadius.circular(12),
                              child: const Center(
                                child: Icon(
                                  Icons.add,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        ),
      ),
    );
  }

  /// Build columns with drop zones between them for column reordering
  List<Widget> _buildColumnsWithDropZones(BuildContext context) {
    const targetColumnWidth = 360.0;
    const collapsedColumnWidth = 60.0;
    
    // Get the kanban board height
    final boardHeight = height ?? MediaQuery.of(context).size.height * 0.7;
    
    final widgets = <Widget>[];
    
    for (int i = 0; i < columns.length; i++) {
      final column = columns[i];
      
      // Add drop zone before the first column
      if (i == 0 && isReorderingColumns) {
        widgets.add(
          SizedBox(
            height: boardHeight, // Match the kanban board height
            child: ColumnDropZone(
              dropIndex: 0,
              isVisible: draggingColumnId != null,
              onColumnDropped: onColumnMoved ?? (_, __) {},
            ),
          ),
        );
      }
      
      // Add the column
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: SizedBox(
            width: column.isCollapsed ? collapsedColumnWidth : targetColumnWidth,
            child: KanbanColumnWidget(
              column: column,
              onTaskMoved: onTaskMoved,
              onTaskTap: onTaskTap,
              onTaskToggle: onTaskToggle,
              onTaskUpdated: onTaskUpdated,
              onTaskDeleted: onTaskDeleted,
              onColumnHide: onColumnHide,
              draggingColumnId: draggingColumnId,
              isReorderingColumns: isReorderingColumns,
              onColumnDragStarted: onColumnDragStarted,
              onColumnDragEnded: onColumnDragEnded,
            ),
          ),
        ),
      );
      
      // Add drop zone after each column (except the last one)
      if (i < columns.length - 1 && isReorderingColumns) {
        widgets.add(
          SizedBox(
            height: boardHeight, // Match the kanban board height
            child: ColumnDropZone(
              dropIndex: i + 1,
              isVisible: draggingColumnId != null,
              onColumnDropped: onColumnMoved ?? (_, __) {},
            ),
          ),
        );
      }
    }
    
    // Add drop zone after the last column
    if (columns.isNotEmpty && isReorderingColumns) {
      widgets.add(
        SizedBox(
          height: boardHeight, // Match the kanban board height
          child: ColumnDropZone(
            dropIndex: columns.length,
            isVisible: draggingColumnId != null,
            onColumnDropped: onColumnMoved ?? (_, __) {},
          ),
        ),
      );
    }
    
    return widgets;
  }
}

class KanbanColumnWidget extends ConsumerWidget {
  final KanbanColumn column;
  final Function(Task, String)? onTaskMoved;
  final Function(Task)? onTaskTap;
  final Function(Task)? onTaskToggle;
  final Function(Task)? onTaskUpdated;
  final Function(Task)? onTaskDeleted;
  final Function(String)? onColumnHide;
  final String? draggingColumnId;
  final bool isReorderingColumns;
  final Function(String)? onColumnDragStarted;
  final VoidCallback? onColumnDragEnded;

  const KanbanColumnWidget({
    super.key,
    required this.column,
    this.onTaskMoved,
    this.onTaskTap,
    this.onTaskToggle,
    this.onTaskUpdated,
    this.onTaskDeleted,
    this.onColumnHide,
    this.draggingColumnId,
    this.isReorderingColumns = false,
    this.onColumnDragStarted,
    this.onColumnDragEnded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (column.isCollapsed) {
      return _buildCollapsedColumn(context);
    }
    
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Column Header
              DraggableColumnHeader(
                columnId: column.id,
                title: column.title,
                subtitle: column.subtitle,
                color: column.color,
                icon: column.icon,
                taskCount: column.tasks.length,
                isCollapsed: column.isCollapsed,
                onToggleCollapse: column.onToggleCollapse,
                onColumnHide: onColumnHide,
                isDragging: draggingColumnId == column.id,
                isReorderingColumns: isReorderingColumns,
                onDragStarted: onColumnDragStarted,
                onDragEnded: () => onColumnDragEnded?.call(),
              ),
              
              // Tasks List
              Expanded(
            child: onTaskMoved != null
                ? DragTarget<Task>(
                    onAcceptWithDetails: (details) {
                      onTaskMoved!(details.data, column.id);
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isHovering = candidateData.isNotEmpty;
                      
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isHovering 
                              ? column.color.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          border: isHovering
                              ? Border.all(
                                  color: column.color.withValues(alpha: 0.5),
                                  width: 2,
                                )
                              : null,
                        ),
                        child: column.tasks.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isHovering ? Icons.move_to_inbox_rounded : column.icon,
                                      size: 32,
                                      color: isHovering 
                                          ? column.color
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isHovering ? 'Drop here to assign' : 'No tasks',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: isHovering 
                                            ? column.color
                                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.only(
                                  left: 8,
                                  right: 8,
                                  top: 8,
                                  bottom: column.onAddTask != null ? 64 : 8,
                                ),
                                itemCount: column.tasks.length,
                                itemBuilder: (context, index) {
                                  final task = column.tasks[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: MobileDelayedDraggableTask(
                                      task: task,
                                      feedback: Material(
                                        elevation: 4,
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: 280,
                                          child: TaskItem(
                                            task: task,
                                            onTap: null, // Disable tap during drag
                                            onToggleComplete: null, // Disable toggle during drag
                                            onTaskUpdated: null, // Disable updates during drag
                                            onTaskDeleted: null, // Disable deletion during drag
                                          ),
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.5,
                                        child: TaskItem(
                                          task: task,
                                          onTap: null,
                                          onToggleComplete: null,
                                          onTaskUpdated: null,
                                          onTaskDeleted: null,
                                        ),
                                      ),
                                      child: TaskItem(
                                        task: task,
                                        onTap: onTaskTap != null ? () => onTaskTap!(task) : null,
                                        onToggleComplete: onTaskToggle != null ? () => onTaskToggle!(task) : null,
                                        onTaskUpdated: onTaskUpdated != null ? (updatedTask) => onTaskUpdated!(updatedTask) : null,
                                        onTaskDeleted: onTaskDeleted != null ? () => onTaskDeleted!(task) : null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      );
                    },
                  )
                : column.tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              column.icon,
                              size: 32,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No tasks',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(
                          left: 8,
                          right: 8,
                          top: 8,
                          bottom: column.onAddTask != null ? 64 : 8,
                        ),
                        itemCount: column.tasks.length,
                        itemBuilder: (context, index) {
                          final task = column.tasks[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TaskItem(
                              task: task,
                              onTap: onTaskTap != null ? () => onTaskTap!(task) : null,
                              onToggleComplete: onTaskToggle != null ? () => onTaskToggle!(task) : null,
                              onTaskUpdated: onTaskUpdated != null ? (updatedTask) => onTaskUpdated!(updatedTask) : null,
                              onTaskDeleted: onTaskDeleted != null ? () => onTaskDeleted!(task) : null,
                            ),
                          );
                        },
                      ),
          ),
            ],
          ),
        ),
        
        // Add Task Button - Positioned absolutely at the bottom
        if (column.onAddTask != null)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: OutlinedButton.icon(
              onPressed: column.onAddTask,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Task'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: column.color,
                side: BorderSide(color: column.color.withValues(alpha: 0.5)),
              ),
            ),
          ),
      ],
    );
  }

  /// Build collapsed column (60px width with icon and expand button)
  Widget _buildCollapsedColumn(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Collapsed Header - Just icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: column.color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: column.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                column.icon,
                color: column.color,
                size: 16,
              ),
            ),
          ),
          
          // Collapsed Body - Vertical text and expand button
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Vertical text
                  RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      column.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: column.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Task count
                  Text(
                    '${column.tasks.length}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: column.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Expand button
                  IconButton(
                    onPressed: column.onToggleCollapse,
                    icon: Icon(
                      Icons.keyboard_double_arrow_right,
                      color: column.color,
                      size: 20,
                    ),
                    tooltip: 'Expand ${column.title}',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

 
