import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';
import 'task_form.dart';

class TaskDetailWidget extends StatefulWidget {
  final String taskId;
  final bool isDialog;
  final VoidCallback? onClose;

  const TaskDetailWidget({
    super.key,
    required this.taskId,
    this.isDialog = false,
    this.onClose,
  });

  @override
  State<TaskDetailWidget> createState() => _TaskDetailWidgetState();
}

class _TaskDetailWidgetState extends State<TaskDetailWidget> {
  late TaskModel? _task;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  void _loadTask() {
    final taskRepository = context.read<TaskRepository>();
    _task = taskRepository.getTask(widget.taskId);
    if (_task == null && mounted) {
      widget.onClose?.call();
      if (!widget.isDialog) {
        Navigator.pop(context);
      }
    }
  }

  void _showEditForm() {
    if (_task == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TaskForm(initialTask: _task),
    ).then((edited) {
      if (edited == true) {
        setState(() {
          _loadTask();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_task == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final theme = Theme.of(context);
    final task = _task!;
    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary
        Text(
          task.summary,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),

        // Status chip
        Wrap(
          spacing: 8,
          children: [
            Chip(
              label: Text(task.status.value),
              backgroundColor: _getStatusColor(task.status, theme.colorScheme),
            ),
            if (task.type != FlowItType.task)
              Chip(
                label: Text(task.type.value),
                backgroundColor: theme.colorScheme.primaryContainer,
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Due date
        if (task.dueDate != null) ...[
          _buildInfoRow(
            context,
            'Due Date',
            _formatDateTime(task.dueDate!),
            Icons.calendar_today,
          ),
          const SizedBox(height: 16),
        ],

        // Description
        if (task.description.isNotEmpty) ...[
          const Text(
            'Description',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(task.description),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Metadata
        _buildInfoRow(
          context,
          'Created',
          _formatDateTime(task.created),
          Icons.create,
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          context,
          'Last Modified',
          _formatDateTime(task.lastModified),
          Icons.update,
        ),

        // Advanced properties
        if (task.processUid != null ||
            task.templateUid != null ||
            task.reversalTaskUid != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Advanced Properties',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.processUid != null)
                  ListTile(
                    leading: const Icon(Icons.account_tree),
                    title: const Text('Process'),
                    subtitle: Text(task.processUid!),
                  ),
                if (task.templateUid != null)
                  ListTile(
                    leading: const Icon(Icons.copy_all),
                    title: const Text('Template'),
                    subtitle: Text(task.templateUid!),
                  ),
                if (task.reversalTaskUid != null)
                  ListTile(
                    leading: const Icon(Icons.undo),
                    title: const Text('Reversal Task'),
                    subtitle: Text(task.reversalTaskUid!),
                  ),
              ],
            ),
          ),
        ],
      ],
    );

    final actions = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (task.status != TaskStatus.completed)
          FilledButton.icon(
            onPressed: () async {
              final taskRepository = context.read<TaskRepository>();
              await taskRepository.completeTask(task.uid);
              setState(() {
                _loadTask();
              });
            },
            icon: const Icon(Icons.check),
            label: const Text('Complete'),
          ),
        if (task.status != TaskStatus.cancelled)
          OutlinedButton.icon(
            onPressed: () async {
              final taskRepository = context.read<TaskRepository>();
              await taskRepository.cancelTask(task.uid);
              setState(() {
                _loadTask();
              });
            },
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel'),
          ),
      ],
    );

    if (widget.isDialog) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600,
            maxHeight: 800,
          ),
          child: Column(
            children: [
              AppBar(
                title: const Text('Task Details'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _showEditForm,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
              Expanded(child: content),
              Padding(
                padding: const EdgeInsets.all(16),
                child: actions,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditForm,
          ),
        ],
      ),
      body: content,
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: actions,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Text(value),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(TaskStatus status, ColorScheme colorScheme) {
    switch (status) {
      case TaskStatus.completed:
        return colorScheme.primaryContainer;
      case TaskStatus.cancelled:
        return colorScheme.errorContainer;
      case TaskStatus.needsAction:
        return colorScheme.surfaceVariant;
    }
  }
} 