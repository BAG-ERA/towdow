// Home screen showing tasks grouped by Today, Soon, and Unregistered
// Refactored to use MVVM architecture with HomeViewModel and Commands

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/task_item/task_item.dart';
import '../../widgets/utils/styled_tab_bar.dart';
import '../../../data/providers/providers.dart';
import '../../../data/models/task.dart';
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
          // Mobile header with hamburger menu
          if (!isDesktop)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                      tooltip: 'Open navigation',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'My Tasks',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Mobile sync status
                  Consumer(
                    builder: (context, ref, child) {
                      final syncStatus = ref.watch(currentSyncStatusProvider);
                      switch (syncStatus) {
                        case SyncStatus.syncing:
                          return const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
              ),
            ),
          
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
    String title;
    String subtitle;
    IconData icon;

    switch (type) {
      case TaskListType.today:
        tasksAsync = ref.watch(todayTasksProvider);
        title = 'Today\'s Tasks';
        subtitle = 'Overdue and tasks due before midnight';
        icon = Icons.today_rounded;
        break;
      case TaskListType.soon:
        tasksAsync = ref.watch(soonTasksProvider);
        title = 'Soon Tasks';
        subtitle = 'Tasks due from tomorrow until next Monday';
        icon = Icons.schedule_rounded;
        break;
      case TaskListType.nextWeek:
        tasksAsync = ref.watch(nextWeekTasksProvider);
        title = 'Next Week Tasks';
        subtitle = 'Tasks due from next Monday to the following Monday';
        icon = Icons.date_range_rounded;
        break;
      case TaskListType.later:
        tasksAsync = ref.watch(laterTasksProvider);
        title = 'Later Tasks';
        subtitle = 'Tasks due after next week';
        icon = Icons.event_rounded;
        break;
      case TaskListType.anytime:
        tasksAsync = ref.watch(anytimeTasksProvider);
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
            ref.invalidate(taskListProvider);
          },
          child: Column(
            children: [
              Expanded(
                child: tasks.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.task_alt_rounded, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No tasks yet',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap + to create your first task',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 12.0, // Horizontal spacing between tasks
                          runSpacing: 12.0, // Vertical spacing between rows
                          alignment: WrapAlignment.start,
                          runAlignment: WrapAlignment.start,
                          children: tasks.map((task) {
                            return ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 420,
                                minWidth: 300,
                              ),
                              child: TaskItem(
                                task: task,
                                onTap: () {
                                  // Navigate to task detail
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Navigate to task ${task.uid}')),
                                  );
                                },
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
                                  
                                  // Refresh the task lists
                                  ref.invalidate(taskListProvider);
                                  ref.invalidate(todayTasksProvider);
                                  ref.invalidate(soonTasksProvider);
                                  ref.invalidate(nextWeekTasksProvider);
                                  ref.invalidate(laterTasksProvider);
                                  ref.invalidate(anytimeTasksProvider);
                                },
                                onTaskDeleted: () async {
                                  // Handle task deletion
                                  await ref.read(taskViewModelProvider.notifier).deleteTask(task.uid);
                                  
                                  // Refresh the task lists
                                  ref.invalidate(taskListProvider);
                                  ref.invalidate(todayTasksProvider);
                                  ref.invalidate(soonTasksProvider);
                                  ref.invalidate(nextWeekTasksProvider);
                                  ref.invalidate(laterTasksProvider);
                                  ref.invalidate(anytimeTasksProvider);
                                  
                                  // Show confirmation
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Task "${task.summary}" deleted'),
                                        action: SnackBarAction(
                                          label: 'Undo',
                                          onPressed: () {
                                            // TODO: Implement undo functionality
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          }).toList(),
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

 
