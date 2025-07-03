// Main navigation component for FlowIt
// Displays primary navigation destinations with proper highlighting

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../adaptive_app_layout.dart';

class MainNavigation extends ConsumerWidget {
  const MainNavigation({
    super.key,
    required this.currentDestination,
    required this.isDesktop,
  });

  final AppDestination? currentDestination;
  final bool isDesktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: AppDestination.values.map((destination) {
        // Only show selected state on desktop, not on mobile
        final isSelected = isDesktop && destination == currentDestination;
        final borderRadius = isDesktop ? BorderRadius.circular(12) : BorderRadius.zero;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Material(
            color: isSelected 
                ? Theme.of(context).colorScheme.secondaryContainer
                : Colors.transparent,
            borderRadius: borderRadius,
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
                // Close drawer on mobile using provided controller
                if (!isDesktop) {
                  final closeDrawer = ref.read(drawerControllerProvider);
                  closeDrawer?.call();
                }
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: borderRadius,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
} 
