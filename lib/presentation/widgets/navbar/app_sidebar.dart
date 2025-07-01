// Main application sidebar component
// Displays navigation sections, projects, and user account info using modular widgets

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'account_card.dart';
import 'main_navigation.dart';
import 'projects_section.dart';
import 'create_button.dart';

import '../../../data/providers/providers.dart';
import '../adaptive_app_layout.dart';

class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.currentDestination,
  });

  final AppDestination currentDestination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccount = ref.watch(hasActiveAccountProvider);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        //of(context).colorScheme.surface,//ContainerHighest.withValues(alpha: 1),
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Main navigation
          MainNavigation(currentDestination: currentDestination),
          
          // Archived projects link
          hasAccount.when(
            data: (hasActiveAccount) => hasActiveAccount 
                ? _buildArchivedProjectsLink(context)
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          
          const Divider(height: 1),
          
          // Projects section
          const Expanded(
            child: ProjectsSection(),
          ),
          
          // Create button
          hasAccount.when(
            data: (hasActiveAccount) => hasActiveAccount 
                ? const CreateButton()
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          
          const Divider(height: 1),
          
          // Account info and settings
          hasAccount.when(
            data: (hasActiveAccount) => hasActiveAccount 
                ? const AccountCard()
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedProjectsLink(BuildContext context) {
    final isArchiveSelected = GoRouterState.of(context).uri.path == '/archived';
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isArchiveSelected 
            ? Theme.of(context).colorScheme.secondaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(
            Icons.archive_rounded,
            color: isArchiveSelected
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 20,
          ),
          title: Text(
            'Archived Projects',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isArchiveSelected
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isArchiveSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          onTap: () {
            context.go('/archived');
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
  }


} 
