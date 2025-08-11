// Projects list adaptive table
// Replaces DataTable with custom adaptive widgets for better layout control and touch UX
// Adapts columns to available space with priority order: project, status, progress, duedate, started, actions (actions stays right)
// Supports column sorting with clickable headers and fully-clickable rows

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/task_calendar.dart';
import '../../viewmodels/project_list_viewmodel.dart';
import '../navbar/project_popup_menu.dart';
import '../addaptative_table/addaptative_table_container.dart';
import '../addaptative_table/addaptative_table_head.dart';
import '../addaptative_table/addaptative_table_row.dart';

class ProjectsTable extends ConsumerStatefulWidget {
  final ProjectListState state;
  final Function(TaskCalendar) onProjectTap;
  final Function(String, ProjectWithStats) onProjectAction;
  final Function(ProjectSort) onSortChanged;
  final List<PopupMenuEntry<String>> Function(BuildContext, WidgetRef, TaskCalendar)? menuBuilder;
  final Widget? header;
  final List<ProjectWithStats>? projectsOverride;

  const ProjectsTable({
    super.key,
    required this.state,
    required this.onProjectTap,
    required this.onProjectAction,
    required this.onSortChanged,
    this.menuBuilder,
    this.header,
    this.projectsOverride,
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            _buildMobileList(context, ref),
          ] else ...[
            LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            
            // Only adapt columns if width has changed
            if (_lastAvailableWidth != availableWidth) {
              _lastAvailableWidth = availableWidth;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _adaptColumnsToWidth(availableWidth);
              });
            }
            
            final rows = (widget.projectsOverride ?? widget.state.filteredProjects);

            final header = _buildHeader(context);
            final rowWidgets = rows.asMap().entries.map((entry) {
              final projectWithStats = entry.value;
              return AddaptativeTableRow(
                onTap: () => widget.onProjectTap(projectWithStats.project),
                cells: _buildRowCells(context, ref, projectWithStats, _visibleColumns),
              );
            }).toList();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              child: AddaptativeTableContainer(
                header: header,
                rows: rowWidgets,
              ),
            );
          },
          ),
          ],
          if (widget.header != null) ...[
            const SizedBox(height: 12),
            widget.header!,
          ],
        ],
      ),
    );
  }

  Widget _buildMobileList(BuildContext context, WidgetRef ref) {
    final rows = widget.projectsOverride ?? widget.state.filteredProjects;
    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500);
    return Column(
      children: [
        for (final projectWithStats in rows)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onProjectTap(projectWithStats.project),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        projectWithStats.project.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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

  Widget _buildHeader(BuildContext context) {
    List<AddaptativeTableHeadCell> headCells = [];

    for (final columnType in _visibleColumns) {
      switch (columnType) {
        case ColumnType.project:
          headCells.add(_buildSortableHeadCell(
            context,
            label: 'Project',
            sortType: ProjectSort.name,
            icon: Icons.sort_by_alpha,
            flex: _flexFor(columnType),
          ));
          break;
        case ColumnType.actions:
          headCells.add(const AddaptativeTableHeadCell(label: '', flex: 1));
          break;
        case ColumnType.status:
          headCells.add(_buildSortableHeadCell(
            context,
            label: 'Status',
            sortType: ProjectSort.name,
            icon: Icons.sort,
            flex: _flexFor(columnType),
          ));
          break;
        case ColumnType.progress:
          headCells.add(_buildSortableHeadCell(
            context,
            label: 'Progress',
            sortType: ProjectSort.progress,
            icon: Icons.trending_up,
            flex: _flexFor(columnType),
          ));
          break;
        case ColumnType.duedate:
          headCells.add(_buildSortableHeadCell(
            context,
            label: 'Due Date',
            sortType: ProjectSort.lastModified,
            icon: Icons.schedule,
            flex: _flexFor(columnType),
          ));
          break;
        case ColumnType.started:
          headCells.add(_buildSortableHeadCell(
            context,
            label: 'Started',
            sortType: ProjectSort.created,
            icon: Icons.calendar_today,
            flex: _flexFor(columnType),
          ));
          break;
      }
    }

    return AddaptativeTableHead(cells: headCells);
  }

  AddaptativeTableHeadCell _buildSortableHeadCell(
    BuildContext context, {
    required String label,
    required ProjectSort sortType,
    required IconData icon,
    required int flex,
  }) {
    final isCurrentlySorted = widget.state.sortBy == sortType;
    final sortDirection = widget.state.sortDirection;

    IconData sortIcon;
    Color iconColor;

    if (isCurrentlySorted && sortDirection != SortDirection.none) {
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
      sortIcon = icon;
      iconColor = isCurrentlySorted
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    }

    return AddaptativeTableHeadCell(
      label: label,
      trailing: Icon(sortIcon, size: 16, color: iconColor),
      flex: flex,
      onTap: () => widget.onSortChanged(sortType),
    );
  }

  List<AddaptativeTableRowCell> _buildRowCells(
    BuildContext context,
    WidgetRef ref,
    ProjectWithStats projectWithStats,
    List<ColumnType> visibleColumns,
  ) {
    return visibleColumns.map((columnType) {
      switch (columnType) {
        case ColumnType.project:
          return AddaptativeTableRowCell(
            Text(
              projectWithStats.project.displayName,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            flex: _flexFor(columnType),
          );
        case ColumnType.actions:
          return AddaptativeTableRowCell(
            Align(
              alignment: Alignment.centerLeft,
              child: _buildActionMenu(context, ref, projectWithStats),
            ),
            flex: _flexFor(columnType),
          );
        case ColumnType.status:
          return AddaptativeTableRowCell(
            _buildStatusChip(context, projectWithStats.project.statusDisplayName),
            flex: _flexFor(columnType),
          );
        case ColumnType.progress:
          return AddaptativeTableRowCell(
            _buildProgressIndicator(context, projectWithStats.stats),
            flex: _flexFor(columnType),
          );
        case ColumnType.duedate:
          return AddaptativeTableRowCell(
            _buildDueDateText(context, projectWithStats),
            flex: _flexFor(columnType),
          );
        case ColumnType.started:
          return AddaptativeTableRowCell(
            Text(
              '${projectWithStats.project.created.day}/${projectWithStats.project.created.month}/${projectWithStats.project.created.year}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            flex: _flexFor(columnType),
          );
      }
    }).toList();
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
  int _flexFor(ColumnType type) {
    switch (type) {
      case ColumnType.project:
        return 4;
      case ColumnType.status:
        return 2;
      case ColumnType.progress:
        return 3;
      case ColumnType.duedate:
        return 2;
      case ColumnType.started:
        return 2;
      case ColumnType.actions:
        return 1;
    }
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
