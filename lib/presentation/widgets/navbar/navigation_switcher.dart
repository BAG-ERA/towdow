// Navigation switcher widget for sidebar
// Switches between different navigation types based on current route:
// - MainNavigation: for general screens
// - DetailNavigation: for project/workflow detail screens
// - SettingsNavigation: removed

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'main_navigation.dart';
import 'detail_navigation.dart';
// settings_navigation removed

class NavigationSwitcher extends ConsumerStatefulWidget {
  const NavigationSwitcher({
    super.key,
    required this.currentDestination,
    required this.isDesktop,
    this.isIconOnly = false,
  });

  final dynamic currentDestination;
  final bool isDesktop;
  final bool isIconOnly;

  @override
  ConsumerState<NavigationSwitcher> createState() => _NavigationSwitcherState();
}

class _NavigationSwitcherState extends ConsumerState<NavigationSwitcher> {
  NavigationType _currentNavigationType = NavigationType.main;
  bool _isTransitioningToMain = false;
  bool? _isWorkflowDetail; // Track whether we're showing workflows (true) or projects (false)
  bool _isUserAction = false; // Track if navigation change was triggered by user action
  String _lastRoute = ''; // Track the last route to detect changes

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.path;
    
    // Determine navigation type based on route (settings removed)
    NavigationType newNavigationType;
    if (location.startsWith('/project/') || location.startsWith('/workflow/')) {
      newNavigationType = NavigationType.detail;
    } else {
      newNavigationType = NavigationType.main;
    }
    
    // Update navigation type if it changed
    if (newNavigationType != _currentNavigationType) {
      setState(() {
        _currentNavigationType = newNavigationType;
        _isTransitioningToMain = newNavigationType == NavigationType.main;
      });
    }
  }

  void _goBackToMain() {
    setState(() {
      _currentNavigationType = NavigationType.main;
      _isTransitioningToMain = true;
      _isUserAction = false; // Reset user action flag
    });
  }

  // Method to handle automatic navigation updates (when navbar updates by itself)
  void _updateDetailContextFromRoute() {
    if (_currentNavigationType == NavigationType.detail && !_isUserAction) {
      // Only update context if we're in detail mode and it wasn't triggered by user action
      final location = GoRouterState.of(context).uri.path;
      final newIsWorkflowDetail = location.startsWith('/workflow/') || location == '/workflows';
      
      if (_isWorkflowDetail != newIsWorkflowDetail) {
        setState(() {
          _isWorkflowDetail = newIsWorkflowDetail;
        });
      }
    }
  }

  void _goToDetail({bool? isWorkflow}) {
    setState(() {
      _currentNavigationType = NavigationType.detail;
      _isTransitioningToMain = false;
      _isUserAction = isWorkflow != null; // Mark as user action if context is provided
      
      // Use the passed parameter if provided (user action), otherwise fall back to route-based detection
      if (isWorkflow != null) {
        _isWorkflowDetail = isWorkflow;
      } else {
        // Automatic navigation: Determine if we're showing workflows based on current route
        final location = GoRouterState.of(context).uri.path;
        _isWorkflowDetail = location == '/workflows';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.path;
    
    // Check if route has changed and update context if needed
    if (currentLocation != _lastRoute) {
      _lastRoute = currentLocation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateDetailContextFromRoute();
      });
    }
    
    // Check available width for responsive behavior using MediaQuery
    final availableWidth = MediaQuery.of(context).size.width;
    final shouldSwitchToMain = availableWidth < 140.0 && _currentNavigationType == NavigationType.detail;
    
    // Automatically switch to main navigation if space is constrained
    if (shouldSwitchToMain && !_isTransitioningToMain) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _goBackToMain();
      });
    }
    
    // Switch navigation content based on current navigation type
    Widget navigationContent;
    switch (_currentNavigationType) {
      case NavigationType.detail:
        navigationContent = DetailNavigation(
          isDesktop: widget.isDesktop,
          onBackPressed: _goBackToMain,
          isIconOnly: widget.isIconOnly,
          isWorkflowDetail: _isWorkflowDetail,
        );
        break;
      case NavigationType.main:
        navigationContent = MainNavigation(
          currentDestination: widget.currentDestination,
          isDesktop: widget.isDesktop,
          onDetailPressed: _goToDetail,
          isIconOnly: widget.isIconOnly,
        );
        break;
    }

    // Wrap navigation content with animation
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        // Determine slide direction based on transition type
        Offset slideDirection;
        if (_isTransitioningToMain) {
          // Coming back to main - slide from left
          slideDirection = const Offset(-1.0, 0.0);
        } else {
          // Going to detail/settings - slide from right
          slideDirection = const Offset(1.0, 0.0);
        }

        return SlideTransition(
          position: Tween<Offset>(
            begin: slideDirection,
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: navigationContent,
    );
  }
}

enum NavigationType {
  main,
  detail,
}
