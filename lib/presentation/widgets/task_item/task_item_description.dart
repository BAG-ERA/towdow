// Task item description component
// Displays description, attendees, and categories sections when task is expanded

import 'package:flutter/material.dart';
import '../../../data/models/task.dart';
import 'chips/attendee_chip.dart';
import 'chips/category_chip.dart';

class TaskItemDescription extends StatelessWidget {
  final Task task;

  const TaskItemDescription({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description
        _buildCompactDescriptionSection(context),
        
        // Attendees
        if (task.attendees.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildCompactAttendeesSection(context),
        ],
        
        // Categories
        if (task.categories.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildCompactCategoriesSection(context),
        ],
      ],
    );
  }

  Widget _buildCompactDescriptionSection(BuildContext context) {
    final hasDescription = task.description.isNotEmpty;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      child: Text(
        hasDescription 
            ? task.description 
            : 'No description provided',
        style: TextStyle(
          fontSize: 13,
          color: hasDescription 
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          fontStyle: hasDescription ? FontStyle.normal : FontStyle.italic,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildCompactAttendeesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              task.attendees.length == 1 ? Icons.person : Icons.group,
              size: 14,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 4),
            Text(
              task.attendees.length == 1 ? 'Attendee' : 'Attendees',
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
          children: task.attendees.map((attendee) {
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
      children: task.categories.map((category) {
        return CategoryChip(category: category);
      }).toList(),
    );
  }
} 