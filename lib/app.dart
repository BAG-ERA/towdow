// Main FlowIt application widget
// Configures Material theme, routing, and global app setup

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/connection/connection_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/projects_list/projects_list_screen.dart';
import 'presentation/screens/workflows_list/workflow_list_screen.dart';
import 'presentation/screens/workflow_detail/workflow_detail_screen.dart';

import 'presentation/screens/project_detail/project_detail_screen.dart';
import 'presentation/viewmodels/appearance_settings_viewmodel.dart';
import 'presentation/widgets/adaptive_app_layout.dart';
import 'presentation/providers/home_providers.dart';
import 'data/providers/providers.dart';
import 'core/theme/chart_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

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
    initialLocation: '/projects',
    refreshListenable: Listenable.merge([accountNotifier, ValueNotifier(sessionEpoch)]),
    redirect: (context, state) {
      // Redirect root path to projects on first-run
      if (state.uri.path == '/') {
        return '/projects';
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
          } else if (location.startsWith('/project/')) {
            currentDestination = null; // Project details have no main navigation active
          } else if (location == '/today' || location == '/') {
            currentDestination = AppDestination.today;
          } else if (location == '/soon') {
            currentDestination = AppDestination.soon;
          } else if (location == '/anytime') {
            currentDestination = AppDestination.anytime;
          } else if (location == '/projects') {
            currentDestination = AppDestination.projects;
          } else if (location == '/workflows') {
            currentDestination = AppDestination.workflows;
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
            pageBuilder: (context, state) => _buildPageForDesktop(child: const _AppShell()),
          ),
          GoRoute(
            path: '/today',
            pageBuilder: (context, state) => _buildPageForDesktop(child: const _TaskViewShell(initialTab: 0)),
          ),
          GoRoute(
            path: '/soon',
            pageBuilder: (context, state) => _buildPageForDesktop(child: const _TaskViewShell(initialTab: 1)),
          ),
          GoRoute(
            path: '/next-week',
            pageBuilder: (context, state) => _buildPageForDesktop(child: const _TaskViewShell(initialTab: 2)),
          ),
          GoRoute(
            path: '/later',
            pageBuilder: (context, state) => _buildPageForDesktop(child: const _TaskViewShell(initialTab: 3)),
          ),
          GoRoute(
            path: '/anytime',
            pageBuilder: (context, state) => _buildPageForDesktop(child: const _TaskViewShell(initialTab: 4)),
          ),

          GoRoute(
            path: '/project/:path',
            pageBuilder: (context, state) => _buildPageForDesktop(
              child: ProjectDetailScreen(
                projectPath: Uri.decodeComponent(state.pathParameters['path']!),
              ),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => _buildPageForDesktop(child: const SettingsScreen()),
          ),
          
          GoRoute(
            path: '/projects',
            pageBuilder: (context, state) => _buildPageForDesktop(child: const ProjectsListScreen()),
          ),
           GoRoute(
             path: '/workflows',
             pageBuilder: (context, state) => _buildPageForDesktop(child: const WorkflowListScreen()),
           ),
           GoRoute(
             path: '/workflow/:path',
             pageBuilder: (context, state) => _buildPageForDesktop(
               child: WorkflowDetailScreen(
                 workflowPath: Uri.decodeComponent(state.pathParameters['path']!),
               ),
             ),
           ),
        ],
      ),
      
      // Routes outside the main shell
      GoRoute(
        path: '/connect',
        pageBuilder: (context, state) => _buildPageForDesktop(child: const ConnectionScreen()),
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

      final fontScale = ref.watch(fontScaleProvider);
      final themeMode = ref.watch(themeModeProvider);

      return MaterialApp.router(
      title: AppLocalizations.of(context)?.appTitle ?? 'TowDow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: FlowItColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        dialogTheme: const DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
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
            ), scale: fontScale),
        ],
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: FlowItColors.primary,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        dialogTheme: const DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
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
            ), scale: fontScale),
        ],
      ),
      themeMode: themeMode,
      locale: ref.watch(localeProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
      ],
      routerConfig: router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(fontScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
    
    // Choose the tab once: default to route tab while loading, then switch to first non-empty
    final suggestedAsync = ref.watch(suggestedTabIndexProvider(initialTab));
    final current = ref.watch(selectedTabIndexProvider);
    final applied = ref.watch(initialTabAppliedProvider(initialTab));

    if (!applied) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Mark as applied so we do it only once per route load
        ref.read(initialTabAppliedProvider(initialTab).notifier).state = true;

        if (suggestedAsync.isLoading) {
          if (current != initialTab) {
            ref.read(selectedTabIndexProvider.notifier).state = initialTab;
          }
        } else if (suggestedAsync.hasValue) {
          final suggestedIndex = suggestedAsync.value ?? initialTab;
          if (current != suggestedIndex) {
            ref.read(selectedTabIndexProvider.notifier).state = suggestedIndex;
          }
        } else {
          if (current != initialTab) {
            ref.read(selectedTabIndexProvider.notifier).state = initialTab;
          }
        }
      });
    }
    return const HomeScreen();
  }
} 

// Returns a page without transitions on desktop platforms, default transitions elsewhere
Page<dynamic> _buildPageForDesktop({required Widget child}) {
  final isDesktop = !kIsWeb && (
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.macOS
  );
  if (isDesktop) {
    return NoTransitionPage(child: child);
  }
  return MaterialPage(child: child);
}
