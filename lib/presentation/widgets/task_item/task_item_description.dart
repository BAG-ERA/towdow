// Task item description component
// Displays description, attendees, and categories sections when task is expanded

import 'package:flutter/material.dart';
import '../../../data/models/task.dart';
import 'chips/attendee_chip.dart';
import 'chips/category_chip.dart';
import '../utils/enhanced_text_field.dart';

class TaskItemDescription extends StatefulWidget {
  final Task task;
  final Function(Task)? onTaskUpdated;

  const TaskItemDescription({
    super.key,
    required this.task,
    this.onTaskUpdated,
  });

  @override
  State<TaskItemDescription> createState() => _TaskItemDescriptionState();
}

class _TaskItemDescriptionState extends State<TaskItemDescription> {
  bool _isEditing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.task.description);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description
        _buildCompactDescriptionSection(context),
        
        // Attendees
        if (widget.task.attendees.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildCompactAttendeesSection(context),
        ],
        
        // Categories
        if (widget.task.categories.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildCompactCategoriesSection(context),
        ],
      ],
    );
  }

  Widget _buildCompactDescriptionSection(BuildContext context) {
    final hasDescription = widget.task.description.isNotEmpty;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(
          color: _isEditing 
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EnhancedTextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: null,
            readOnly: !_isEditing,
            hintText: hasDescription ? null : 'No description provided • Click to add',
            style: TextStyle(
              fontSize: 13,
              color: hasDescription 
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              fontStyle: hasDescription ? FontStyle.normal : FontStyle.italic,
              height: 1.3,
            ),
            onTap: widget.onTaskUpdated != null ? _startEditing : null,
            onSubmitted: (_) => _saveDescription(),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _cancelEdit,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveDescription,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _controller.text = widget.task.description;
    });
  }

  void _saveDescription() {
    if (widget.onTaskUpdated != null) {
      final updatedTask = widget.task.copyWith(
        description: _controller.text.trim(),
        lastModified: DateTime.now(),
      );
      widget.onTaskUpdated!(updatedTask);
    }
    
    setState(() {
      _isEditing = false;
    });
  }

  Widget _buildCompactAttendeesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              widget.task.attendees.length == 1 ? Icons.person : Icons.group,
              size: 14,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 4),
            Text(
              widget.task.attendees.length == 1 ? 'Attendee' : 'Attendees',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 3,
          children: widget.task.attendees.map((attendee) {
            return AttendeeChip(attendee: attendee);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCompactCategoriesSection(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 3,
      children: widget.task.categories.map((category) {
        return CategoryChip(category: category);
      }).toList(),
    );
  }
} 