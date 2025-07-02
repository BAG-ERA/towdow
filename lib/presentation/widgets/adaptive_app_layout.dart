// Adaptive app layout that switches between desktop and mobile layouts
// Desktop: permanent sidebar + main content area
// Mobile: drawer navigation + full-screen content

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'navbar/app_sidebar.dart';

enum AppDestination {
  today(
    label: 'Today',
    icon: Icons.today_rounded,
    route: '/today',
  ),
  soon(
    label: 'Soon',
    icon: Icons.schedule_rounded,
    route: '/soon',
  ),
  anytime(
    label: 'Anytime',
    icon: Icons.inbox_rounded,
    route: '/anytime',
  );

  const AppDestination({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

class AdaptiveAppLayout extends ConsumerWidget {
  const AdaptiveAppLayout({
    super.key,
    required this.currentDestination,
    required this.child,
  });

  final AppDestination? currentDestination;
  final Widget child;

  static const double _desktopBreakpoint = 800.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= _desktopBreakpoint;

    if (isDesktop) {
      return _buildDesktopLayout(context);
    } else {
      return _buildMobileLayout(context);
    }
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Fixed sidebar
          AppSidebar(currentDestination: currentDestination),
          // Main content area
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    // Determine title for mobile based on route
    String title = 'FlowIt';
    final location = GoRouterState.of(context).uri.path;
    
    if (location.startsWith('/archived')) {
      title = 'Archived Projects';
    } else if (location.startsWith('/settings')) {
      title = 'Settings';
    } else if (location.startsWith('/project/')) {
      title = 'Project Details';
    } else if (currentDestination != null) {
      title = currentDestination!.label;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: false,
        leading: Builder(
          builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
                  ),
                ),
      drawer: _buildMobileDrawer(context),
      body: child,
    );
  }

  Widget _buildMobileDrawer(BuildContext context) {
    return Drawer(
      child: AppSidebar(currentDestination: currentDestination),
          );
  }


} 
