// Main application sidebar component
// Displays navigation sections and projects using modular widgets

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation_switcher.dart';
import 'toolbar_widget.dart';
import 'user_account_badge.dart';

import '../adaptive_app_layout.dart';

class AppSidebar extends ConsumerStatefulWidget {
  const AppSidebar({
    super.key,
    required this.currentDestination,
    this.fullWidth = false,
  });

  final AppDestination? currentDestination;
  final bool fullWidth;

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  static const double _minWidth = 80.0; // Minimal width in pixels
  static const double _maxWidth = 360.0; // Maximum width in pixels
  double _currentWidth = 280.0; // Start at default width
  bool _isResizing = false;

  @override
  Widget build(BuildContext context) {
    // Check if we're on mobile (same breakpoint as AdaptiveAppLayout)
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;

    if (!isDesktop) {
      final double containerWidth = widget.fullWidth ? double.infinity : 280.0;

      return Container(
        width: containerWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const UserAccountBadge(),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NavigationSwitcher(
                    currentDestination: widget.currentDestination,
                    isDesktop: isDesktop,
                    isIconOnly: false,
                  ),
                  const Divider(height: 24, color: Colors.transparent),
                ],
              ),
            ),
            const ToolbarWidget(),
            SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 0),
          ],
        ),
      );
    }

    final bool isIconOnly = _currentWidth <= _minWidth;

    return Container(
      width: _currentWidth,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              const UserAccountBadge(),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NavigationSwitcher(
                      currentDestination: widget.currentDestination,
                      isDesktop: isDesktop,
                      isIconOnly: isIconOnly,
                    ),
                    const Divider(height: 24, color: Colors.transparent),
                  ],
                ),
              ),
              ToolbarWidget(isIconOnly: isIconOnly),
            ],
          ),

          // Resize handle at the right edge
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) {
                  setState(() {
                    _isResizing = true;
                  });
                },
                onPanUpdate: (details) {
                  final double proposed = _currentWidth + details.delta.dx;
                  final double clamped = proposed.clamp(_minWidth, _maxWidth);
                  if (clamped != _currentWidth) {
                    setState(() {
                      _currentWidth = clamped;
                    });
                  }
                },
                onPanEnd: (_) {
                  setState(() {
                    _isResizing = false;
                  });
                },
                child: SizedBox(
                  width: 8,
                  child: Center(
                    child: Container(
                      width: 2,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _isResizing
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
