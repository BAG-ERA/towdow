import 'package:flutter/material.dart';

enum NavigationItem {
  today(
    label: 'Today',
    icon: Icons.today,
  ),
  soon(
    label: 'Soon',
    icon: Icons.upcoming,
  ),
  unregistered(
    label: 'Unregistered',
    icon: Icons.inbox,
  ),
  projects(
    label: 'Projects',
    icon: Icons.folder,
  );

  final String label;
  final IconData icon;

  const NavigationItem({
    required this.label,
    required this.icon,
  });
}

class AdaptiveNavigation extends StatelessWidget {
  final bool isDesktop;
  final NavigationItem selectedItem;
  final ValueChanged<NavigationItem> onNavigationItemSelected;
  final Widget? child;

  const AdaptiveNavigation({
    super.key,
    required this.isDesktop,
    required this.selectedItem,
    required this.onNavigationItemSelected,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Desktop: Show a side-by-side layout with navigation rail
    if (isDesktop) {
      return Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 250,
            selectedIndex: selectedItem.index,
            onDestinationSelected: (index) {
              onNavigationItemSelected(NavigationItem.values[index]);
            },
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'FlowIt',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            destinations: NavigationItem.values.map((item) {
              return NavigationRailDestination(
                icon: Icon(item.icon),
                label: Text(item.label),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main content area
          if (child != null)
            Expanded(
              child: child!,
            ),
        ],
      );
    }

    // Mobile: Show either the navigation menu or the content
    return child ?? _buildNavigationMenu(context);
  }

  Widget _buildNavigationMenu(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FlowIt'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ...NavigationItem.values.map((item) {
            return ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              selected: item == selectedItem,
              onTap: () => onNavigationItemSelected(item),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement task creation
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 