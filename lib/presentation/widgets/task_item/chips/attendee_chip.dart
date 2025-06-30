// Attendee chip component for task items
// Displays individual attendee with status-based color coding

import 'package:flutter/material.dart';
import '../../../../data/models/attendee.dart';

class AttendeeChip extends StatelessWidget {
  final Attendee attendee;

  const AttendeeChip({
    super.key,
    required this.attendee,
  });

  @override
  Widget build(BuildContext context) {
    // Color based on status
    Color containerColor;
    Color textColor;
    
    switch (attendee.status) {
      case AttendeeStatus.accepted:
        containerColor = Colors.green.withValues(alpha: 0.15);
        textColor = Colors.green.shade700;
        break;
      case AttendeeStatus.declined:
        containerColor = Colors.red.withValues(alpha: 0.15);
        textColor = Colors.red.shade700;
        break;
      case AttendeeStatus.tentative:
        containerColor = Colors.orange.withValues(alpha: 0.15);
        textColor = Colors.orange.shade700;
        break;
      case AttendeeStatus.delegated:
        containerColor = Colors.purple.withValues(alpha: 0.15);
        textColor = Colors.purple.shade700;
        break;
      default:
        containerColor = Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.7);
        textColor = Theme.of(context).colorScheme.onSecondaryContainer;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        attendee.effectiveDisplayName,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: attendee.hasAccepted ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
} 