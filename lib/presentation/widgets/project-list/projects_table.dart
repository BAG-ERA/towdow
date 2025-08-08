// Desktop table widget for projects list
// Displays projects in a Material Design DataTable with clickable rows
// Adapts columns to available space with priority order: project, status, progress, duedate, started, actions (actions stays right)
// Supports column sorting with clickable headers

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/task_calendar.dart';
import '../../viewmodels/project_list_viewmodel.dart';
import '../navbar/project_popup_menu.dart';

class ProjectsTable extends ConsumerStatefulWidget {
  final ProjectListState state;
  final Function(TaskCalendar) onProjectTap;
  final Function(String, ProjectWithStats) onProjectAction;
  final Function(ProjectSort) onSortChanged;
  final List<PopupMenuEntry<String>> Function(BuildContext, WidgetRef, TaskCalendar)? menuBuilder;

  const ProjectsTable({
    super.key,
    required this.state,
    required this.onProjectTap,
    required this.onProjectAction,
    required this.onSortChanged,
    this.menuBuilder,
  });

  @override
  ConsumerState<ProjectsTable> createState() => _ProjectsTableState();
}

class _ProjectsTableState extends ConsumerState<ProjectsTable> {
  List<ColumnType> _visibleColumns = [];
  double? _lastAvailableWidth;

