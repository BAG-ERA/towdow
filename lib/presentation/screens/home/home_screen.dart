// Home screen showing tasks grouped by Today, Soon, and Unregistered
// Refactored to use MVVM architecture with HomeViewModel and Commands

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/providers.dart';
import '../../../data/models/task.dart';
import '../../../data/services/caldav_service.dart';
import '../../../data/services/sync_service.dart';
import '../../providers/home_providers.dart';
import '../../widgets/styled_tab_bar.dart';
import '../../widgets/task_item/task_item.dart';

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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        automaticallyImplyLeading: false,
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
                label: 'Later (${ref.watch(laterTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})', 
                icon: Icons.event_rounded
              ),
              StyledTabItem(
                label: 'Anytime (${ref.watch(anytimeTasksProvider).maybeWhen(data: (tasks) => tasks.length, orElse: () => 0)})', 
                icon: Icons.layers_rounded
              ),
            ],
            selectedIndex: selectedTabIndex,
            onTabSelected: (index) {
              ref.read(selectedTabIndexProvider.notifier).state = index;
            },
          ),
        ),
      ),
      body: IndexedStack(
        index: selectedTabIndex,
        children: const [
          _TaskListTab(type: TaskListType.today),
          _TaskListTab(type: TaskListType.soon),
          _TaskListTab(type: TaskListType.later),
          _TaskListTab(type: TaskListType.anytime),
        ],
      ),
      floatingActionButton: Consumer(
        builder: (context, ref, child) {
          final isCommandExecuting = ref.watch(isAnyCommandExecutingProvider);
          
          return FloatingActionButton(
            onPressed: isCommandExecuting ? null : () {
              _showCreateTaskDialog(context);
            },
            child: isCommandExecuting 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded),
          );
        },
      ),
    );
  }

  void _showCreateTaskDialog(BuildContext context) {
    final summaryController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? selectedDue;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Task'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: summaryController,
                  decoration: const InputDecoration(
                    labelText: 'Task summary *',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded),
                  title: Text(selectedDue == null 
                    ? 'No due date' 
                    : 'Due: ${selectedDue!.day}/${selectedDue!.month}/${selectedDue!.year}'
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDue ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDue = picked;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            Consumer(
              builder: (context, ref, child) {
                final isCommandExecuting = ref.watch(isAnyCommandExecutingProvider);
                
                return ElevatedButton(
                  onPressed: isCommandExecuting ? null : () async {
                    if (summaryController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a task summary')),
                      );
                      return;
                    }

                    try {
                      // Use TaskViewModel to create the task so it includes organizer by default
                      final taskViewModel = ref.read(taskViewModelProvider.notifier);
                      await taskViewModel.createTask(
                        summary: summaryController.text.trim(),
                        description: descriptionController.text.trim().isEmpty 
                          ? '' 
                          : descriptionController.text.trim(),
                        due: selectedDue,
                        categories: const [],
                      );

                      // Close dialog and show success
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Task created successfully!')),
                      );
                      
                      // Refresh task providers
                      ref.invalidate(taskListProvider);
                      ref.invalidate(todayTasksProvider);
                      ref.invalidate(soonTasksProvider);
                      ref.invalidate(laterTasksProvider);
                      ref.invalidate(anytimeTasksProvider);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  child: isCommandExecuting 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : null,
        duration: Duration(seconds: isSuccess ? 4 : 3),
      ),
    );
  }


}

enum TaskListType { today, soon, later, anytime }

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
        subtitle = 'Overdue and tasks due within 24 hours';
        icon = Icons.today_rounded;
        break;
      case TaskListType.soon:
        tasksAsync = ref.watch(soonTasksProvider);
        title = 'Soon Tasks';
        subtitle = 'Tasks due between 24h and 7 days';
        icon = Icons.schedule_rounded;
        break;
      case TaskListType.later:
        tasksAsync = ref.watch(laterTasksProvider);
        title = 'Later Tasks';
        subtitle = 'Tasks due in more than 7 days';
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
              // Test CalDAV Sync Button (development)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () => _testCalDAVSync(context, ref),
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Test CalDAV Sync'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              
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
                    : ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _TaskListTile(task: task);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _testCalDAVSync(BuildContext context, WidgetRef ref) async {
    try {
      // Get active CalDAV account
      final activeAccount = ref.read(activeAccountProvider);
      activeAccount.when(
        data: (account) async {
          if (account == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No active CalDAV account found')),
            );
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Creating test task and syncing with CalDAV server...')),
          );

          // Create a test task
          final testTask = Task(
            uid: 'test-task-${DateTime.now().millisecondsSinceEpoch}',
            summary: 'Test CalDAV Task',
            description: 'This is a test task created from FlowIt to verify CalDAV synchronization',
            status: 'NEEDS-ACTION',
            lastModified: DateTime.now(),
            created: DateTime.now(),
            dtstamp: DateTime.now(), // Required by iCalendar specification
            due: DateTime.now().add(const Duration(days: 7)),
            categories: ['test', 'caldav'],
          );

          // Save locally first
          final taskViewModel = ref.read(taskViewModelProvider.notifier);
          await taskViewModel.createTask(
            summary: testTask.summary,
            description: testTask.description,
            due: testTask.due,
          );

          // Sync with CalDAV server
          final caldavService = CalDAVService(account: account);
          final syncResult = await caldavService.createTask(testTask);
          
          syncResult.when(
            success: (taskUrl) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Task synced successfully!\nURL: $taskUrl'),
                  backgroundColor: Colors.green,
                ),
              );
              ref.invalidate(taskListProvider);
            },
            failure: (failure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('❌ CalDAV sync failed: ${failure.message}')),
              );
            },
          );
        },
        loading: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading account...')),
        ),
        error: (error, _) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting account: $error')),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during CalDAV sync test: $e')),
      );
    }
  }


}

class _TaskListTile extends ConsumerWidget {
  final Task task;

  const _TaskListTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
            return TaskItem(
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
    );
  }
} 
