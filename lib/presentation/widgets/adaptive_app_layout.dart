// Adaptive app layout that switches between desktop and mobile layouts
// Desktop: permanent sidebar + main content area
// Mobile: drawer navigation + full-screen content

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'navbar/app_sidebar.dart';

// Provider for dynamic mobile title (used by detail screens)
final mobileTitleProvider = StateProvider<String?>((ref) => null);

// Provider for drawer control - allows navigation components to close drawer
final drawerControllerProvider = StateProvider<VoidCallback?>((ref) => null);

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

class _AdaptiveAppLayoutState extends ConsumerState<AdaptiveAppLayout> 
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _hasOpenedDrawerOnStart = false;
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0), // Start slightly from the right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    super.dispose();
  }

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
          _slideAnimationController.reset();
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

    // Provide drawer closing function to navigation components
    if (!isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(drawerControllerProvider.notifier).state = () {
          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
            _scaffoldKey.currentState!.closeDrawer();
            // Trigger slide-in animation after drawer starts closing
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _slideAnimationController.reset();
                _slideAnimationController.forward();
              }
            });
          }
        };
      });
    }

    return PopScope(
      canPop: false, // Never allow back button to close the app
      onPopInvoked: (didPop) {
        // On mobile, toggle drawer state instead of closing app
        if (!isDesktop && _scaffoldKey.currentState != null) {
          final scaffoldState = _scaffoldKey.currentState!;
          if (scaffoldState.isDrawerOpen) {
            // Drawer is open, close it
            Navigator.of(context).pop();
            // Trigger slide-in animation
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _slideAnimationController.forward();
              }
            });
          } else {
            // Drawer is closed, open it - reset animation
            _slideAnimationController.reset();
            scaffoldState.openDrawer();
          }
        }
      },
      child: isDesktop ? _buildDesktopLayout(context) : _buildMobileLayout(context),
    );
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
      title = ref.watch(mobileTitleProvider) ?? 'Project Details';
      isDetailScreen = true;
    }    
    return Scaffold(
      key: _scaffoldKey,
      appBar: isDetailScreen ? AppBar(
        title: Text(title),
        centerTitle: false,
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Back to navigation',
          ),
                  ),
      ) : null,
      drawer: _buildMobileDrawer(context),
      body: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: widget.child,
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Drawer(
        shape: const RoundedRectangleBorder(), // Remove rounded corners
        child: SafeArea(
          child: AppSidebar(currentDestination: widget.currentDestination),
        ),
      ),
    );
  }
} 
