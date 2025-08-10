// Adaptive app layout that switches between desktop and mobile layouts
// Desktop: permanent sidebar + main content area
// Mobile: drawer navigation + full-screen content

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/logger.dart';
import 'navbar/app_sidebar.dart';
import 'navbar/project_popup_menu.dart';
import '../../data/models/task_calendar.dart';
import '../../data/providers/providers.dart';
import 'utils/editable_title.dart';
import 'utils/popup/move_to_domain_dialog.dart';
import 'utils/popup/project_sharing_dialog.dart';

// Provider for dynamic mobile title (used by detail screens)
final mobileTitleProvider = StateProvider<String?>((ref) => null);

// Providers for mobile project editing
final mobileProjectProvider = StateProvider<TaskCalendar?>((ref) => null);
final mobileProjectUpdateProvider = StateProvider<Function(TaskCalendar)?>(
  (ref) => null,
);

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
    
    // Open drawer on mobile startup, but with proper timing to avoid layout issues
    if (!isDesktop && isFirstMobileLoad && !_hasOpenedDrawerOnStart) {
      _hasOpenedDrawerOnStart = true;
      
      // Use a longer delay to ensure the layout is fully established
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Add an additional delay to ensure everything is rendered
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _scaffoldKey.currentState != null) {
            _scaffoldKey.currentState!.openDrawer();
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
    } else if (location == '/projects') {
      title = 'All Projects';
      isDetailScreen = true;
    } else if (location == '/' || location.startsWith('/today') || location.startsWith('/soon') || 
               location.startsWith('/next-week') || location.startsWith('/later') || location.startsWith('/anytime')) {
      title = 'My Tasks';
      isDetailScreen = true;
    }    
    return Scaffold(
      key: _scaffoldKey,
      appBar: isDetailScreen ? AppBar(
        title: location.startsWith('/project/') 
            ? _buildMobileProjectTitle(ref)
            : Text(title),
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
        actions: location.startsWith('/project/') 
            ? [_buildMobileProjectMenu(context, ref)]
            : null,
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

  Widget _buildMobileProjectTitle(WidgetRef ref) {
    final project = ref.watch(mobileProjectProvider);
    final updateCallback = ref.watch(mobileProjectUpdateProvider);
    
    if (project != null && updateCallback != null) {
      return EditableTitle(
        title: project.displayName,
        onTitleUpdated: (newTitle) {
          final updatedProject = project.copyWith(
            displayName: newTitle,
            lastModified: DateTime.now(),
          );
          updateCallback(updatedProject);
        },
        isInAppBar: true,
      );
    }
    
    // Fallback to regular title
    final title = ref.watch(mobileTitleProvider) ?? 'Project Details';
    return Text(title);
  }

  Widget _buildMobileProjectMenu(BuildContext context, WidgetRef ref) {
    final project = ref.watch(mobileProjectProvider);
    
    if (project == null) {
      return const SizedBox.shrink();
    }
    
    return ProjectPopupMenu(
      onMenuAction: (action) => _handleMobileProjectMenuAction(context, ref, action),
    );
  }

  void _handleMobileProjectMenuAction(BuildContext context, WidgetRef ref, String action) {
    final project = ref.read(mobileProjectProvider);
    if (project == null) return;

    switch (action) {
      case 'move_to_domain':
        _showMoveToDomainDialog(context, project);
        break;
      case 'share_project':
        _showProjectSharingDialog(context, project);
        break;
      case 'archive_project':
        _handleArchiveProject(context, ref, project);
        break;
      case 'delete_project':
        _showDeleteConfirmation(context, ref, project);
        break;
    }
  }

  void _showMoveToDomainDialog(BuildContext context, TaskCalendar project) {
    // Import and use the existing dialog
    showDialog(
      context: context,
      builder: (context) => MoveToDomainDialog(project: project),
    );
  }

  void _showProjectSharingDialog(BuildContext context, TaskCalendar project) {
    // Import and use the existing dialog
    showDialog(
      context: context,
      builder: (context) => ProjectSharingDialog(project: project),
    );
  }

  void _handleArchiveProject(BuildContext context, WidgetRef ref, TaskCalendar project) async {
    try {
      final statusService = ref.read(statusServiceProvider);
      final result = await statusService.archiveCalendar(project.path);
      
      result.when(
        success: (_) {
        },
        failure: (failure) {
          AppLogger.error('Failed to archive project: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('Failed to archive project: $e');
    }
  }

  void _handleUnarchiveProject(BuildContext context, WidgetRef ref, TaskCalendar project) async {
    try {
      final statusService = ref.read(statusServiceProvider);
      final result = await statusService.unarchiveCalendar(project.path);
      
      result.when(
        success: (_) {
        },
        failure: (failure) {
          AppLogger.error('Failed to unarchive project: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('Failed to unarchive project: $e');
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, TaskCalendar project) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text(
          'Are you sure you want to delete "${project.displayName}"? This action cannot be undone and will remove all associated tasks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteProject(context, ref, project);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteProject(BuildContext context, WidgetRef ref, TaskCalendar project) async {
    try {
      final projectListViewModel = ref.read(projectListViewModelProvider.notifier);
      await projectListViewModel.deleteProject(project.path);
      
      // Navigate away from project if currently viewing it
      final currentRoute = GoRouterState.of(context).uri.path;
      if (currentRoute == '/project/${Uri.encodeComponent(project.path)}') {
        context.go('/');
      }
      
    } catch (e) {
      AppLogger.error('Failed to delete project: $e');
    }
  }
} 
