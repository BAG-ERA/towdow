// Bottom toolbar widget for navbar
// Contains Create, Archive, and Settings actions in a horizontal layout

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/providers/providers.dart';
import '../utils/buttons/create_project_or_domain_button.dart';

class ToolbarWidget extends ConsumerWidget {
  const ToolbarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccount = ref.watch(hasActiveAccountProvider);
    final currentLocation = GoRouterState.of(context).uri.path;
    
    return hasAccount.when(
      data: (hasActiveAccount) => hasActiveAccount 
          ? _buildToolbarContent(context, currentLocation)
          : const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      error: (_, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _buildToolbarContent(BuildContext context, String currentLocation) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withAlpha(25),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Create button (left side)
          Expanded(
            child: CreateProjectOrDomainButton.compact(
              isFullWidth: true,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Archive button (right side)
          _buildIconButton(
            context: context,
            icon: Icons.archive_rounded,
            tooltip: 'Archived Projects',
            isSelected: currentLocation == '/archived',
            onPressed: () {
              context.go('/archived');
              _closeDrawerIfMobile(context);
            },
          ),
          
          const SizedBox(width: 8),
          
          // Settings button (right side)
          _buildIconButton(
            context: context,
            icon: Icons.settings_rounded,
            tooltip: 'Settings',
            isSelected: currentLocation == '/settings',
            onPressed: () {
              context.go('/settings');
              _closeDrawerIfMobile(context);
            },
          ),
        ],
      ),
    );
  }



  Widget _buildIconButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isSelected 
            ? colorScheme.secondaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: isSelected
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }



  void _closeDrawerIfMobile(BuildContext context) {
    if (Scaffold.of(context).hasDrawer) {
      Navigator.of(context).pop();
    }
  }
} 