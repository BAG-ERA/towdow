// Attendee chip component for task items
// Displays individual attendee with status-based color coding

import 'package:flutter/material.dart';
import '../../../../data/models/attendee.dart';
import '../../../../core/theme/chart_theme.dart';

class AttendeeChip extends StatelessWidget {
  final Attendee attendee;

  const AttendeeChip({
    super.key,
    required this.attendee,
  });

  @override
  Widget build(BuildContext context) {
    // Color based on status using FlowIt brand colors
    Color containerColor;
    Color textColor;
    
    switch (attendee.status) {
      case AttendeeStatus.accepted:
        containerColor = context.chartTheme.colors.success.withValues(alpha: 0.15); // Water Green
        textColor = context.chartTheme.colors.success;
        break;
      case AttendeeStatus.declined:
        containerColor = context.chartTheme.colors.error.withValues(alpha: 0.15); // Pink
        textColor = context.chartTheme.colors.error;
        break;
      case AttendeeStatus.tentative:
        containerColor = context.chartTheme.colors.warning.withValues(alpha: 0.15); // Yellow Dark
        textColor = context.chartTheme.colors.warning;
        break;
      case AttendeeStatus.delegated:
        containerColor = context.chartTheme.colors.tertiary.withValues(alpha: 0.15); // Violet
        textColor = context.chartTheme.colors.tertiary;
        break;
      default:
        containerColor = context.chartTheme.colors.secondary.withValues(alpha: 0.15); // Water Green Light
        textColor = context.chartTheme.colors.secondary;
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