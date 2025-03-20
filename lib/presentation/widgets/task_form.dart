import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';
import 'markdown_editor.dart';

class TaskForm extends StatefulWidget {
  final TaskModel? initialTask;
  final String? processUid;

  const TaskForm({
    super.key,
    this.initialTask,
    this.processUid,
  });

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  late TextEditingController _summaryController;
  String _description = '';
  DateTime? _dueDate;
  FlowItType _type = FlowItType.task;

  @override
  void initState() {
    super.initState();
    _summaryController = TextEditingController(text: widget.initialTask?.summary);
    _description = widget.initialTask?.description ?? '';
    _dueDate = widget.initialTask?.dueDate;
    _type = widget.initialTask?.type ?? FlowItType.task;
  }

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) {
      setState(() {
        _dueDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
        );
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    String getTitle() {
      if (widget.initialTask?.type == FlowItType.taskGroup) {
        return widget.initialTask == null ? 'New Project' : 'Edit Project';
      }
      return widget.initialTask == null ? 'New Task' : 'Edit Task';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                getTitle(),
                style: theme.textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _summaryController,
            decoration: const InputDecoration(
              labelText: 'Summary',
              border: OutlineInputBorder(),
              helperText: 'Required',
              helperStyle: TextStyle(color: Colors.red),
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
            onChanged: (value) {
              // Rebuild to update submit button state
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          MarkdownEditor(
            initialValue: _description,
            onChanged: (value) {
              setState(() {
                _description = value;
              });
            },
            labelText: 'Description',
            hintText: 'Add more details (supports markdown)',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(context),
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_dueDate == null
                      ? 'Set Due Date (optional)'
                      : 'Due: ${_formatDate(_dueDate!)}'),
                ),
              ),
              if (_dueDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _dueDate = null;
                    });
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _summaryController.text.trim().isNotEmpty
                ? () {
                    final taskRepository = context.read<TaskRepository>();
                    if (widget.initialTask != null) {
                      // Update existing task
                      final updatedTask = widget.initialTask!.copyWith(
                        summary: _summaryController.text.trim(),
                        description: _description.trim(),
                        dueDate: _dueDate,
                        type: _type,
                      );
                      taskRepository.updateTask(updatedTask);
                    } else {
                      // Create new task
                      taskRepository.createTask(
                        summary: _summaryController.text.trim(),
                        description: _description.trim(),
                        dueDate: _dueDate,
                        type: _type,
                        processUid: widget.processUid,
                      );
                    }
                    Navigator.pop(context, true);
                  }
                : null,
            child: Text(widget.initialTask == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }
} 