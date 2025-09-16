// Adaptive app layout that switches between desktop and mobile layouts
// Desktop: permanent sidebar + main content area
// Mobile: drawer navigation + full-screen content

import 'package:flutter/material.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'navbar/app_sidebar.dart';
import 'navbar/project_popup_menu.dart';
import '../../data/models/task_calendar.dart';
import '../../data/providers/providers.dart';
import 'utils/popup/move_to_domain_dialog.dart';
import 'utils/popup/project_sharing_dialog.dart';
import 'common/monitoring_status_widget.dart';

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
  ),
  projects(
    label: 'Projects',
    icon: Icons.folder_rounded,
    route: '/projects',
  ),
  workflows(
    label: 'Workflows',
    icon: Icons.route_rounded,
    route: '/workflows',
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
      begin: const Offset(0.2, 0), // Start slightly from the right when drawer closes
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start in completed state - animation will be triggered when drawer closes
    _slideAnimationController.value = 1.0;
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
    
    // Do not auto-open drawer anymore; first screen on mobile is /nav
    if (!isDesktop && isFirstMobileLoad && !_hasOpenedDrawerOnStart) {
      _hasOpenedDrawerOnStart = true;
      
      // Use a longer delay to ensure the layout is fully established
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Add an additional delay to ensure everything is rendered
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _scaffoldKey.currentState != null) {
            // Mark that we've completed the first mobile load
            ref.read(_firstMobileLoadProvider.notifier).state = false;
          }
        });
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
      onPopInvokedWithResult: (didPop, result) {
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
            // Drawer is closed, go to nav screen instead of opening drawer
            context.go('/nav');
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
    bool isListScreen = false;
    final location = GoRouterState.of(context).uri.path;

    if (location.startsWith('/settings')) {
      title = AppLocalizations.of(context)!.settings;
      isListScreen = true;
    } else if (location.startsWith('/project/')) {
      title = ref.watch(mobileTitleProvider) ?? AppLocalizations.of(context)!.projectDetails;
      isDetailScreen = true;
    } else if (location == '/projects') {
      title = AppLocalizations.of(context)!.allProjects;
      isListScreen = true;
    } else if (location.startsWith('/workflow/')) {
      title = ref.watch(mobileTitleProvider) ?? AppLocalizations.of(context)!.workflowDetails;
      isDetailScreen = true;
    } else if (location == '/workflows') {
      title = AppLocalizations.of(context)!.allWorkflows;
      isListScreen = true;
    } else if (location == '/' || location.startsWith('/today') || location.startsWith('/soon') ||
        location.startsWith('/next-week') || location.startsWith('/later') || location.startsWith('/anytime')) {
      title = AppLocalizations.of(context)!.myTasks;
      isListScreen = false; // Don't show AppBar for home routes - HomeScreen handles its own AppBar
    }
    return Scaffold(
      key: _scaffoldKey,
      appBar: (isDetailScreen || isListScreen) ? AppBar(
        title: location.startsWith('/project/') 
            ? Text(ref.watch(mobileTitleProvider) ?? AppLocalizations.of(context)!.projectDetails)
            : Text(title),
        centerTitle: false,
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (isDetailScreen) {
                // Detail pages go back to their list
                if (location.startsWith('/project/')) {
                  context.go('/projects');
                } else if (location.startsWith('/workflow/')) {
                  context.go('/workflows');
                }
              } else if (isListScreen) {
                // List pages go to navigation
                context.go('/nav');
              }
            },
            tooltip: isDetailScreen
                ? (location.startsWith('/project/')
                    ? AppLocalizations.of(context)!.backToProjects
                    : AppLocalizations.of(context)!.backToWorkflows)
                : AppLocalizations.of(context)!.backToNavigation,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: MonitoringStatusWidget(compact: true),
          ),
        ],
      ) : null,
      body: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: widget.child,
        ),
      ),
    );
  }
} 
