// Project detail screen for managing individual projects
// Shows tasks within a project, supports task management and project info
// Projects are represented by TaskCalendar objects (CalDAV calendars)

import 'package:flutter/material.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/utils/styled_tab_bar.dart';
import '../../widgets/kanban_board.dart';
import '../../widgets/agenda_calendar.dart';
import '../../widgets/utils/tasklist_toolbar.dart';
import '../../widgets/utils/buttons/archive_project_button.dart';
import '../../widgets/utils/buttons/exit_share_button.dart';
import '../../../data/models/task_calendar.dart';
import '../../../data/models/task.dart';
import '../../../data/models/journal.dart';
import '../../../data/models/step.dart';
import '../../../data/providers/providers.dart';
import '../../../core/logger.dart';
import '../../../core/result.dart';
// commands now handled in ViewModel
import '../../viewmodels/project_detail_viewmodel.dart';

import '../../../core/theme/chart_theme.dart';
import '../../widgets/adaptive_app_layout.dart';
import '../../widgets/project_detail/project_task_list_view.dart';
import '../../widgets/project_detail/project_kanban_view.dart';
import '../../widgets/project_detail/project_infos_widget.dart';
import '../../widgets/project_detail/project_warnings_banner.dart';
import '../../widgets/project_detail/project_notes_quick_panel.dart';
import '../../widgets/project_detail/project_note_view.dart';
import '../../widgets/utils/voice_feedback_button.dart';
import '../../widgets/common/monitoring_status_widget.dart';
import '../../widgets/utils/task_completion_animation.dart';

