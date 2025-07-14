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

// ChangeNotifier wrapper for AsyncValue to make GoRouter reactive
class AsyncValueNotifier<T> extends ChangeNotifier {
  AsyncValueNotifier(this._asyncValue);
  
  AsyncValue<T> _asyncValue;
  
  AsyncValue<T> get asyncValue => _asyncValue;
  
  void update(AsyncValue<T> newValue) {
    if (newValue != _asyncValue) {
      _asyncValue = newValue;
      notifyListeners();
    }
  }
}

// Provider for account status change notifier
final accountStatusNotifierProvider = Provider<AsyncValueNotifier<bool>>((ref) {
  final asyncValue = ref.watch(hasActiveAccountProvider);
  final notifier = AsyncValueNotifier<bool>(asyncValue);
  
  ref.listen<AsyncValue<bool>>(hasActiveAccountProvider, (previous, next) {
    notifier.update(next);
  });
  
  return notifier;
});

// GoRouter provider that's reactive to account changes
final routerProvider = Provider<GoRouter>((ref) {
  final accountNotifier = ref.watch(accountStatusNotifierProvider);
  final sessionEpoch = ref.watch(sessionEpochProvider);

  return GoRouter(
    navigatorKey: globalNavigatorKey,
    initialLocation: '/today',
    refreshListenable: Listenable.merge([accountNotifier, ValueNotifier(sessionEpoch)]),
    redirect: (context, state) {
      // Redirect root path to today view
      if (state.uri.path == '/') {
        return '/today';
      }
      
      // Skip account check if already on connection screen
      if (state.uri.path == '/connect') {
        return null;
      }
      
      // Check account status from the notifier
      return accountNotifier.asyncValue.when(
        data: (hasAccount) {
          if (!hasAccount) {
            // No active account, redirect to connection screen
            return '/connect';
          }
          return null;
        },
        loading: () {
          // Still loading, allow route to proceed
          return null;
        },
        error: (error, stackTrace) {
          // Error checking account status, redirect to connection screen
          return '/connect';
        },
      );
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
            path: '/project/:path',
            builder: (context, state) => ProjectDetailScreen(
              projectPath: Uri.decodeComponent(state.pathParameters['path']!),
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
});

class FlowItApp extends ConsumerWidget {
  const FlowItApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize AppLifecycleManager
    ref.watch(appLifecycleInitializationProvider);
    
    // Get the reactive router
    final router = ref.watch(routerProvider);

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
      routerConfig: router,
    );
  }
}

// App Shell - account checking now handled by router
class _AppShell extends ConsumerWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Account checking is now handled by router redirect
    // This will only be called when user has an active account
    return const HomeScreen();
  }
}

// Task View Shell to handle time-based task views
class _TaskViewShell extends ConsumerWidget {
  const _TaskViewShell({required this.initialTab});
  
  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Account checking is now handled by router redirect
    // This will only be called when user has an active account
    
    // Set the initial tab and show the home screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedTabIndexProvider.notifier).state = initialTab;
    });
    return const HomeScreen();
  }
} 
