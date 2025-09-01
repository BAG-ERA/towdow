// Shared scaffold component for list screens (projects and workflows)
// Provides consistent layout with header, domain tabs, toggle button, body, and floating action button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:towdow_app/l10n/app_localizations.dart';

import '../../widgets/utils/styled_tab_bar.dart';
import '../../widgets/header_screen_widget.dart';

class ListScreenScaffold extends ConsumerWidget {
  final String title;
  final int selectedTabIndex;
  final Function(int) onTabSelected;
  final List<String> domainTabs;
  final bool showArchived;
  final VoidCallback onToggleArchived;
  final Widget body;
  final Widget floatingActionButton;
  final bool showVoiceFeedback;
  final String? contentType;

  const ListScreenScaffold({
    super.key,
    required this.title,
    required this.selectedTabIndex,
    required this.onTabSelected,
    required this.domainTabs,
    required this.showArchived,
    required this.onToggleArchived,
    required this.body,
    required this.floatingActionButton,
    this.showVoiceFeedback = true,
    this.contentType,
  });

  String _getToggleButtonText(BuildContext context) {
    if (contentType != null) {
      if (showArchived) {
        // Currently showing archived, so button should go to active
        if (contentType == 'projects') {
          return AppLocalizations.of(context)!.goToActiveProjects;
        } else if (contentType == 'workflows') {
          return AppLocalizations.of(context)!.goToActiveWorkflows;
        }
      } else {
        // Currently showing active, so button should go to archived
        if (contentType == 'projects') {
          return AppLocalizations.of(context)!.goToArchivedProjects;
        } else if (contentType == 'workflows') {
          return AppLocalizations.of(context)!.goToArchivedWorkflows;
        }
      }
    }
    
    // Fallback to title-based text
    return showArchived 
        ? 'Go to active ${title.toLowerCase()}'
        : 'Go to archived ${title.toLowerCase()}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;
    
    if (isDesktop) {
      // Desktop layout with HeaderScreenWidget
      return Scaffold(
        appBar: HeaderScreenWidget(
          title: title,
          showVoiceFeedback: showVoiceFeedback,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(120),
            child: Column(
              children: [
                StyledTabBar(
                  items: domainTabs.map((domain) => StyledTabItem(label: domain)).toList(),
                  selectedIndex: selectedTabIndex,
                  onTabSelected: onTabSelected,
                  enableShrink: false, // Domain tabs should not shrink, only scroll
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextButton(
                    onPressed: onToggleArchived,
                    child: Text(_getToggleButtonText(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: body,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: SafeArea(
          child: floatingActionButton,
        ),
      );
    } else {
      // Mobile layout - no AppBar, put tabs and toggle in body
      return Scaffold(
        body: Column(
          children: [
            // Styled tab bar for mobile
            StyledTabBar(
              items: domainTabs.map((domain) => StyledTabItem(label: domain)).toList(),
              selectedIndex: selectedTabIndex,
              onTabSelected: onTabSelected,
              enableShrink: false, // Domain tabs should not shrink, only scroll
            ),
            // Toggle button for mobile
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextButton(
                onPressed: onToggleArchived,
                child: Text(_getToggleButtonText(context)),
              ),
            ),
            // Main content
            Expanded(child: body),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: SafeArea(
          child: floatingActionButton,
        ),
      );
    }
  }
}
