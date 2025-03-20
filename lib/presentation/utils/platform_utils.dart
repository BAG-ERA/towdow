import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/task_detail_widget.dart';
import '../screens/project_detail_screen.dart';
import '../widgets/adaptive_navigation.dart';
import '../screens/main_screen.dart';

void showTaskDetails(BuildContext context, String taskId) {
  // Check if we're on desktop
  final isDesktop = kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  if (isDesktop) {
    showDialog(
      context: context,
      builder: (context) => TaskDetailWidget(
        taskId: taskId,
        isDialog: true,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailWidget(
          taskId: taskId,
          isDialog: false,
        ),
      ),
    );
  }
}

void showProjectDetails(BuildContext context, String projectId) {
  Navigator.push<NavigationItem>(
    context,
    MaterialPageRoute(
      builder: (context) => ProjectDetailScreen(
        projectId: projectId,
      ),
    ),
  ).then((selectedItem) {
    if (selectedItem != null && context.mounted) {
      // If a navigation item was selected, update the main screen
      final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
      if (mainScreenState != null) {
        mainScreenState.selectedItem = selectedItem;
        mainScreenState.showNavigation = false;
      }
    }
  });
} 