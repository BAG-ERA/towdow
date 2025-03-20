import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/models/task_model.dart';
import '../widgets/task_list.dart';
import '../utils/platform_utils.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  @override
  Widget build(BuildContext context) {
    final taskRepository = context.read<TaskRepository>();
    final projects = taskRepository.getTasksByType(FlowItType.taskGroup);

    return TaskList(
      tasks: projects,
      onTaskTap: (task) {
        showProjectDetails(context, task.uid);
      },
      // Projects can't be completed directly
      onTaskComplete: null,
    );
  }
} 