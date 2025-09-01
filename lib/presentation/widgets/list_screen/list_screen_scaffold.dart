// Shared scaffold component for list screens (projects and workflows)
// Provides consistent layout with header, domain tabs, toggle button, body, and floating action button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  child: Text(
                    showArchived 
                        ? 'Go to active ${title.toLowerCase()}'
                        : 'Go to archived ${title.toLowerCase()}',
                  ),
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
  }
}
