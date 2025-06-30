// Styled tab bar widget with rounded tabs and background colors for selected state
// Features width that fits content and improved padding

import 'package:flutter/material.dart';

class StyledTabItem {
  final String label;
  final IconData? icon;
  final bool isDisabled;

  const StyledTabItem({
    required this.label,
    this.icon,
    this.isDisabled = false,
  });
}

class StyledTabBar extends StatelessWidget {
  final List<StyledTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final EdgeInsets padding;
  final double tabSpacing;
  final Duration animationDuration;
  final EdgeInsets tabPadding;

  const StyledTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTabSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    this.tabSpacing = 8.0,
    this.animationDuration = const Duration(milliseconds: 200),
    this.tabPadding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: padding,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == selectedIndex;
                  final isDisabled = item.isDisabled;

                  return AnimatedContainer(
                    duration: animationDuration,
                    curve: Curves.easeInOut,
                    margin: EdgeInsets.only(
                      right: index < items.length - 1 ? tabSpacing : 0,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isDisabled ? null : () => onTabSelected(index),
                        borderRadius: BorderRadius.circular(8.0),
                        child: Padding(
                          padding: tabPadding,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (item.icon != null) ...[
                                AnimatedSwitcher(
                                  duration: animationDuration,
                                  child: Icon(
                                    item.icon,
                                    key: ValueKey('$index-$isSelected'),
                                    size: 18,
                                    color: isSelected
                                        ? colorScheme.onPrimary
                                        : isDisabled
                                            ? colorScheme.onSurface.withValues(alpha: 0.38)
                                            : colorScheme.onSurface.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                item.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? colorScheme.onPrimary
                                      : isDisabled
                                          ? colorScheme.onSurface.withValues(alpha: 0.38)
                                          : colorScheme.onSurface.withValues(alpha: 0.8),
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
