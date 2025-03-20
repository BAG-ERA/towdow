import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';
import '../widgets/task_list.dart';
import '../widgets/task_form.dart';
import '../widgets/adaptive_navigation.dart';
import '../utils/platform_utils.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late TaskModel? _project;
  List<TaskModel> _tasks = [];
  bool _showCompleted = false;
  bool _showNavigation = false;

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  void _loadProject() {
    final taskRepository = context.read<TaskRepository>();
    _project = taskRepository.getTask(widget.projectId);
    if (_project == null) {
      Navigator.pop(context);
      return;
    }

    // Load tasks associated with this project
    _tasks = taskRepository.getAllTasks()
        .where((task) => 
            task.processUid == widget.projectId && 
            task.type == FlowItType.task &&
            (_showCompleted || task.status != TaskStatus.completed))
        .toList()
      ..sort((a, b) {
        // Sort by status (incomplete first), then by due date
        if (a.status != b.status) {
          if (a.status == TaskStatus.completed) return 1;
          if (b.status == TaskStatus.completed) return -1;
        }
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });
    setState(() {});
  }

  void _addTask() {
    if (_project == null) return;

    final newTask = TaskModel(
      uid: const Uuid().v4(),
      summary: '',
      processUid: _project!.uid,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TaskForm(initialTask: newTask),
    ).then((created) {
      if (created == true) {
        setState(() {
          _loadProject();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_project == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final theme = Theme.of(context);
    final project = _project!;
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project.summary,
                style: theme.textTheme.headlineSmall,
              ),
              if (project.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  project.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Tasks',
                style: theme.textTheme.titleLarge,
              ),
              const Spacer(),
              // Toggle to show/hide completed tasks
              Row(
                children: [
                  Text(
                    'Show completed',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Switch(
                    value: _showCompleted,
                    onChanged: (value) {
                      setState(() {
                        _showCompleted = value;
                        _loadProject();
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final content = Scaffold(
      appBar: AppBar(
        leading: !isDesktop && !_showNavigation
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  setState(() {
                    _showNavigation = true;
                  });
                },
              )
            : null,
        title: Text(project.summary),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 8),
          Expanded(
            child: _tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.task_alt,
                          size: 48,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tasks yet',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _addTask,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Task'),
                        ),
                      ],
                    ),
                  )
                : TaskList(
                    tasks: _tasks,
                    onTaskTap: (task) {
                      showTaskDetails(context, task.uid);
                    },
                    onTaskComplete: (task) async {
                      final taskRepository = context.read<TaskRepository>();
                      await taskRepository.completeTask(task.uid);
                      if (mounted) {
                        setState(() {
                          _loadProject();
                        });
                      }
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );

    return AdaptiveNavigation(
      isDesktop: isDesktop,
      selectedItem: NavigationItem.projects,
      onNavigationItemSelected: (item) {
        if (item == NavigationItem.projects) {
          Navigator.pop(context);
        } else {
          // Pop back to main screen and select the new item
          Navigator.pop(context, item);
        }
      },
      child: isDesktop || !_showNavigation ? content : null,
    );
  }
} 