// Bottom toolbar widget for navbar
// Contains Create, Archive, and Settings actions in a horizontal layout

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/providers/providers.dart';
import '../utils/buttons/create_project_or_domain_button.dart';


class ToolbarWidget extends ConsumerWidget {
  const ToolbarWidget({super.key, this.isIconOnly = false});

  final bool isIconOnly;

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
    
    // Scale toolbar height and padding with global text scale so the compact button grows
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    final baseHPad = 16.0;
    final baseVPad = 8.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: baseHPad * textScale, vertical: baseVPad * textScale),
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
            child: CreateProjectOrDomainButton(
              isFullWidth: true,
              size: CreateProjectOrDomainButtonSize.large,
              showDropdownAffordance: true,
            ),
          ),
        ],
      ),
    );
  }



  // No additional buttons for now



  // No-op helpers for future use
} 