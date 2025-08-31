// Main application sidebar component
// Displays navigation sections and projects using modular widgets

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation_switcher.dart';
import 'toolbar_widget.dart';
import 'user_account_badge.dart';

import '../adaptive_app_layout.dart';

class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.currentDestination,
    this.fullWidth = false,
  });

  final AppDestination? currentDestination;
  final bool fullWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if we're on mobile (same breakpoint as AdaptiveAppLayout)
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;

    final double containerWidth = isDesktop ? 280 : (fullWidth ? double.infinity : 280);

    return Container(
      width: containerWidth,
      decoration: BoxDecoration(
        borderRadius: isDesktop ? null : BorderRadius.zero, // Remove rounded corners on mobile
        border: isDesktop ? Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ) : null, // Remove right border on mobile since drawer is full-screen
      ),
      child: Column(
        children: [
          // Add top padding on mobile for status bar
          if (!isDesktop) const SizedBox(height: 8),
          // Top: user account badge
          const UserAccountBadge(),
          
          // Center navigation section vertically between badge and toolbar
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NavigationSwitcher(
                  currentDestination: currentDestination,
                  isDesktop: isDesktop,
                ),
                const Divider(height: 24, color: Colors.transparent),
              ],
            ),
          ),
          
          // Bottom toolbar with Create, Archive, and Settings
          const ToolbarWidget(),
          
          // Add bottom padding on mobile for home indicator
          if (!isDesktop) 
            SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 0),
        ],
      ),
    );
  }




} 
