import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/task_repository.dart';
import '../widgets/task_list.dart';
import '../utils/platform_utils.dart';

class SoonScreen extends StatefulWidget {
  const SoonScreen({super.key});

  @override
  State<SoonScreen> createState() => _SoonScreenState();
}

class _SoonScreenState extends State<SoonScreen> {
  @override
  Widget build(BuildContext context) {
    final taskRepository = context.read<TaskRepository>();
    final tasks = taskRepository.getTasksDueSoon();

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