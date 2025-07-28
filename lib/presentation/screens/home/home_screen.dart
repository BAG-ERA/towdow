// Home screen showing tasks grouped by Today, Soon, and Unregistered
// Refactored to use MVVM architecture with HomeViewModel and Commands

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/task_item/task_item.dart';
import '../../widgets/utils/styled_tab_bar.dart';
import '../../widgets/external_calendar/external_events_list.dart';
import '../../widgets/adaptive_app_layout.dart';
import '../../../data/providers/providers.dart';
import '../../../data/models/task.dart';
import '../../../data/models/calendar_event.dart';
import '../../../data/services/sync_service.dart';
import '../../providers/home_providers.dart';

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
    
    // Check if we're on mobile (same breakpoint as AdaptiveAppLayout)
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;
    
    return Scaffold(
      appBar: isDesktop ? AppBar(
        title: const Text('My Tasks'),
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          // Sync status indicator
          Consumer(
            builder: (context, ref, child) {
              final syncStatus = ref.watch(currentSyncStatusProvider);
              switch (syncStatus) {
                case SyncStatus.syncing:
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                case SyncStatus.error:
                  return IconButton(
                    icon: const Icon(Icons.sync_problem_rounded, color: Colors.red),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sync error occurred')),
                      );
                    },
                  );
                case SyncStatus.offline:
                  return IconButton(
                    icon: const Icon(Icons.cloud_off_rounded, color: Colors.orange),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Offline - no account configured')),
                      );
                    },
                  );
                case SyncStatus.idle:
                  return IconButton(
                    icon: const Icon(Icons.sync_rounded),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Go to Settings > Debug > Sync Now')),
                      );
                    },
                  );
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: StyledTabBar(
            items: [
              StyledTabItem(
                label: 'Today (${ref.watch(todayTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})', 
                icon: Icons.today_rounded
              ),
              StyledTabItem(
                label: 'Soon (${ref.watch(soonTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})', 
                icon: Icons.schedule_rounded
              ),
              StyledTabItem(
                label: 'Next Week (${ref.watch(nextWeekTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})', 
                icon: Icons.date_range_rounded
              ),
              StyledTabItem(
                label: 'Later (${ref.watch(laterTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})', 
                icon: Icons.event_rounded
              ),
              StyledTabItem(
                label: 'Anytime (${ref.watch(anytimeTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})', 
                icon: Icons.inbox_rounded
              ),
            ],
            selectedIndex: selectedTabIndex,
            onTabSelected: (index) {
              ref.read(selectedTabIndexProvider.notifier).state = index;
            },
          ),
        ),
      ) : null,
      body: Column(
        children: [
          // Mobile tabs - only show when no AppBar (mobile mode)
          if (!isDesktop)
            StyledTabBar(
              items: [
                StyledTabItem(
                  label: 'Today (${ref.watch(todayTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})', 
                  icon: Icons.today_rounded
                ),
                StyledTabItem(
                  label: 'Soon (${ref.watch(soonTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})', 
                  icon: Icons.schedule_rounded
                ),
                StyledTabItem(
                  label: 'Next Week (${ref.watch(nextWeekTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})', 
                  icon: Icons.date_range_rounded
                ),
                StyledTabItem(
                  label: 'Later (${ref.watch(laterTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})', 
                  icon: Icons.event_rounded
                ),
                StyledTabItem(
                  label: 'Anytime (${ref.watch(anytimeTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})', 
                  icon: Icons.inbox_rounded
                ),
              ],
              selectedIndex: selectedTabIndex,
              onTabSelected: (index) {
                ref.read(selectedTabIndexProvider.notifier).state = index;
              },
            ),
          
          Expanded(
            child: IndexedStack(
              index: selectedTabIndex,
              children: const [
                _TaskListTab(type: TaskListType.today),
                _TaskListTab(type: TaskListType.soon),
                _TaskListTab(type: TaskListType.nextWeek),
                _TaskListTab(type: TaskListType.later),
                _TaskListTab(type: TaskListType.anytime),
              ],
            ),
          ),
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
            Text('Error loading tasks: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(todayTasksProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (tasks) {
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
                const Text('No tasks yet. Tap + to create your first task!'),
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
                      if (tasks.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(height: 16),
                                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                                const SizedBox(height: 8),
                                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                                const SizedBox(height: 32),
                                const Text('No tasks yet. Tap + to create your first task!'),
                              ],
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 12.0, // Horizontal spacing between tasks
                            runSpacing: 12.0, // Vertical spacing between rows
                            alignment: WrapAlignment.center,
                            runAlignment: WrapAlignment.center,
                            children: tasks.map((task) {
                              return ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                  minWidth: 300,
                                ),
                                child: TaskItem(
                                  task: task,
                                  onToggleComplete: () async {
                                    // Toggle task completion
                                    await ref.read(taskViewModelProvider.notifier).toggleTaskCompletion(task);
                                    
                                    // Refresh the task lists
                                    ref.invalidate(taskListProvider);
                                    ref.invalidate(todayTasksProvider);
                                    ref.invalidate(soonTasksProvider);
                                    ref.invalidate(nextWeekTasksProvider);
                                    ref.invalidate(laterTasksProvider);
                                    ref.invalidate(anytimeTasksProvider);
                                  },
                                  onTaskUpdated: (updatedTask) async {
                                    // Handle task updates - save to repository and sync
                                    await ref.read(taskViewModelProvider.notifier).updateTask(updatedTask);
                                    
                                    // Note: Task lists will auto-update via repository streams
                                  },
                                  onTaskDeleted: () async {
                                    // Handle task deletion
                                    await ref.read(taskViewModelProvider.notifier).deleteTask(task.uid);
                                    
                                    // Note: Task lists will auto-update via repository streams
                                  },
                                ),
                              );
                            }).toList(),
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

 
