// Adaptive app layout that switches between desktop and mobile layouts
// Desktop: permanent sidebar + main content area
// Mobile: drawer navigation + full-screen content

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'navbar/app_sidebar.dart';
import '../../data/models/task_calendar.dart';

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
      begin: const Offset(0.3, 0), // Start slightly from the right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));
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
    
    // Open drawer on start for mobile devices on first load
    if (!isDesktop && isFirstMobileLoad && !_hasOpenedDrawerOnStart) {
      _hasOpenedDrawerOnStart = true;
      
      // Use addPostFrameCallback to ensure the widget is built before opening drawer
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scaffoldKey.currentState != null) {
          _slideAnimationController.reset();
          _scaffoldKey.currentState!.openDrawer();
          // Mark that we've completed the first mobile load
          ref.read(_firstMobileLoadProvider.notifier).state = false;
        }
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
      onPopInvoked: (didPop) {
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
      return _MobileEditableProjectTitle(
        project: project,
        onProjectUpdated: updateCallback,
      );
    }
    
    // Fallback to regular title
    final title = ref.watch(mobileTitleProvider) ?? 'Project Details';
    return Text(title);
  }
}

class _MobileEditableProjectTitle extends StatefulWidget {
  final TaskCalendar project;
  final Function(TaskCalendar) onProjectUpdated;

  const _MobileEditableProjectTitle({
    required this.project,
    required this.onProjectUpdated,
  });

  @override
  State<_MobileEditableProjectTitle> createState() => _MobileEditableProjectTitleState();
}

class _MobileEditableProjectTitleState extends State<_MobileEditableProjectTitle> {
  bool _isEditing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.project.displayName);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_MobileEditableProjectTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.project.uid != widget.project.uid) {
      setState(() {
        _isEditing = false;
      });
      _controller.text = widget.project.displayName;
    } else if (oldWidget.project.displayName != widget.project.displayName) {
      if (!_isEditing) {
        _controller.text = widget.project.displayName;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return SizedBox(
        width: double.infinity,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            isDense: true,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: _cancelEdit,
                  tooltip: 'Cancel',
                ),
                IconButton(
                  icon: const Icon(Icons.check, size: 16),
                  onPressed: _saveTitle,
                  tooltip: 'Save',
                ),
              ],
            ),
          ),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onSubmitted: (_) => _saveTitle(),
        ),
      );
    }

    return InkWell(
      onTap: _startEditing,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          widget.project.displayName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _controller.text = widget.project.displayName;
    });
  }

  void _saveTitle() {
    if (_controller.text.trim().isNotEmpty) {
      final newTitle = _controller.text.trim();
      
      final updatedProject = widget.project.copyWith(
        displayName: newTitle,
        lastModified: DateTime.now(),
      );
      
      widget.onProjectUpdated(updatedProject);
    }
    
    setState(() {
      _isEditing = false;
    });
  }
} 