  @override
  void initState() {
    super.initState();
    // Start with all columns
    _visibleColumns = [
      ColumnType.project,
      ColumnType.status,
      ColumnType.progress,
      ColumnType.duedate,
      ColumnType.started,
      ColumnType.actions,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            
            // Only adapt columns if width has changed
            if (_lastAvailableWidth != availableWidth) {
              _lastAvailableWidth = availableWidth;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _adaptColumnsToWidth(availableWidth);
              });
            }
            
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _ClickableDataTable(
                columns: _buildColumns(_visibleColumns),
                rows: widget.state.filteredProjects.map((projectWithStats) {
                  return DataRow(
                    cells: _buildCells(context, ref, projectWithStats, _visibleColumns),
                  );
                }).toList(),
                onRowTap: (index) {
                  final projectWithStats = widget.state.filteredProjects[index];
                  widget.onProjectTap(projectWithStats.project);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _adaptColumnsToWidth(double availableWidth) {
    // Priority order: project (always), then middle columns, then actions (always right)
    const middleColumns = [
      ColumnType.status,
      ColumnType.progress,
      ColumnType.duedate,
      ColumnType.started,
    ];

    // Always include project and actions
    List<ColumnType> testColumns = [ColumnType.project];
    
    // Add middle columns from left to right until they don't fit
    for (final column in middleColumns) {
      final testColumnsWithNewColumn = [...testColumns, column, ColumnType.actions];
      final estimatedWidth = _estimateTableWidth(testColumnsWithNewColumn, availableWidth);
      
      if (estimatedWidth <= availableWidth) {
        testColumns.add(column);
      } else {
        break;
      }
    }
    
    // Always add actions at the end
    testColumns.add(ColumnType.actions);

    if (_visibleColumns != testColumns) {
      setState(() {
        _visibleColumns = testColumns;
      });
    }
  }

  double _estimateTableWidth(List<ColumnType> columns, double availableWidth) {
    // Estimate column widths based on content type
    const columnWidths = {
      ColumnType.project: 200.0,
      ColumnType.actions: 80.0,
      ColumnType.status: 120.0,
      ColumnType.progress: 140.0,
      ColumnType.duedate: 120.0,
      ColumnType.started: 120.0,
    };

    double totalWidth = 0.0;
    for (final column in columns) {
      totalWidth += columnWidths[column] ?? 100.0;
    }

    // Add some padding and margin
    totalWidth += 32.0;

    return totalWidth;
  }

  List<DataColumn> _buildColumns(List<ColumnType> visibleColumns) {
    return visibleColumns.map((columnType) {
      switch (columnType) {
        case ColumnType.project:
          return _buildSortableColumn(
            '',
            ProjectSort.name,
            Icons.sort_by_alpha,
          );
        case ColumnType.actions:
          return const DataColumn(label: Text(''));
        case ColumnType.status:
          return _buildSortableColumn(
            'Status',
            ProjectSort.name, // Status sorting uses name as proxy
            Icons.sort,
          );
        case ColumnType.progress:
          return _buildSortableColumn(
            'Progress',
            ProjectSort.progress,
            Icons.trending_up,
          );
        case ColumnType.duedate:
          return _buildSortableColumn(
            'Due Date',
            ProjectSort.lastModified, // Use lastModified as proxy for due date
            Icons.schedule,
          );
        case ColumnType.started:
          return _buildSortableColumn(
            'Started',
            ProjectSort.created,
            Icons.calendar_today,
          );
      }
    }).toList();
  }

  DataColumn _buildSortableColumn(String label, ProjectSort sortType, IconData icon) {
    final isCurrentlySorted = widget.state.sortBy == sortType;
    final sortDirection = widget.state.sortDirection;
    
    IconData sortIcon;
    Color iconColor;
    
    if (isCurrentlySorted && sortDirection != SortDirection.none) {
      // Show direction-specific icon
      switch (sortDirection) {
        case SortDirection.ascending:
          sortIcon = Icons.keyboard_arrow_up;
          iconColor = Theme.of(context).colorScheme.primary;
          break;
        case SortDirection.descending:
          sortIcon = Icons.keyboard_arrow_down;
          iconColor = Theme.of(context).colorScheme.primary;
          break;
        case SortDirection.none:
          sortIcon = icon;
          iconColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
          break;
      }
    } else {
      // Show default icon
      sortIcon = icon;
      iconColor = isCurrentlySorted 
        ? Theme.of(context).colorScheme.primary 
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    }
    
    return DataColumn(
      label: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () => widget.onSortChanged(sortType),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 4),
              Icon(
                sortIcon,
                size: 16,
                color: iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DataCell> _buildCells(BuildContext context, WidgetRef ref, ProjectWithStats projectWithStats, List<ColumnType> visibleColumns) {
    return visibleColumns.map((columnType) {
      switch (columnType) {
        case ColumnType.project:
          return _buildClickableCell(
            Text(projectWithStats.project.displayName, 
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            () => widget.onProjectTap(projectWithStats.project),
          );
        case ColumnType.actions:
          return DataCell(
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {}, // Prevent row click
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  alignment: Alignment.center,
                  child: _buildActionMenu(context, ref, projectWithStats),
                ),
              ),
            ),
          );
        case ColumnType.status:
          return _buildClickableCell(
            _buildStatusChip(context, projectWithStats.project.statusDisplayName),
            () => widget.onProjectTap(projectWithStats.project),
          );
        case ColumnType.progress:
          return _buildClickableCell(
            _buildProgressIndicator(context, projectWithStats.stats),
            () => widget.onProjectTap(projectWithStats.project),
          );
        case ColumnType.duedate:
          return _buildClickableCell(
            _buildDueDateText(context, projectWithStats),
            () => widget.onProjectTap(projectWithStats.project),
          );
        case ColumnType.started:
          return _buildClickableCell(
            Text('${projectWithStats.project.created.day}/${projectWithStats.project.created.month}/${projectWithStats.project.created.year}', 
                style: Theme.of(context).textTheme.bodySmall),
            () => widget.onProjectTap(projectWithStats.project),
          );
      }
    }).toList();
  }

  DataCell _buildClickableCell(Widget child, VoidCallback onTap) {
    return DataCell(
      Container(
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    Color chipColor;
    IconData icon;
    String displayText;
    
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        chipColor = Colors.green;
        icon = Icons.check_circle_rounded;
        displayText = 'Completed';
        break;
      case 'CANCELED':
      case 'CANCELLED':
        chipColor = Colors.red;
        icon = Icons.cancel_rounded;
        displayText = 'Canceled';
        break;
      case 'ONGOING':
        chipColor = Theme.of(context).colorScheme.primary;
        icon = Icons.play_circle_rounded;
        displayText = 'Ongoing';
        break;
      case 'STOPPED':
        chipColor = Colors.orange;
        icon = Icons.pause_circle_rounded;
        displayText = 'Stopped';
        break;
      case 'ARCHIVE':
        chipColor = Colors.grey;
        icon = Icons.archive_rounded;
        displayText = 'Archived';
        break;
      case 'DRAFT':
        chipColor = Colors.blue;
        icon = Icons.edit_note_rounded;
        displayText = 'Draft';
        break;
      case 'NEEDACTION':
      case 'NEEDS-ACTION':
        chipColor = Theme.of(context).colorScheme.primary;
        icon = Icons.pending_actions_rounded;
        displayText = 'Needs Action';
        break;
      case 'FAILED':
        chipColor = Colors.red;
        icon = Icons.error_rounded;
        displayText = 'Failed';
        break;
      default:
        chipColor = Theme.of(context).colorScheme.primary;
        icon = Icons.play_circle_rounded;
        displayText = status.replaceAll('-', ' ').toTitleCase();
    }

    return Chip(
      label: Text(displayText, style: TextStyle(color: chipColor, fontSize: 12, fontWeight: FontWeight.w500)),
      avatar: Icon(icon, size: 16, color: chipColor),
      backgroundColor: chipColor.withValues(alpha: 0.1),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildDueDateText(BuildContext context, ProjectWithStats projectWithStats) {
    return Text(
      'No due date',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, ProjectStats stats) {
    final percentage = stats.progressPercentage;
    final color = percentage == 100 ? Colors.green : Theme.of(context).colorScheme.primary;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(width: 8),
        Text('$percentage%', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: color)),
      ],
    );
  }

  Widget _buildActionMenu(BuildContext context, WidgetRef ref, ProjectWithStats projectWithStats) {
    if (widget.menuBuilder != null) {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded),
        tooltip: 'Options',
        onSelected: (value) => widget.onProjectAction(value, projectWithStats),
        itemBuilder: (context) => widget.menuBuilder!(context, ref, projectWithStats.project),
      );
    }
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      tooltip: 'Options',
      onSelected: (value) => widget.onProjectAction(value, projectWithStats),
      itemBuilder: (context) => ProjectPopupMenu.getMenuItems(context, ref, project: projectWithStats.project),
    );
  }
}

class _ClickableDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final Function(int) onRowTap;

  const _ClickableDataTable({
    required this.columns,
    required this.rows,
    required this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: columns,
      rows: rows.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        
        return DataRow(
          cells: row.cells.map((cell) {
            // Wrap each cell in a GestureDetector to handle row clicks
            return DataCell(
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onRowTap(index),
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: cell.child,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

enum ColumnType {
  project,
  actions,
  status,
  progress,
  duedate,
  started,
}

extension StringExtension on String {
  String toTitleCase() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
