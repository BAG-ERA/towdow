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
          ? _buildToolbarContent(context, currentLocation, ref)
          : const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      error: (_, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _buildToolbarContent(BuildContext context, String currentLocation, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withAlpha(25),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: CreateProjectOrDomainButton.compact(
              isFullWidth: true,
            ),
          ),
        ],
      ),
    );
  }



  // No additional buttons for now



  // No-op helpers for future use
} 