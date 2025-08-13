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
import 'presentation/screens/navigation/nav_screen.dart';

import 'presentation/screens/project_detail/project_detail_screen.dart';
import 'presentation/viewmodels/appearance_settings_viewmodel.dart';
import 'presentation/widgets/adaptive_app_layout.dart';
import 'presentation/providers/home_providers.dart';
import 'data/providers/providers.dart';
import 'core/theme/chart_theme.dart';
import 'core/update/gitlab_update_service.dart';
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
bool _isDesktopPlatform() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

final routerProvider = Provider<GoRouter>((ref) {
  final accountNotifier = ref.watch(accountStatusNotifierProvider);
  final sessionEpoch = ref.watch(sessionEpochProvider);

      return GoRouter(
    navigatorKey: globalNavigatorKey,
    initialLocation: '/nav',
    refreshListenable: Listenable.merge([accountNotifier, ValueNotifier(sessionEpoch)]),
    redirect: (context, state) {
      final isDesktop = _isDesktopPlatform();

      // Redirect root path to nav on mobile, projects on desktop
      if (state.uri.path == '/') {
        return isDesktop ? '/projects' : '/nav';
      }

      // Redirect /nav away on desktop platforms
      if (isDesktop && state.uri.path == '/nav') {
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
      // Route outside the main shell for mobile navigation screen
      GoRoute(
        path: '/nav',
        pageBuilder: (context, state) => _buildPageForPlatformRoute(path: '/nav', state: state, child: const NavScreen()),
      ),
      // Main app shell with adaptive navigation
      ShellRoute(
        builder: (context, state, child) {
          // Determine current destination from route
          AppDestination? currentDestination;
          final location = state.uri.path;
          
          if (location.startsWith('/settings')) {
            currentDestination = null; // Settings handled by toolbar
          } else if (location.startsWith('/project/')) {
            // Keep Projects tab active when viewing a specific project
            currentDestination = AppDestination.projects;
          } else if (location.startsWith('/workflow/')) {
            // Keep Workflows tab active when viewing a specific workflow
            currentDestination = AppDestination.workflows;
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
            pageBuilder: (context, state) => _buildPageForPlatformRoute(path: '/', state: state, child: const _AppShell()),
          ),
          GoRoute(
            path: '/today',
            pageBuilder: (context, state) => _buildPageForPlatformRoute(path: '/today', state: state, child: const _TaskViewShell(initialTab: 0)),
          ),
          GoRoute(
            path: '/soon',
            pageBuilder: (context, state) => _buildPageForPlatformRoute(path: '/soon', state: state, child: const _TaskViewShell(initialTab: 1)),
          ),
          GoRoute(
            path: '/next-week',
            pageBuilder: (context, state) => _buildPageForPlatformRoute(path: '/next-week', state: state, child: const _TaskViewShell(initialTab: 2)),
          ),
          GoRoute(
            path: '/later',
            pageBuilder: (context, state) => _buildPageForPlatformRoute(path: '/later', state: state, child: const _TaskViewShell(initialTab: 3)),
          ),
          GoRoute(
            path: '/anytime',
            pageBuilder: (context, state) => _buildPageForPlatformRoute(path: '/anytime', state: state, child: const _TaskViewShell(initialTab: 4)),
          ),

          GoRoute(
            path: '/project/:path',
            pageBuilder: (context, state) => _buildPageForPlatformRoute(
              path: '/project',
              state: state,
              child: ProjectDetailScreen(
                projectPath: Uri.decodeComponent(state.pathParameters['path']!),
              ),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => _buildPageForPlatformRoute(path: '/settings', state: state, child: const SettingsScreen()),
          ),
          
          GoRoute(
            path: '/projects',
            pageBuilder: (context, state) => _buildPageForPlatformRoute(path: '/projects', state: state, child: const ProjectsListScreen()),
          ),
           GoRoute(
             path: '/workflows',
             pageBuilder: (context, state) => _buildPageForPlatformRoute(path: '/workflows', state: state, child: const WorkflowListScreen()),
           ),
           GoRoute(
             path: '/workflow/:path',
             pageBuilder: (context, state) => _buildPageForPlatformRoute(
               path: '/workflow',
               state: state,
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
        pageBuilder: (context, state) => _buildPageForPlatformRoute(path: '/connect', state: state, child: const ConnectionScreen()),
      ),
    ],
  );
});

class FlowItApp extends ConsumerStatefulWidget {
  const FlowItApp({super.key});

  @override
  ConsumerState<FlowItApp> createState() => _FlowItAppState();
}

class _FlowItAppState extends ConsumerState<FlowItApp> {
  @override
  void initState() {
    super.initState();
    // Kick the update check right after first frame, using global navigator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GitLabUpdateService().checkAndPromptIfNeeded(); // no context needed
    });
  }

  @override
  Widget build(BuildContext context) {
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

// Returns a page with slide transitions on mobile, and no transitions on desktop
Page<dynamic> _buildPageForPlatformRoute({required String path, required GoRouterState state, required Widget child}) {
  final isDesktop = _isDesktopPlatform();
  if (isDesktop) {
    return NoTransitionPage(child: child);
  }
  // Determine direction based on route pairing
  // - /nav -> list/screens: slide left
  // - list/screens -> /nav: slide right
  // - list -> detail: slide left
  // - detail -> list: slide right
  final location = state.uri.path;
  final bool isDetail = location.startsWith('/project/') || location.startsWith('/workflow/');
  final bool isList = location == '/projects' || location == '/workflows' ||
      location == '/today' || location == '/soon' || location == '/anytime' ||
      location == '/next-week' || location == '/later' || location == '/settings' || location == '/';
  final bool goingToNav = path == '/nav';
  final bool comingFromNav = location == '/nav';

  // Default forward slide (left)
  Offset begin = const Offset(1.0, 0.0);

  if (goingToNav) {
    // Any screen -> nav: slide right
    begin = const Offset(-1.0, 0.0);
  } else if (comingFromNav) {
    // nav -> any screen: slide left
    begin = const Offset(1.0, 0.0);
  } else if (isDetail && isList) {
    // list -> detail: left
    begin = const Offset(1.0, 0.0);
  } else if (!isDetail && (path == '/project' || path == '/workflow')) {
    // list -> detail explicit: left
    begin = const Offset(1.0, 0.0);
  } else if (isDetail && (path == '/projects' || path == '/workflows' || path == '/today' || path == '/soon' || path == '/anytime' || path == '/next-week' || path == '/later' || path == '/settings')) {
    // detail -> list/settings: right
    begin = const Offset(-1.0, 0.0);
  }

  return CustomTransitionPage(
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return SlideTransition(position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved), child: child);
    },
  );
}
