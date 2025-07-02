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

// Provider to track if this is the first time opening the app on mobile
final _firstMobileLoadProvider = StateProvider<bool>((ref) => true);

class AdaptiveAppLayout extends ConsumerStatefulWidget {
  const AdaptiveAppLayout({
    super.key,
    required this.currentDestination,
    required this.child,
  });

  final AppDestination? currentDestination;
  final Widget child;

  static const double _desktopBreakpoint = 800.0;

  @override
  ConsumerState<AdaptiveAppLayout> createState() => _AdaptiveAppLayoutState();
}

class _AdaptiveAppLayoutState extends ConsumerState<AdaptiveAppLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _hasOpenedDrawerOnStart = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final isDesktop = MediaQuery.of(context).size.width >= AdaptiveAppLayout._desktopBreakpoint;
    final isFirstMobileLoad = ref.read(_firstMobileLoadProvider);
    
    // Open drawer on start for mobile devices on first load
    if (!isDesktop && isFirstMobileLoad && !_hasOpenedDrawerOnStart) {
      _hasOpenedDrawerOnStart = true;
      
      // Use addPostFrameCallback to ensure the widget is built before opening drawer
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scaffoldKey.currentState != null) {
          _scaffoldKey.currentState!.openDrawer();
          // Mark that we've completed the first mobile load
          ref.read(_firstMobileLoadProvider.notifier).state = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= AdaptiveAppLayout._desktopBreakpoint;

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
          AppSidebar(currentDestination: widget.currentDestination),
          // Main content area
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    // Determine title for mobile based on route
    String title = 'FlowIt';
    bool isDetailScreen = false;
      final location = GoRouterState.of(context).uri.path;
    
      if (location.startsWith('/archived')) {
        title = 'Archived Projects';
      isDetailScreen = true;
    } else if (location.startsWith('/settings')) {
      title = 'Settings';
      isDetailScreen = true;
    } else if (location.startsWith('/project/')) {
      title = 'Project Details';
      isDetailScreen = true;
    } else if (widget.currentDestination != null) {
      title = widget.currentDestination!.label;
    }
    
    return Scaffold(
      key: _scaffoldKey,
      appBar: isDetailScreen ? AppBar(
        title: Text(title),
        centerTitle: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Back to navigation',
          ),
                  ),
      ) : null,
      drawer: _buildMobileDrawer(context),
      body: widget.child,
    );
  }

  Widget _buildMobileDrawer(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Drawer(
        shape: const RoundedRectangleBorder(), // Remove rounded corners
      child: AppSidebar(currentDestination: widget.currentDestination),
      ),
          );
  }
} 
