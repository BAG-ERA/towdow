import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/task_repository.dart';
import '../widgets/task_list.dart';
import '../utils/platform_utils.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  @override
  Widget build(BuildContext context) {
    final taskRepository = context.read<TaskRepository>();
    final tasks = taskRepository.getTasksDueToday();

    return TaskList(
      tasks: tasks,
      onTaskTap: (task) {
        showTaskDetails(context, task.uid);
        // The setState will be called when the dialog/screen is closed
        // because we're using Navigator.pop/push which rebuilds the widget tree
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