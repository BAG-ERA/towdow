import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../widgets/adaptive_navigation.dart';
import '../widgets/task_form.dart';
import '../../data/models/task_model.dart';
import 'today_screen.dart';
import 'soon_screen.dart';
import 'unregistered_screen.dart';
import 'projects_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  NavigationItem _selectedItem = NavigationItem.today;
  bool _showNavigation = true;

  // Public getters/setters for navigation state
  NavigationItem get selectedItem => _selectedItem;
  set selectedItem(NavigationItem value) {
    setState(() {
      _selectedItem = value;
    });
  }

  bool get showNavigation => _showNavigation;
  set showNavigation(bool value) {
    setState(() {
      _showNavigation = value;
    });
  }

  void _showTaskForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const TaskForm(),
    ).then((created) {
      if (created == true) {
        // Refresh the current screen
        setState(() {});
      }
    });
  }

  void _showProjectForm(BuildContext context) {
    final newProject = TaskModel(
      uid: const Uuid().v4(),
      summary: '',
      type: FlowItType.taskGroup,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TaskForm(
        initialTask: newProject,
      ),
    ).then((created) {
      if (created == true) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return AdaptiveNavigation(
      isDesktop: isDesktop,
      selectedItem: _selectedItem,
      onNavigationItemSelected: (item) {
        setState(() {
          _selectedItem = item;
          // On mobile, hide navigation when an item is selected
          if (!isDesktop) {
            _showNavigation = false;
          }
        });
      },
      // Only show content if we're on desktop or navigation is hidden on mobile
      child: isDesktop || !_showNavigation ? _buildScreen() : null,
    );
  }

  Widget _buildScreen() {
    return Scaffold(
      appBar: AppBar(
        // Only show menu button on mobile when not showing navigation
        leading: MediaQuery.of(context).size.width < 600
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  setState(() {
                    _showNavigation = true;
                  });
                },
              )
            : null,
        title: Text(_selectedItem.label),
      ),
      body: _buildContent(),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget? _buildFAB() {
    switch (_selectedItem) {
      case NavigationItem.projects:
        return FloatingActionButton(
          onPressed: () => _showProjectForm(context),
          tooltip: 'Create Project',
          child: const Icon(Icons.create_new_folder),
        );
      case NavigationItem.today:
      case NavigationItem.soon:
      case NavigationItem.unregistered:
        return FloatingActionButton(
          onPressed: () => _showTaskForm(context),
          tooltip: 'Create Task',
          child: const Icon(Icons.add),
        );
    }
  }

  Widget _buildContent() {
    switch (_selectedItem) {
      case NavigationItem.today:
        return const TodayScreen();
      case NavigationItem.soon:
        return const SoonScreen();
      case NavigationItem.unregistered:
        return const UnregisteredScreen();
      case NavigationItem.projects:
        return const ProjectsScreen();
    }
  }
} 