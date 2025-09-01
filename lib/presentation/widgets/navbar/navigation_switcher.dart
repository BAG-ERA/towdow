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
    });
  }

  void _goToDetail() {
    setState(() {
      _currentNavigationType = NavigationType.detail;
      _isTransitioningToMain = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Switch navigation content based on current navigation type
    Widget navigationContent;
    switch (_currentNavigationType) {
      case NavigationType.detail:
        navigationContent = DetailNavigation(
          isDesktop: widget.isDesktop,
          onBackPressed: _goBackToMain,
          isIconOnly: widget.isIconOnly,
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
    return Expanded(
      child: AnimatedSwitcher(
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
      ),
    );
  }
}

enum NavigationType {
  main,
  detail,
}
