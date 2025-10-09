// Workflow detail screen - thin wrapper around ProjectDetailScreen for separate route and future specialization

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import '../../../core/result.dart';
import '../../widgets/utils/styled_tab_bar.dart';
import '../../../data/models/task_calendar.dart';
import '../../../data/models/task.dart';
import '../../../data/providers/providers.dart';
import '../../widgets/project_detail/project_infos_widget.dart';
import '../../widgets/project_detail/project_notes_quick_panel.dart';
import '../../widgets/project_detail/project_note_view.dart';
import '../../../data/models/journal.dart';
import '../../widgets/utils/tasklist_toolbar.dart';
import '../../widgets/utils/popup/requirement_mapping_dialog.dart';
import '../../widgets/project_detail/project_task_step_view.dart';
import '../../widgets/project_detail/project_bottleneck_view.dart';
// projectProvider removed; use calendarListProvider to read project state
import '../../widgets/project_detail/project_warnings_banner.dart';
import '../../widgets/utils/voice_feedback_button.dart';
import '../../widgets/common/monitoring_status_widget.dart';

class WorkflowDetailScreen extends ConsumerStatefulWidget {
  final String workflowPath;
  const WorkflowDetailScreen({super.key, required this.workflowPath});

  @override
  ConsumerState<WorkflowDetailScreen> createState() => _WorkflowDetailScreenState();
}

class _WorkflowDetailScreenState extends ConsumerState<WorkflowDetailScreen> {
  int _selectedTabIndex = 0;
  bool _showNotesPanel = false;
  Journal? _openedNote;
  bool _isDetailColumnCollapsed = false; // New state for column collapse

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(projectTasksProvider(widget.workflowPath));
    final encoded = widget.workflowPath.replaceAll('@', '%40');
    final projectAsync = ref.watch(calendarListProvider).whenData((cals) {
      try {
        return cals.firstWhere((c) => c.path == encoded);
      } catch (_) {
        return null;
      }
    });

