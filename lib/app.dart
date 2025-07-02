// Main FlowIt application widget
// Configures Material theme, routing, and global app setup

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/connection/connection_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/archived_projects/archived_projects_screen.dart';

import 'presentation/screens/project_detail/project_detail_screen.dart';
import 'presentation/widgets/adaptive_app_layout.dart';
import 'presentation/providers/home_providers.dart';
import 'data/providers/providers.dart';
import 'core/theme/chart_theme.dart';

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
          seedColor: FlowItColors.primary,
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
        extensions: <ThemeExtension<dynamic>>[
          ChartTheme.light(ColorScheme.fromSeed(
            seedColor: FlowItColors.primary,
            brightness: Brightness.light,
          )),
        ],
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: FlowItColors.primary,
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
        extensions: <ThemeExtension<dynamic>>[
          ChartTheme.dark(ColorScheme.fromSeed(
            seedColor: FlowItColors.primary,
            brightness: Brightness.dark,
          )),
        ],
      ),
      themeMode: ThemeMode.system,
      routerConfig: _createRouter(),
    );
  }

  GoRouter _createRouter() {
    return GoRouter(
      initialLocation: '/today',
      redirect: (context, state) {
        // Redirect root path to today view
        if (state.uri.path == '/') {
          return '/today';
        }
        return null;
      },
      routes: [
        // Main app shell with adaptive navigation
        ShellRoute(
          builder: (context, state, child) {
            // Determine current destination from route
            AppDestination? currentDestination;
            final location = state.uri.path;
            
            if (location.startsWith('/settings')) {
              currentDestination = null; // Settings handled by toolbar
            } else if (location.startsWith('/archived')) {
              currentDestination = null; // Archived projects have no main navigation active
            } else if (location.startsWith('/project/')) {
              currentDestination = null; // Project details have no main navigation active
            } else if (location == '/today' || location == '/') {
              currentDestination = AppDestination.today;
            } else if (location == '/soon') {
              currentDestination = AppDestination.soon;
            } else if (location == '/anytime') {
              currentDestination = AppDestination.anytime;
            } else if (location == '/next-week' || location == '/later') {
              // Next week and later tabs exist but are not shown in sidebar
              currentDestination = null;
            } else {
              currentDestination = AppDestination.today; // Default to today
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
              path: '/today',
              builder: (context, state) => const _TaskViewShell(initialTab: 0),
            ),
            GoRoute(
              path: '/soon',
              builder: (context, state) => const _TaskViewShell(initialTab: 1),
            ),
            GoRoute(
              path: '/next-week',
              builder: (context, state) => const _TaskViewShell(initialTab: 2),
            ),
            GoRoute(
              path: '/later',
              builder: (context, state) => const _TaskViewShell(initialTab: 3),
            ),
            GoRoute(
              path: '/anytime',
              builder: (context, state) => const _TaskViewShell(initialTab: 4),
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
            GoRoute(
              path: '/archived',
              builder: (context, state) => const ArchivedProjectsScreen(),
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

// Task View Shell to handle time-based task views
class _TaskViewShell extends ConsumerWidget {
  const _TaskViewShell({required this.initialTab});
  
  final int initialTab;

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
          // Set the initial tab and show the home screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedTabIndexProvider.notifier).state = initialTab;
          });
          return const HomeScreen();
        } else {
          // No active account, show connection screen
          return const ConnectionScreen();
        }
      },
    );
  }
} 
