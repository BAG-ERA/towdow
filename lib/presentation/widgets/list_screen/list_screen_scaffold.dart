// Shared scaffold component for list screens (projects and workflows)
// Provides consistent layout with header, tabs, body, and floating action button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/utils/styled_tab_bar.dart';
import '../../widgets/header_screen_widget.dart';
import 'package:towdow_app/l10n/app_localizations.dart';

class ListScreenScaffold extends ConsumerWidget {
  final String title;
  final int selectedTabIndex;
  final Function(int) onTabSelected;
  final Widget body;
  final Widget floatingActionButton;
  final bool showVoiceFeedback;

  const ListScreenScaffold({
    super.key,
    required this.title,
    required this.selectedTabIndex,
    required this.onTabSelected,
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
          preferredSize: const Size.fromHeight(80),
          child: StyledTabBar(
            items: [
              StyledTabItem(label: AppLocalizations.of(context)!.ongoing),
              StyledTabItem(label: AppLocalizations.of(context)!.archived),
              StyledTabItem(label: AppLocalizations.of(context)!.all),
            ],
            selectedIndex: selectedTabIndex,
            onTabSelected: onTabSelected,
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
