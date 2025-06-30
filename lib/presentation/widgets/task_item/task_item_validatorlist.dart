// Task item validator list component
// Manages all validators and routes them to their specific validator type components

import 'package:flutter/material.dart';
import '../../../data/models/task.dart';
import '../validator_widget.dart';

class TaskItemValidatorList extends StatelessWidget {
  final Task task;
  final Function(Task)? onTaskUpdated;

  const TaskItemValidatorList({
    super.key,
    required this.task,
    this.onTaskUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return ValidatorWidget(
      task: task,
      onTaskUpdated: onTaskUpdated,
    );
  }
} 