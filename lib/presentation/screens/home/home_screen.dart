// Home screen showing tasks grouped by Today, Soon, Next Week, Later, and Anytime
// Simple implementation with same behavior on mobile and desktop

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import '../../widgets/task_item/task_item.dart';
import '../../widgets/utils/styled_tab_bar.dart';
import '../../widgets/external_calendar/external_events_list.dart';
import '../../../data/providers/providers.dart';
import '../../../data/models/task.dart';
import '../../../data/models/task_calendar.dart';
import '../../../data/models/calendar_event.dart';
import '../../providers/home_providers.dart';
import '../../../core/theme/chart_theme_usage.dart';
import '../../widgets/header_screen_widget.dart';
import '../../widgets/common/monitoring_status_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    
    // Initialize local storage when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeStorage();
    });
  }

  Future<void> _initializeStorage() async {
    final storageService = ref.read(localStorageServiceProvider);
    await storageService.initialize();
    
    // Data loading is handled automatically by Riverpod providers
  }

  @override
  Widget build(BuildContext context) {
    final selectedTabIndex = ref.watch(selectedTabIndexProvider);
    final isMobile = MediaQuery.of(context).size.width < 800.0;
    
    // Create tab bar items once to avoid duplication
    final tabItems = [
      StyledTabItem(
        label: '${AppLocalizations.of(context)!.today} (${ref.watch(todayTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})',
        icon: Icons.today_rounded,
      ),
      StyledTabItem(
        label: '${AppLocalizations.of(context)!.soon} (${ref.watch(soonTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})',
        icon: Icons.schedule_rounded,
      ),
      StyledTabItem(
        label: '${AppLocalizations.of(context)!.nextWeek} (${ref.watch(nextWeekTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})',
        icon: Icons.date_range_rounded,
      ),
      StyledTabItem(
        label: '${AppLocalizations.of(context)!.later} (${ref.watch(laterTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})',
        icon: Icons.event_rounded,
      ),
      StyledTabItem(
        label: '${AppLocalizations.of(context)!.anytime} (${ref.watch(anytimeTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})',
        icon: Icons.inbox_rounded,
      ),
    ];
    
    final tabBar = StyledTabBar(
      items: tabItems,
      selectedIndex: selectedTabIndex,
      onTabSelected: (index) {
        ref.read(selectedTabIndexProvider.notifier).state = index;
      },
    );
    
    return Scaffold(
      appBar: isMobile ? AppBar(
        title: Text(AppLocalizations.of(context)!.myTasks),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/nav'),
          tooltip: AppLocalizations.of(context)!.backToNavigation,
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: MonitoringStatusWidget(compact: true),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: tabBar,
        ),
      ) : HeaderScreenWidget(
        title: AppLocalizations.of(context)!.myTasks,
        showVoiceFeedback: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: tabBar,
        ),
      ),
      body: IndexedStack(
        index: selectedTabIndex,
        children: const [
          _TaskListTab(type: TaskListType.today),
          _TaskListTab(type: TaskListType.soon),
          _TaskListTab(type: TaskListType.nextWeek),
          _TaskListTab(type: TaskListType.later),
          _TaskListTab(type: TaskListType.anytime),
        ],
      ),
    );
  }
}

enum TaskListType { today, soon, nextWeek, later, anytime }

class _TaskListTab extends ConsumerWidget {
  final TaskListType type;

