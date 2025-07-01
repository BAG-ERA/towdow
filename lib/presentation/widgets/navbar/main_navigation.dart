// Main navigation component for FlowIt
// Displays primary navigation destinations with proper highlighting

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../adaptive_app_layout.dart';

class MainNavigation extends StatelessWidget {
  const MainNavigation({
    super.key,
    required this.currentDestination,
  });

  final AppDestination? currentDestination;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: AppDestination.values.map((destination) {
        final isSelected = destination == currentDestination;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Material(
            color: isSelected 
                ? Theme.of(context).colorScheme.secondaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              leading: Icon(
                destination.icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(
                destination.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              onTap: () {
                context.go(destination.route);
                // Close drawer on mobile
                if (Scaffold.of(context).hasDrawer) {
                  Navigator.of(context).pop();
                }
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
} 
