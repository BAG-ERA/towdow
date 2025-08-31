// Settings navigation widget for sidebar
// Shows settings-related navigation options when user is on settings screens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:towdow_app/l10n/app_localizations.dart';

class SettingsNavigation extends ConsumerWidget {
  const SettingsNavigation({
    super.key,
    required this.isDesktop,
    required this.onBackPressed,
  });

  final bool isDesktop;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Settings header with return button (entire header is clickable)
        InkWell(
          onTap: onBackPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Return icon (no longer a button)
                Icon(
                  Icons.arrow_back_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                // Title
                Expanded(
                  child: Text(
                    l10n.settings,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Settings navigation items
        _SettingsNavItem(
          label: l10n.appearance,
          icon: Icons.palette_rounded,
          onTap: () {}, // Stay on settings screen
          isDesktop: isDesktop,
        ),
        
        _SettingsNavItem(
          label: l10n.account,
          icon: Icons.account_circle_rounded,
          onTap: () {}, // Stay on settings screen
          isDesktop: isDesktop,
        ),
        
        _SettingsNavItem(
          label: l10n.integration,
          icon: Icons.integration_instructions_rounded,
          onTap: () {}, // Stay on settings screen
          isDesktop: isDesktop,
        ),
        
        _SettingsNavItem(
          label: l10n.about,
          icon: Icons.info_rounded,
          onTap: () {}, // Stay on settings screen
          isDesktop: isDesktop,
        ),
      ],
    );
  }
}

class _SettingsNavItem extends StatelessWidget {
  const _SettingsNavItem({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isDesktop,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final borderRadius = isDesktop ? BorderRadius.circular(12) : BorderRadius.zero;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: ListTile(
          leading: Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          title: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
    );
  }
}
