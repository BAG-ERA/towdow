// Navigation switcher widget for sidebar
// Switches between different navigation types based on current route:
// - MainNavigation: for general screens
// - DetailNavigation: for project/workflow detail screens
// - SettingsNavigation: for settings screens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'main_navigation.dart';
import 'detail_navigation.dart';
import 'settings_navigation.dart';

class NavigationSwitcher extends ConsumerStatefulWidget {
  const NavigationSwitcher({
    super.key,
    required this.currentDestination,
    required this.isDesktop,
  });

  final dynamic currentDestination;
  final bool isDesktop;

  @override
  ConsumerState<NavigationSwitcher> createState() => _NavigationSwitcherState();
}

class _NavigationSwitcherState extends ConsumerState<NavigationSwitcher> {
  NavigationType _currentNavigationType = NavigationType.main;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.path;
    
    // Determine navigation type based on route
    if (location.startsWith('/project/') || location.startsWith('/workflow/')) {
      _currentNavigationType = NavigationType.detail;
    } else if (location.startsWith('/settings')) {
      _currentNavigationType = NavigationType.settings;
    } else {
      _currentNavigationType = NavigationType.main;
    }
  }

  void _goBackToMain() {
    setState(() {
      _currentNavigationType = NavigationType.main;
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
        );
        break;
      case NavigationType.settings:
        navigationContent = SettingsNavigation(
          isDesktop: widget.isDesktop,
          onBackPressed: _goBackToMain,
        );
        break;
      case NavigationType.main:
      default:
        navigationContent = MainNavigation(
          currentDestination: widget.currentDestination,
          isDesktop: widget.isDesktop,
        );
        break;
    }

    // Wrap navigation content with pink background, take all available space, and add animation
    return Expanded(
      child: Container(
        width: double.infinity,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.1, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                )),
                child: child,
              ),
            );
          },
          child: navigationContent,
        ),
      ),
    );
  }
}

enum NavigationType {
  main,
  detail,
  settings,
}
