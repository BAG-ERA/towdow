// Main FlowIt application widget
// Configures Material theme, routing, and global app setup

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/connection/connection_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/projects/projects_screen.dart';
import 'presentation/screens/project_detail/project_detail_screen.dart';
import 'presentation/widgets/adaptive_app_layout.dart';
import 'data/providers/providers.dart';

class FlowItApp extends ConsumerWidget {
  const FlowItApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize AppLifecycleManager
    ref.watch(appLifecycleInitializationProvider);

    return MaterialApp.router(
      title: 'FlowIt',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      routerConfig: _createRouter(),
    );
  }

  GoRouter _createRouter() {
    return GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        // For now, let's disable the automatic redirect to allow testing
        // We'll implement the proper redirect logic later
        return null;
      },
      routes: [
        // Main app shell with adaptive navigation
        ShellRoute(
          builder: (context, state, child) {
            // Determine current destination from route
            AppDestination currentDestination;
            final location = state.uri.path;
            
            if (location.startsWith('/projects') || location.startsWith('/project/')) {
              currentDestination = AppDestination.projects;
            } else if (location.startsWith('/settings')) {
              currentDestination = AppDestination.settings;
            } else {
              currentDestination = AppDestination.myTasks;
            }

            return AdaptiveAppLayout(
              currentDestination: currentDestination,
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const _AppShell(),
            ),
            GoRoute(
              path: '/projects',
              builder: (context, state) => const ProjectsScreen(),
            ),
            GoRoute(
              path: '/project/:uid',
              builder: (context, state) => ProjectDetailScreen(
                projectUid: state.pathParameters['uid']!,
              ),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
        
        // Routes outside the main shell
        GoRoute(
          path: '/connect',
          builder: (context, state) => const ConnectionScreen(),
        ),
      ],
    );
  }
}

// App Shell to handle account status checking
class _AppShell extends ConsumerWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccountAsync = ref.watch(hasActiveAccountProvider);

    return hasAccountAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('Error checking account status: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(hasActiveAccountProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (hasAccount) {
        if (hasAccount) {
          // User has an active account, show main app
          return const HomeScreen();
        } else {
          // No active account, show connection screen
          return const ConnectionScreen();
        }
      },
    );
  }
} 
