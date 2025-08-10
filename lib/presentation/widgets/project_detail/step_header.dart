// StepHeader widget
// Reusable header for sections in the Step view: title and actions (expand/collapse, inactive toggle)

import 'package:flutter/material.dart';

class StepHeader extends StatelessWidget {
  final String title;
  final int? count;
  final VoidCallback onExpandAll;
  final VoidCallback onCollapseAll;

  const StepHeader({
    super.key,
    required this.title,
    required this.onExpandAll,
    required this.onCollapseAll,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          count != null ? '$title (${count!})' : title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(width: 16),
        TextButton(
          onPressed: onExpandAll,
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Expand All', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onCollapseAll,
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Collapse All', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}


