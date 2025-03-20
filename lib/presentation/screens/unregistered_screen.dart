import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/task_repository.dart';
import '../widgets/task_list.dart';
import '../utils/platform_utils.dart';

class UnregisteredScreen extends StatefulWidget {
  const UnregisteredScreen({super.key});

  @override
  State<UnregisteredScreen> createState() => _UnregisteredScreenState();
}

class _UnregisteredScreenState extends State<UnregisteredScreen> {
  @override
  Widget build(BuildContext context) {
    final taskRepository = context.read<TaskRepository>();
    final tasks = taskRepository.getUnregisteredTasks();

    return TaskList(
      tasks: tasks,
      onTaskTap: (task) {
        showTaskDetails(context, task.uid);
      },
      onTaskComplete: (task) async {
        await taskRepository.completeTask(task.uid);
        if (context.mounted) {
          setState(() {});
        }
      },
    );
  }
} 