  const _TaskListTab({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<List<Task>> tasksAsync;
    AsyncValue<List<CalendarEvent>> eventsAsync;
    String title;
    String subtitle;
    IconData icon;

    switch (type) {
      case TaskListType.today:
        tasksAsync = ref.watch(todayTasksProvider);
        eventsAsync = ref.watch(todayExternalEventsProvider);
        title = 'Today\'s Tasks';
        subtitle = 'Overdue and tasks due before midnight';
        icon = Icons.today_rounded;
        break;
      case TaskListType.soon:
        tasksAsync = ref.watch(soonTasksProvider);
        eventsAsync = ref.watch(soonExternalEventsProvider);
        title = 'Soon Tasks';
        subtitle = 'Tasks due from tomorrow until next Monday';
        icon = Icons.schedule_rounded;
        break;
      case TaskListType.nextWeek:
        tasksAsync = ref.watch(nextWeekTasksProvider);
        eventsAsync = ref.watch(nextWeekExternalEventsProvider);
        title = 'Next Week Tasks';
        subtitle = 'Tasks due from next Monday to the following Monday';
        icon = Icons.date_range_rounded;
        break;
      case TaskListType.later:
        tasksAsync = ref.watch(laterTasksProvider);
        eventsAsync = ref.watch(laterExternalEventsProvider);
        title = 'Later Tasks';
        subtitle = 'Tasks due after next week';
        icon = Icons.event_rounded;
        break;
      case TaskListType.anytime:
        tasksAsync = ref.watch(anytimeTasksProvider);
        eventsAsync = ref.watch(anytimeExternalEventsProvider);
        title = 'Anytime Tasks';
        subtitle = 'Tasks without due dates';
        icon = Icons.inbox_rounded;
        break;
    }

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_rounded, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('${AppLocalizations.of(context)!.failedToLoad}: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(todayTasksProvider),
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
      data: (tasks) {
        // Calendars map for grouping headers and navigation (projects and workflows)
        final calendars = ref.watch(calendarListProvider).maybeWhen(
          data: (list) => list,
          orElse: () => <TaskCalendar>[],
        );
        final calendarByPath = {for (final c in calendars) c.path: c};

        // Group tasks by project/workflow path (nullable when task has no project)
        final Map<String?, List<Task>> tasksByProject = {};
        for (final t in tasks) {
          final key = t.projectPath; // stored as encoded path (may contain %40)
          (tasksByProject[key] ??= <Task>[]).add(t);
        }

        // Sort groups by project/workflow display name (unknowns last)
        final groupKeys = tasksByProject.keys.toList()
          ..sort((a, b) {
            final ca = a != null ? calendarByPath[a] : null;
            final cb = b != null ? calendarByPath[b] : null;
            final na = ca?.displayName ?? '\uFFFF';
            final nb = cb?.displayName ?? '\uFFFF';
            return na.toLowerCase().compareTo(nb.toLowerCase());
          });

        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                Text(AppLocalizations.of(context)!.noneFound(AppLocalizations.of(context)!.projects.toLowerCase())),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Trigger sync instead of manual invalidation since streams auto-update
            final syncService = ref.read(syncServiceProvider);
            await syncService.syncAllActiveCaldav();
          },
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // External calendar events section
                      eventsAsync.when(
                        loading: () => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Loading calendar events...',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        error: (error, _) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: Theme.of(context).colorScheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Failed to load calendar events',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        data: (events) => ExternalEventsList(
                          events: events,
                          startReduced: false,
                          limitReducedEvents: false,
                        ),
                      ),
                      
                      // Tasks section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final key in groupKeys) ...[
                              // Group header: project/workflow name, tappable to navigate
                              Builder(
                                builder: (context) {
                                  final calendar = key != null ? calendarByPath[key] : null;
                                  final title = calendar?.displayName ?? 'No Project';
                                  final isWorkflow = (calendar?.flowitAsFlow == true) ||
                                      ((calendar?.flowitType.toUpperCase() ?? '') == 'WORKFLOW');

                                  void onTapHeader() {
                                    if (calendar == null) return;
                                    final rawPath = Uri.decodeComponent(calendar.path);
                                    final routeSegment = Uri.encodeComponent(rawPath);
                                    final route = isWorkflow ? '/workflow/$routeSegment' : '/project/$routeSegment';
                                    context.go(route);
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: calendar != null ? onTapHeader : null,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Wrap(
                                                spacing: 8,
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                children: [
                                                  Text(
                                                    title,
                                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (calendar != null)
                                                    Text(
                                                      calendar.domainDisplayName,
                                                      style: context.domainNameStyle.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(alpha: 0.55),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  // Navigation icon to indicate clickable project title
                                                  if (calendar != null)
                                                    Icon(
                                                      Icons.open_in_new_rounded,
                                                      size: 16,
                                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 6),
                              // Grouped tasks
                              Wrap(
                                spacing: 12.0,
                                runSpacing: 12.0,
                                alignment: WrapAlignment.start,
                                runAlignment: WrapAlignment.start,
                                children: [
                                  for (final task in tasksByProject[key]!)
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 420,
                                        minWidth: 300,
                                      ),
                                      child: TaskItem(
                                        task: task,
                                        onToggleComplete: () async {
                                          await ref.read(taskViewModelProvider.notifier).toggleTaskCompletion(task);
                                        },
                                        onTaskUpdated: (updatedTask) async {
                                          await ref.read(taskViewModelProvider.notifier).updateTask(updatedTask);
                                        },
                                        onTaskDeleted: () async {
                                          await ref.read(taskViewModelProvider.notifier).deleteTask(task.uid);
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}