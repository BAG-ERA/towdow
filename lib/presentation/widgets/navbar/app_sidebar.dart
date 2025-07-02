// Main application sidebar component
// Displays navigation sections and projects using modular widgets

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main_navigation.dart';
import 'projects_section.dart';
import 'toolbar_widget.dart';

import '../adaptive_app_layout.dart';

class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.currentDestination,
  });

  final AppDestination? currentDestination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if we're on mobile (same breakpoint as AdaptiveAppLayout)
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;

    return Container(
      width: 280,
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
          // Main navigation
          MainNavigation(
            currentDestination: currentDestination,
            isDesktop: isDesktop,
          ),
          
          const Divider(height: 24, color: Colors.transparent),
          
          // Projects section
          Expanded(
            child: ProjectsSection(isDesktop: isDesktop),
          ),
          
          // Bottom toolbar with Create, Archive, and Settings
          const ToolbarWidget(),
        ],
      ),
    );
  }




} 
