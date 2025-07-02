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
          
          const Divider(height: 1),
          
          // Projects section
          const Expanded(
            child: ProjectsSection(),
          ),
          
          const Divider(height: 1),
          
          // Account info section removed
          
          // Bottom toolbar with Create, Archive, and Settings
          const ToolbarWidget(),
        ],
      ),
    );
  }




} 