// ViewModel provider for a specific project
final projectDetailViewModelProvider = StateNotifierProvider.family<ProjectDetailViewModel, ProjectDetailState, String>((ref, projectPath) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  final stepRepository = ref.watch(stepRepositoryProvider);
  final taskRepository = ref.watch(taskRepositoryProvider);
  final syncService = ref.watch(syncServiceProvider);

  final vm = ProjectDetailViewModel(
    ref,
    projectPath,
    calendarRepository,
    userRepository,
    stepRepository,
    taskRepository,
    syncService,
  );
  // Fire and forget init
  vm.initialize();
  return vm;
});

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectPath;

  const ProjectDetailScreen({
    super.key,
    required this.projectPath,
  });

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  int _selectedTabIndex = 0;
  bool _showNotesPanel = false;
  Journal? _openedNote;
  bool _isDetailColumnCollapsed = false; // New state variable for desktop layout
  String? _pendingTaskUid;

  @override
  void dispose() {
    // Note: Mobile providers are automatically cleaned up when the widget tree is disposed
    // No need to manually clear them here as it can cause disposal errors
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AppLogger.info('ProjectDetailScreen: Building screen for project path: ${widget.projectPath}');
    final vmState = ref.watch(projectDetailViewModelProvider(widget.projectPath));
    final projectAsync = vmState.project;
    final tasksAsync = ref.watch(projectTasksProvider(widget.projectPath));

    // Check if we're on desktop (same breakpoint as AdaptiveAppLayout)
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;

    // Update mobile providers when project data is available
    projectAsync.whenData((project) {
      if (project != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Update mobile title provider if on mobile
          if (!isDesktop) {
            ref.read(mobileTitleProvider.notifier).state = project.displayName;
          }
          
          // Auto-acknowledge shared project when viewing project detail
          ref.read(projectDetailViewModelProvider(widget.projectPath).notifier)
              .acknowledgeSharedProjectIfNeeded(project);

          // If a task query is present, scroll/focus once tasks are loaded
          final taskUid = GoRouterState.of(context).uri.queryParameters['task'];
          if (taskUid != null && taskUid.isNotEmpty) {
            _pendingTaskUid = taskUid;
          }
        });
      }
    });

    if (isDesktop) {
      // Desktop 3-column layout: Nav bar | Title/Header | View content
      return _buildDesktopLayout(context, projectAsync, tasksAsync);
    } else {
      // Mobile single-column layout (existing)
      return _buildMobileLayout(context, projectAsync, tasksAsync);
    }
  }

  Widget _buildDesktopLayout(BuildContext context, AsyncValue<TaskCalendar?> projectAsync, AsyncValue<List<Task>> tasksAsync) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: Row(
        children: [
          // Column 1: Title/Header area (collapsible width) with full project info
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _isDetailColumnCollapsed ? 60 : 320,
            child: Column(
              children: [
                // Project title and full project info (scrollable to avoid overflow)
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _isDetailColumnCollapsed 
                          ? _buildCollapsedHeader(context, ref.watch(projectDetailViewModelProvider(widget.projectPath)))
                          : SingleChildScrollView(
                              child: _buildDesktopHeader(context, ref.watch(projectDetailViewModelProvider(widget.projectPath)), tasksAsync),
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
                                    key: const ValueKey('note_open_desktop'),
                                    journal: _openedNote!,
                                    onSaved: () {
                                      setState(() {
                                        _openedNote = null;
                                        _showNotesPanel = false;
                                      });
                                    },
                                  )
                                : const SizedBox.shrink(key: ValueKey('note_closed_desktop')),
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
                                    key: const ValueKey('panel_open_desktop'),
                                    projectPath: widget.projectPath,
                                    onOpenNote: (j) => setState(() { _openedNote = j; _showNotesPanel = false; }),
                                    onCreateNew: () => _createNewNote(),
                                  )
                                : const SizedBox.shrink(key: ValueKey('panel_closed_desktop')),
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
                    child: Center(
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
          
          // Column 2: View content (expanded) with tabs and content
          Expanded(
            child: Column(
              children: [
                // Archive button row at the top
                _buildArchiveButtonRow(context, projectAsync),
                
                // View tabs moved to right column
                _buildViewTabs(context),
                
                // Content based on selected tab
                Expanded(
                  child: _buildTabContent(context, ref, tasksAsync),
                ),
                
                // Bottom toolbar with search and create task button
                TaskListToolbar(
                  projectPath: widget.projectPath,
                  projectName: projectAsync.asData?.value?.displayName,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewNote() async {
    // Minimal inline creation; could be replaced with a dedicated dialog later
    final repo = ref.read(journalRepositoryProvider);
    final j = Journal.createNew(
      summary: AppLocalizations.of(context)!.note,
      description: '',
      projectPath: widget.projectPath,
    );
    await repo.save(j);
    setState(() {
      _openedNote = j;
      _showNotesPanel = false;
    });
  }

  Widget _buildDesktopHeader(BuildContext context, ProjectDetailState vmState, AsyncValue<List<Task>> tasksAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project details layout
           vmState.project.when(
            data: (project) => project != null 
                ? ProjectInfosWidget(
                    project: project,
                    tasksAsync: tasksAsync,
                    onProjectUpdated: _updateProject,
                    onCollapse: () => setState(() => _isDetailColumnCollapsed = true),
                  )
                : const SizedBox.shrink(),
            loading: () => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  Text(AppLocalizations.of(context)!.loadingProject),
                ],
              ),
            ),
            error: (error, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${AppLocalizations.of(context)!.failedToLoadProject}: $error',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
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

  Widget _buildCollapsedHeader(BuildContext context, ProjectDetailState vmState) {
    return Container(
      height: double.infinity,
      child: MouseRegion(
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
                    Icons.keyboard_double_arrow_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      AppLocalizations.of(context)!.showProjectDetail,
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
                  tooltip: AppLocalizations.of(context)!.closeNote,
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, AsyncValue<TaskCalendar?> projectAsync, AsyncValue<List<Task>> tasksAsync) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: Stack(
        children: [
          Column(
            children: [
              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                  // Warnings banner on mobile (if any)
                  projectAsync.when(
                    data: (project) => project != null
                        ? ProjectWarningsBanner(project: project, tasksAsync: tasksAsync)
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  // Project Details - collapsible on mobile
                  projectAsync.when(
                    data: (project) => project != null
                        ? Column(
                            children: [
                              // Collapsible header with tasks count
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
                                        AppLocalizations.of(context)!.tasksCount(completed, total),
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                      );
                                    },
                                    loading: () => Text(
                                      AppLocalizations.of(context)!.tasksLoading,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    error: (_, __) => Text(
                                      AppLocalizations.of(context)!.tasksEmpty,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: ProjectInfosWidget(
                                        project: project,
                                        tasksAsync: tasksAsync,
                                        onProjectUpdated: (updatedProject) => _updateProject(updatedProject),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Separator under the header
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Divider(
                                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                  height: 1,
                                ),
                              ),
                            ],
                          )
                        : Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_rounded,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${AppLocalizations.of(context)!.projectNotFound}: ${widget.projectPath}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onErrorContainer,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    loading: () => Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(width: 16),
                          Text(AppLocalizations.of(context)!.loadingProject),
                        ],
                      ),
                    ),
                    error: (error, _) => Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_rounded,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${AppLocalizations.of(context)!.failedToLoadProject}: $error',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // View Tabs - Updated labels for new views
                  _buildViewTabs(context),
                  
                  // Content based on selected tab
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7, // Give content a reasonable height
                        child: _buildTabContent(context, ref, tasksAsync),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Bottom toolbar with search and create task button (fixed at bottom)
              TaskListToolbar(
                projectPath: widget.projectPath,
                projectName: projectAsync.asData?.value?.displayName,
              ),
            ],
          ),

          // Notes overlays
          // Animated note overlay
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
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
                      key: const ValueKey('note_open'),
                      journal: _openedNote!,
                      onSaved: () {
                        setState(() {
                          _openedNote = null;
                          _showNotesPanel = false;
                        });
                      },
                    )
                  : const SizedBox.shrink(key: ValueKey('note_closed')),
            ),
          ),

          // Dim overlay behind quick panel (tap to dismiss)
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: (_showNotesPanel && _openedNote == null)
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _showNotesPanel = false;
                        });
                      },
                      child: Container(color: Colors.black.withOpacity(0.35)),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // Animated quick panel
          Positioned(
            left: 12,
            right: 12,
            bottom: 128, // a bit higher to leave room for shadow halo
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
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
                      key: const ValueKey('panel_open'),
                      projectPath: widget.projectPath,
                      onOpenNote: (j) => setState(() { _openedNote = j; _showNotesPanel = false; }),
                      onCreateNew: () => _createNewNote(),
                    )
                  : const SizedBox.shrink(key: ValueKey('panel_closed')),
            ),
          ),

          // Floating notes button just above search bar (render last so it's always on top)
          AnimatedPositioned(
            left: 16,
            right: 16,
            bottom: _openedNote != null ? 16 : 64, // nudge closer when closing note
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
                          key: ValueKey(_openedNote != null
                              ? 'icon_close'
                              : (_showNotesPanel ? 'icon_hide' : 'icon_show')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 360),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: Text(
                          _openedNote != null
                              ? AppLocalizations.of(context)!.closeNote
                              : (_showNotesPanel ? AppLocalizations.of(context)!.hideNotes : AppLocalizations.of(context)!.showNotes),
                          key: ValueKey(_openedNote != null
                              ? 'label_close'
                              : (_showNotesPanel ? 'label_hide' : 'label_show')),
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
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOut,
          ),
        ],
      ),
    );
  }



  Widget _buildArchiveButtonRow(BuildContext context, AsyncValue<TaskCalendar?> projectAsync) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Voice feedback button on the left
          const VoiceFeedbackButton(),
          // Spacer to push project actions to the right
          const Spacer(),
          projectAsync.when(
            data: (project) => project != null
                ? _buildProjectActionButton(context, project)
                : const SizedBox.shrink(),
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

  Widget _buildProjectActionButton(BuildContext context, TaskCalendar project) {
    // Determine if this project is shared with me by checking if we have a sharer email
    final sharedByAsync = ref.watch(projectSharedByProvider(project.uid));
    return sharedByAsync.when(
      data: (sharedBy) {
        final isSharedWithMe = sharedBy.isNotEmpty;
        if (isSharedWithMe) {
          // Show exit share button for shared projects
          return ExitShareButton.compact(
            projectPath: project.path,
            projectDisplayName: project.displayName,
          );
        } else {
          // Show archive button for owned projects
          return ArchiveProjectButton.compact(
            projectPath: project.path,
            projectDisplayName: project.displayName,
            onProjectArchived: () {
              // Navigate back to home after archiving
              Navigator.of(context).pop();
            },
          );
        }
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildViewTabs(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: StyledTabBar(
        selectedIndex: _selectedTabIndex,
        onTabSelected: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        items: [
          StyledTabItem(
            label: AppLocalizations.of(context)!.listTab,
            icon: Icons.checklist_rounded,
          ),
          StyledTabItem(
            label: AppLocalizations.of(context)!.timingTab,
            icon: Icons.schedule_rounded,
          ),
          StyledTabItem(
            label: AppLocalizations.of(context)!.attendeeTab,
            icon: Icons.groups,
          ),
          StyledTabItem(
            label: AppLocalizations.of(context)!.kanbanTab,
            icon: Icons.view_kanban_rounded,
          ),
          StyledTabItem(
            label: AppLocalizations.of(context)!.agendaTab,
            icon: Icons.calendar_month_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, WidgetRef ref, AsyncValue<List<Task>> tasksAsync) {
    return switch (_selectedTabIndex) {
      0 => ProjectTaskListView(
        projectPath: widget.projectPath,
        tasksAsync: tasksAsync,
        initialFocusedTaskUid: _pendingTaskUid,
      ),
      1 => _buildTimingView(context, ref, tasksAsync),
      2 => _buildAttendeeView(context, ref, tasksAsync),
      3 => _buildKanbanView(context, ref, tasksAsync),
      4 => _buildAgendaView(context, ref, tasksAsync),
      _ => ProjectTaskListView(
        projectPath: widget.projectPath,
        tasksAsync: tasksAsync,
      ),
    };
  }



  // Timing View - Kanban organized by time periods
  Widget _buildTimingView(BuildContext context, WidgetRef ref, AsyncValue<List<Task>> tasksAsync) {
    return tasksAsync.when(
      data: (tasks) => _buildTimingKanban(context, ref, tasks),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('${AppLocalizations.of(context)!.failedToLoad}: $error')),
    );
  }

  Widget _buildTimingKanban(BuildContext context, WidgetRef ref, List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));

    // Group tasks by time periods
    final overdueTasks = tasks.where((task) => 
        task.due != null && 
        DateTime(task.due!.year, task.due!.month, task.due!.day).isBefore(today) &&
        task.status != 'COMPLETED').toList();
    
    final todayTasks = tasks.where((task) => 
        task.due != null && 
        DateTime(task.due!.year, task.due!.month, task.due!.day).isAtSameMomentAs(today)).toList();
    
    final soonTasks = tasks.where((task) => 
        task.due != null && 
        DateTime(task.due!.year, task.due!.month, task.due!.day).isAfter(today) &&
        DateTime(task.due!.year, task.due!.month, task.due!.day).isBefore(tomorrow.add(const Duration(days: 2)))).toList();
    
    final nextWeekTasks = tasks.where((task) => 
        task.due != null && 
        task.due!.isAfter(tomorrow.add(const Duration(days: 2))) &&
        task.due!.isBefore(nextWeek)).toList();
    
    final laterTasks = tasks.where((task) => 
        task.due != null && 
        task.due!.isAfter(nextWeek)).toList();
    
    final anytimeTasks = tasks.where((task) => task.due == null).toList();

    // Sort all task lists by status (completed tasks last)
    _sortTasksByStatus(overdueTasks);
    _sortTasksByStatus(todayTasks);
    _sortTasksByStatus(soonTasks);
    _sortTasksByStatus(nextWeekTasks);
    _sortTasksByStatus(laterTasks);
    _sortTasksByStatus(anytimeTasks);

    final columns = [
      KanbanColumn(
        id: 'overdue',
        title: AppLocalizations.of(context)!.overdue,
        subtitle: AppLocalizations.of(context)!.tasksCountSimple(overdueTasks.length),
        tasks: overdueTasks,
                 color: context.chartTheme.colors.error,
        icon: Icons.warning_rounded,
      ),
      KanbanColumn(
        id: 'today',
        title: AppLocalizations.of(context)!.today,
        subtitle: _formatDate(today),
        tasks: todayTasks,
                 color: context.chartTheme.colors.success,
        icon: Icons.today_rounded,
      ),
      KanbanColumn(
        id: 'soon',
        title: AppLocalizations.of(context)!.soon,
        subtitle: AppLocalizations.of(context)!.nextTwoDays,
        tasks: soonTasks,
                 color: context.chartTheme.colors.warning,
        icon: Icons.schedule_rounded,
      ),
      KanbanColumn(
        id: 'next_week',
        title: AppLocalizations.of(context)!.nextWeek,
        subtitle: AppLocalizations.of(context)!.tasksCountSimple(nextWeekTasks.length),
        tasks: nextWeekTasks,
                 color: context.chartTheme.colors.primary,
        icon: Icons.date_range_rounded,
      ),
      KanbanColumn(
        id: 'later',
        title: AppLocalizations.of(context)!.later,
        subtitle: AppLocalizations.of(context)!.tasksCountSimple(laterTasks.length),
        tasks: laterTasks,
                 color: context.chartTheme.colors.tertiary,
        icon: Icons.event_rounded,
      ),
      KanbanColumn(
        id: 'anytime',
        title: AppLocalizations.of(context)!.anytime,
        subtitle: AppLocalizations.of(context)!.tasksCountSimple(anytimeTasks.length),
        tasks: anytimeTasks,
        color: Colors.grey,
        icon: Icons.inbox_rounded,
      ),
    ];

      return KanbanBoard(
      columns: columns,
      onTaskTap: (task) {
        // Navigate to task detail
      },
      onTaskToggle: (task) async {
        // Enforce: in ONGOING workflows only tasks in AVAILABLE steps can be marked done
        final project = ref.read(projectDetailViewModelProvider(widget.projectPath)).project.asData?.value;
        final stepStatusRes = await ref.read(projectDetailViewModelProvider(widget.projectPath).notifier).getStepStatusForTask(task);
        final step = stepStatusRes.when(success: (s) => s, failure: (_) => null);
        final isFlow = project?.flowitAsFlow == true;
        final status = (project?.flowitStatus ?? 'ONGOING').toUpperCase();
          final stepIsAvailable = step == StepStatus.available;

        if (isFlow && status == 'ONGOING' && !stepIsAvailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.waitingStepCannotComplete)),
          );
          return;
        }

        // Show completion animation if marking task as complete
        if (task.status != 'COMPLETED') {
          await TaskCompletionAnimation.show(context);
        }

        final taskViewModel = ref.read(taskViewModelProvider.notifier);
        await taskViewModel.toggleTaskCompletion(task);
        
        // Task updates handled by repository streams - no manual refresh needed
      },
      onTaskUpdated: (task) async {
        await ref.read(taskViewModelProvider.notifier).updateTask(task);
        
        // Task updates handled by repository streams - no manual refresh needed
      },
      onTaskDeleted: (task) async {
        // Handle task deletion
        final taskViewModel = ref.read(taskViewModelProvider.notifier);
        await taskViewModel.deleteTask(task.uid);
        
        // Task deletion handled by repository streams - no manual refresh needed
      },
    );
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  Color _getAttendeeColor(String attendee) {
    // Simple hash to get consistent colors for attendees
    final hash = attendee.hashCode;
    final colors = [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.teal, Colors.pink];
    return colors[hash.abs() % colors.length];
  }

  Future<void> _addTaskForAttendee(BuildContext context, WidgetRef ref, String attendee) async {
    final textController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.addTaskFor(_formatAttendeeEmail(attendee))),
        content: TextField(
          controller: textController,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.enterTaskSummary,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text.trim()),
            child: Text(AppLocalizations.of(context)!.addTask),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      final taskViewModel = ref.read(taskViewModelProvider.notifier);
      await taskViewModel.createTask(
        summary: result,
        projectPath: widget.projectPath,
      );
      
      // Task creation handled by repository streams - no manual invalidation needed
    }
  }



  // Attendee View - Kanban organized by attendees
  Widget _buildAttendeeView(BuildContext context, WidgetRef ref, AsyncValue<List<Task>> tasksAsync) {
    final projectAsync = ref.watch(projectDetailViewModelProvider(widget.projectPath)).project;
    
    return projectAsync.when(
      data: (project) {
        if (project == null) {
          return Center(child: Text(AppLocalizations.of(context)!.projectNotFound));
        }

        return tasksAsync.when(
          data: (tasks) => _buildAttendeeKanban(context, ref, project, tasks),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('${AppLocalizations.of(context)!.failedToLoad}: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('${AppLocalizations.of(context)!.failedToLoad}: $error')),
    );
  }

  Widget _buildAttendeeKanban(BuildContext context, WidgetRef ref, TaskCalendar project, List<Task> tasks) {
    // Collect all unique ACTUAL attendees from project and tasks
    // Note: We're NOT including organizers here - only people who are attendees
    final Set<String> allAttendees = {};
    
    // Add project attendees (convert Attendee objects to emails)
    for (final attendee in project.attendees) {
      allAttendees.add(attendee.email);
    }
    
    // Add task attendees (but NOT organizers - only actual attendees)
    for (final task in tasks) {
      // Convert Attendee objects to email strings
      for (final attendee in task.attendees) {
        allAttendees.add(attendee.email);
      }
    }

    final attendeesList = allAttendees.toList()..sort();
    
    // Tasks without attendees - sorted by status (done tasks last)
    final unassignedTasks = tasks.where((task) => task.attendees.isEmpty).toList();
    _sortTasksByStatus(unassignedTasks);
    
    final columns = <KanbanColumn>[];
    
    // Add "No Attendees" column first
    columns.add(
      KanbanColumn(
        id: '__no_attendees__',
        title: AppLocalizations.of(context)!.noAttendees,
        subtitle: AppLocalizations.of(context)!.tasksCountSimple(unassignedTasks.length),
        tasks: unassignedTasks,
        color: Colors.grey,
        icon: Icons.person_off_rounded,
        onAddTask: () => _addUnassignedTask(context, ref),
      ),
    );

    // Add columns for each attendee
    for (final attendee in attendeesList) {
      final attendeeTasks = _getTasksForAttendee(tasks, attendee);
      _sortTasksByStatus(attendeeTasks);
      final completedTasks = attendeeTasks.where((task) => task.status == 'COMPLETED').length;
      final progressPercentage = attendeeTasks.isNotEmpty 
          ? (completedTasks * 100 / attendeeTasks.length).round() 
          : 0;

      columns.add(
        KanbanColumn(
          id: attendee,
          title: _formatAttendeeEmail(attendee),
          subtitle: AppLocalizations.of(context)!.progressComplete(progressPercentage),
          tasks: attendeeTasks,
          color: _getAttendeeColor(attendee),
          icon: Icons.person_rounded,
          onAddTask: () => _addTaskForAttendee(context, ref, attendee),
        ),
      );
    }

      return KanbanBoard(
      columns: columns,
      onTaskToggle: (task) async {
        // Show completion animation if marking task as complete
        if (task.status != 'COMPLETED') {
          await TaskCompletionAnimation.show(context);
        }

        final taskViewModel = ref.read(taskViewModelProvider.notifier);
        await taskViewModel.toggleTaskCompletion(task);
        
        // Task updates handled by repository streams - no manual refresh needed
      },
      onTaskUpdated: (task) async {
        await ref.read(taskViewModelProvider.notifier).updateTask(task);
        
        // Task updates handled by repository streams - no manual refresh needed
      },
        onTaskMoved: (task, columnId) async {
          final res = await ref.read(projectDetailViewModelProvider(widget.projectPath).notifier)
              .handleAttendeeTaskMove(task, columnId);
          res.when(success: (_) {
            // Task moves handled by repository streams - no manual refresh needed
          }, failure: (_) {});
        },
    );
  }

  List<Task> _getTasksForAttendee(List<Task> tasks, String attendee) {
    // Only return tasks where the person is an actual attendee (not just organizer)
    return tasks.where((task) => 
      task.attendees.any((a) => a.email == attendee)
    ).toList();
  }

  String _formatAttendeeEmail(String email) {
    // Show just the name part if it's an email, otherwise show as-is
    if (email.contains('@')) {
      final namePart = email.split('@').first;
      // Capitalize and replace separators with spaces
      return namePart
          .replaceAll(RegExp(r'[.\-_]'), ' ')
          .split(' ')
          .map((word) => word.isNotEmpty 
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : word)
          .join(' ');
    }
    return email;
  }

  Future<void> _addUnassignedTask(BuildContext context, WidgetRef ref) async {
    final textController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.addUnassignedTask),
        content: TextField(
          controller: textController,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.enterTaskSummary,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text.trim()),
            child: Text(AppLocalizations.of(context)!.addTask),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      final taskViewModel = ref.read(taskViewModelProvider.notifier);
      await taskViewModel.createTask(
        summary: result,
        projectPath: widget.projectPath,
      );
      
      // Task creation handled by repository streams - no manual invalidation needed
    }
  }

  // moved to ViewModel

  // Kanban View - Organized by categories
  Widget _buildKanbanView(BuildContext context, WidgetRef ref, AsyncValue<List<Task>> tasksAsync) {
    return ProjectKanbanView(
      projectPath: widget.projectPath,
      tasksAsync: tasksAsync,
      onTasksRefresh: () {
        // Task updates are handled automatically by repository streams
      },
    );
  }

  /// Sort tasks by status with completed tasks appearing last
  void _sortTasksByStatus(List<Task> tasks) {
    tasks.sort((a, b) {
      // First, sort by completion status (incomplete tasks first)
      if (a.status == 'COMPLETED' && b.status != 'COMPLETED') {
        return 1; // a (completed) comes after b (incomplete)
      }
      if (a.status != 'COMPLETED' && b.status == 'COMPLETED') {
        return -1; // a (incomplete) comes before b (completed)
      }
      
      // If both have the same completion status, sort by priority/due date
      // Tasks with due dates come before tasks without due dates
      if (a.due != null && b.due == null) {
        return -1; // a (has due date) comes before b (no due date)
      }
      if (a.due == null && b.due != null) {
        return 1; // a (no due date) comes after b (has due date)
      }
      
      // If both have due dates, sort by due date (earliest first)
      if (a.due != null && b.due != null) {
        return a.due!.compareTo(b.due!);
      }
      
      // If neither has due dates, sort alphabetically by summary
      return a.summary.toLowerCase().compareTo(b.summary.toLowerCase());
    });
  }

  // Agenda View - Calendar with tasks positioned by due date
  Widget _buildAgendaView(BuildContext context, WidgetRef ref, AsyncValue<List<Task>> tasksAsync) {
    return tasksAsync.when(
      data: (tasks) => AgendaCalendar(
        tasks: tasks,
        onTaskTap: (task) {
          // Navigate to task detail
        },
        onTaskToggle: (task) async {
          // Show completion animation if marking task as complete
          if (task.status != 'COMPLETED') {
            await TaskCompletionAnimation.show(context);
          }

          final taskViewModel = ref.read(taskViewModelProvider.notifier);
          await taskViewModel.toggleTaskCompletion(task);
          
          // Task updates handled by repository streams - no manual refresh needed
        },
        onTaskUpdated: (task) async {
          await ref.read(taskViewModelProvider.notifier).updateTask(task);
          
          // Task updates handled by repository streams - no manual refresh needed
        },
        onTaskDeleted: (task) async {
          // Handle task deletion
          final taskViewModel = ref.read(taskViewModelProvider.notifier);
          await taskViewModel.deleteTask(task.uid);
          
          // Task deletion handled by repository streams - no manual refresh needed
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('${AppLocalizations.of(context)!.failedToLoad}: $error')),
    );
  }

  // Task updates are handled automatically by repository streams

  

  Future<void> _updateProject(TaskCalendar updatedProject) async {
    final res = await ref.read(projectDetailViewModelProvider(widget.projectPath).notifier)
        .updateProject(updatedProject);
    res.when(success: (_) {
      // No invalidation needed for metadata-only updates.
    }, failure: (f) {
      AppLogger.error('ProjectDetail: Failed to update project: ${f.message}', f.exception, f.stackTrace);
    });
  }

  /// Sync project metadata changes to server via repository
  // Sync moved to ViewModel

  /// Auto-acknowledge shared project when user views project detail
  // Acknowledgment moved to ViewModel
} 