    final isDesktop = MediaQuery.of(context).size.width >= 800.0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: isDesktop ? _buildDesktopLayout(context, projectAsync, tasksAsync) : _buildMobileLayout(context, projectAsync, tasksAsync),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, AsyncValue<TaskCalendar?> projectAsync, AsyncValue<List<Task>> tasksAsync) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
                      width: _isDetailColumnCollapsed ? 60 : 320,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SingleChildScrollView(
                      child: _isDetailColumnCollapsed 
                          ? _buildCollapsedHeader(context, projectAsync)
                          : _buildDesktopHeader(context, projectAsync, tasksAsync),
                    ),
                    // Animated note overlay (desktop) - only show when not collapsed
                    if (!_isDetailColumnCollapsed)
                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 360),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) {
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(anim),
                                child: child,
                              ),
                            );
                          },
                          child: _openedNote != null
                              ? ProjectNoteView(
                                  key: const ValueKey('wf_note_open_desktop'),
                                  journal: _openedNote!,
                                  onSaved: () {
                                    setState(() {
                                      _openedNote = null;
                                      _showNotesPanel = false;
                                    });
                                  },
                                )
                              : const SizedBox.shrink(key: ValueKey('wf_note_closed_desktop')),
                        ),
                      ),
                    // Animated quick panel (desktop) - only show when not collapsed
                    if (!_isDetailColumnCollapsed)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 16,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 360),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, anim) {
                              return FadeTransition(
                                opacity: anim,
                                child: SizeTransition(
                                  sizeFactor: anim,
                                  axisAlignment: -1.0,
                                  child: child,
                                ),
                              );
                            },
                            child: (_showNotesPanel && _openedNote == null)
                                ? ProjectNotesQuickPanel(
                                    key: const ValueKey('wf_panel_open_desktop'),
                                    projectPath: widget.workflowPath,
                                    onOpenNote: (j) => setState(() { _openedNote = j; _showNotesPanel = false; }),
                                    onCreateNew: () => _createNewNote(),
                                  )
                                : const SizedBox.shrink(key: ValueKey('wf_panel_closed_desktop')),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Notes button - only show when not collapsed
              if (!_isDetailColumnCollapsed) ...[
                const SizedBox(height: 8),
                Container(
                  height: 56,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      if (_openedNote != null) {
                        _openedNote = null;
                        _showNotesPanel = false;
                      } else {
                        _showNotesPanel = !_showNotesPanel;
                      }
                    }),
                    icon: Icon(_openedNote != null
                        ? Icons.close_rounded
                        : (_showNotesPanel ? Icons.expand_more_rounded : Icons.notes_rounded)),
                    label: Text(
                      _openedNote != null
                          ? AppLocalizations.of(context)!.closeNote
                          : (_showNotesPanel ? AppLocalizations.of(context)!.hideNotes : AppLocalizations.of(context)!.showNotes),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Separator between columns
        Container(
          width: 1,
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        Expanded(
          child: Column(
            children: [
              _buildTopActionRow(context, projectAsync),
              _buildViewTabs(context),
              Expanded(child: _buildTabContent(context, tasksAsync)),
              // Bottom toolbar with search and create task button (same as Project screen)
              TaskListToolbar(
                projectPath: widget.workflowPath,
                projectName: projectAsync.asData?.value?.displayName,
                workflowVariant: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, AsyncValue<TaskCalendar?> projectAsync, AsyncValue<List<Task>> tasksAsync) {
    return Stack(
      children: [
        Column(
          children: [
        // Warnings banner on mobile (if any)
        projectAsync.when(
          data: (project) => project != null
              ? ProjectWarningsBanner(project: project, tasksAsync: tasksAsync)
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        projectAsync.when(
          data: (project) => project != null
              ? Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        backgroundColor: Colors.transparent,
                        collapsedBackgroundColor: Colors.transparent,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                        title: tasksAsync.when(
                          data: (tasks) {
                            final completed = tasks.where((t) => t.status == 'COMPLETED').length;
                            final total = tasks.length;
                            return Text(
                              'Tasks $completed/$total',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            );
                          },
                          loading: () => Text(
                            'Tasks ...',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          error: (_, __) => Text(
                            'Tasks 0/0',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ProjectInfosWidget(project: project, tasksAsync: tasksAsync, onProjectUpdated: (p) {}),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        height: 1,
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        Expanded(child: _buildTabContent(context, tasksAsync)),
        // Bottom toolbar with search and create task button (same as Project screen)
        TaskListToolbar(
          projectPath: widget.workflowPath,
          projectName: projectAsync.asData?.value?.displayName,
          workflowVariant: true,
        ),
          ],
        ),

        // Dim overlay for quick panel
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: (_showNotesPanel && _openedNote == null)
                ? GestureDetector(
                    onTap: () => setState(() => _showNotesPanel = false),
                    child: Container(color: Colors.black.withOpacity(0.35)),
                  )
                : const SizedBox.shrink(),
          ),
        ),

        // Note overlay
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(anim),
                  child: child,
                ),
              );
            },
            child: _openedNote != null
                ? ProjectNoteView(
                    key: const ValueKey('wf_note_open'),
                    journal: _openedNote!,
                    onSaved: () {
                      setState(() {
                        _openedNote = null;
                        _showNotesPanel = false;
                      });
                    },
                  )
                : const SizedBox.shrink(key: ValueKey('wf_note_closed')),
          ),
        ),

        // Quick panel
        Positioned(
          left: 12,
          right: 12,
          bottom: 128,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) {
              return FadeTransition(
                opacity: anim,
                child: SizeTransition(sizeFactor: anim, axisAlignment: -1.0, child: child),
              );
            },
            child: (_showNotesPanel && _openedNote == null)
                ? ProjectNotesQuickPanel(
                    key: const ValueKey('wf_panel_open'),
                    projectPath: widget.workflowPath,
                    onOpenNote: (j) => setState(() { _openedNote = j; _showNotesPanel = false; }),
                    onCreateNew: () => _createNewNote(),
                  )
                : const SizedBox.shrink(key: ValueKey('wf_panel_closed')),
          ),
        ),

        // Floating Show/Close button
        AnimatedPositioned(
          left: 16,
          right: 16,
          bottom: _openedNote != null ? 16 : 64,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOut,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 40,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    if (_openedNote != null) {
                      _openedNote = null;
                      _showNotesPanel = false;
                    } else {
                      _showNotesPanel = !_showNotesPanel;
                    }
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: Icon(
                        _openedNote != null
                            ? Icons.close_rounded
                            : (_showNotesPanel ? Icons.expand_more_rounded : Icons.notes_rounded),
                        key: ValueKey(_openedNote != null ? 'wf_icon_close' : (_showNotesPanel ? 'wf_icon_hide' : 'wf_icon_show')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: Text(
                        _openedNote != null ? AppLocalizations.of(context)!.closeNote : (_showNotesPanel ? AppLocalizations.of(context)!.hideNotes : AppLocalizations.of(context)!.showNotes),
                        key: ValueKey(_openedNote != null ? 'wf_label_close' : (_showNotesPanel ? 'wf_label_hide' : 'wf_label_show')),
                      ),
                    ),
                  ],
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopActionRow(BuildContext context, AsyncValue<TaskCalendar?> projectAsync) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Voice feedback button on the left
          const VoiceFeedbackButton(),
          // Spacer to push workflow actions to the right
          const Spacer(),
          projectAsync.when(
            data: (project) => project != null ? _buildWorkflowActions(context, project) : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Sync monitoring status
          const Padding(
            padding: EdgeInsets.only(left: 12.0),
            child: MonitoringStatusWidget(compact: true),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowActions(BuildContext context, TaskCalendar project) {
    final status = (project.flowitStatus ?? 'ONGOING').toUpperCase();
    final buttons = <Widget>[];

    if (status == 'DRAFT') {
      buttons.add(FilledButton.icon(
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(AppLocalizations.of(context)!.startWorkflow),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => RequirementMappingDialog(projectPath: widget.workflowPath),
          );
          if (confirmed == true) {
            final statusService = ref.read(statusServiceProvider);
             await statusService.assignStatusToCalendar(widget.workflowPath, 'ONGOING');
             // After starting, propagate requirement attendees to tasks
             // TODO: inject workflow service via provider if needed
             // Force refresh of project status for UI buttons
             ref.invalidate(calendarListProvider);
          }
        },
      ));
    } else if (status == 'ONGOING') {
      buttons.add(FilledButton.tonalIcon(
        icon: const Icon(Icons.pause_rounded),
        label: Text(AppLocalizations.of(context)!.stopWorkflow),
        onPressed: () async {
          final statusService = ref.read(statusServiceProvider);
          await statusService.assignStatusToCalendar(widget.workflowPath, 'STOPPED');
          // Refresh UI to reflect STOPPED state
          ref.invalidate(calendarListProvider);
        },
      ));
    } else if (status == 'STOPPED') {
      buttons.add(FilledButton.icon(
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(AppLocalizations.of(context)!.resumeWorkflow),
        onPressed: () async {
          final statusService = ref.read(statusServiceProvider);
          await statusService.assignStatusToCalendar(widget.workflowPath, 'ONGOING');
          ref.invalidate(calendarListProvider);
        },
      ));
    } else if (status == 'COMPLETED') {
      buttons.add(FilledButton.tonalIcon(
        icon: const Icon(Icons.archive_rounded),
        label: Text(AppLocalizations.of(context)!.archiveWorkflow),
        onPressed: () async {
          final statusService = ref.read(statusServiceProvider);
          await statusService.archiveCalendar(widget.workflowPath);
          // Refresh UI to reflect ARCHIVE state
          ref.invalidate(calendarListProvider);
        },
      ));
    }

    buttons.add(const SizedBox(width: 8));
    buttons.add(OutlinedButton.icon(
      icon: const Icon(Icons.content_copy_rounded),
      label: Text(AppLocalizations.of(context)!.duplicateWorkflow),
      onPressed: () async {
        final name = await showDialog<String>(
          context: context,
          builder: (ctx) {
            final controller = TextEditingController(text: '${project.displayName} (copy)');
            return AlertDialog(
              title: const Text('Duplicate workflow'),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'New workflow name'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
        if (name == null || name.isEmpty) return;

        final workflowService = ref.read(workflowServiceProvider);
        final result = await workflowService.duplicateWorkflow(
          sourceCalendarPath: widget.workflowPath,
          newDisplayName: name,
        );
        await result.when(
          success: (newPath) async {
            final encoded = Uri.encodeComponent(newPath);
            if (mounted) context.go('/workflow/$encoded');
          },
          failure: (f) async {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${AppLocalizations.of(context)!.failedToLoad}: ${f.message}')),
              );
            }
          },
        );
      },
    ));

    return Row(children: buttons);
  }

  Widget _buildCollapsedHeader(BuildContext context, AsyncValue<TaskCalendar?> projectAsync) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _isDetailColumnCollapsed = false),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.transparent,
          ),
          child: Column(
        children: [
          // Vertical text with arrow icon
          Column(
            children: [
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              RotatedBox(
                quarterTurns: 1,
                child: Text(
                  'Show Workflow Detail',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Notes button when collapsed
          if (!_showNotesPanel && _openedNote == null)
            IconButton(
              onPressed: () => setState(() => _showNotesPanel = true),
              icon: const Icon(Icons.notes_rounded),
              tooltip: AppLocalizations.of(context)!.showNotes,
            ),
          if (_showNotesPanel || _openedNote != null)
            IconButton(
              onPressed: () => setState(() {
                if (_openedNote != null) {
                  _openedNote = null;
                  _showNotesPanel = false;
                } else {
                  _showNotesPanel = false;
                }
              }),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close notes',
            ),
          // Expand button at bottom
          IconButton(
            onPressed: () => setState(() => _isDetailColumnCollapsed = false),
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Expand workflow details',
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context, AsyncValue<TaskCalendar?> projectAsync, AsyncValue<List<Task>> tasksAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          projectAsync.when(
            data: (project) => project != null
                ? ProjectInfosWidget(
                    project: project, 
                    tasksAsync: tasksAsync, 
                    onProjectUpdated: (_) {},
                    onCollapse: () => setState(() => _isDetailColumnCollapsed = true),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewNote() async {
    final repo = ref.read(journalRepositoryProvider);
    final j = Journal.createNew(
      summary: 'Note',
      description: '',
      projectPath: widget.workflowPath,
    );
    await repo.save(j);
    setState(() {
      _openedNote = j;
      _showNotesPanel = false;
    });
  }

  Widget _buildViewTabs(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: StyledTabBar(
        selectedIndex: _selectedTabIndex,
        onTabSelected: (index) => setState(() => _selectedTabIndex = index),
        items: [
          StyledTabItem(label: AppLocalizations.of(context)!.stepsTab, icon: Icons.stairs_outlined),
          StyledTabItem(label: AppLocalizations.of(context)!.bottleneckTab, icon: Icons.timeline),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, AsyncValue<List<Task>> tasksAsync) {
    switch (_selectedTabIndex) {
      case 0:
        return ProjectTaskStepView(
          projectPath: widget.workflowPath,
          tasksAsync: tasksAsync,
          onTasksRefresh: () {},
          workflowVariant: true,
        );
      case 1:
        return tasksAsync.when(
          data: (tasks) => ProjectBottleneckView(
            projectPath: widget.workflowPath,
            tasks: tasks,
            onTasksRefresh: () {},
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error loading tasks: $error')),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}


