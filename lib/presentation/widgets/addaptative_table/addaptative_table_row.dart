// Adaptive table row
// Full-width, fully-clickable row with responsive columns. Supports touch with large hit area.

import 'package:flutter/material.dart';

class AddaptativeTableRow extends StatelessWidget {
  final List<AddaptativeTableRowCell> cells;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double columnSpacing;
  final BorderRadius? borderRadius;
  final Color? hoverColor;
  final int? hoverElevation;

  const AddaptativeTableRow({
    super.key,
    required this.cells,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    this.columnSpacing = 16,
    this.borderRadius,
    this.hoverColor,
    this.hoverElevation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedHoverColor = hoverColor ?? theme.colorScheme.primary.withValues(alpha: 0.04);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(6),
        splashFactory: InkSparkle.splashFactory,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              for (int i = 0; i < cells.length; i++) ...[
                Expanded(flex: cells[i].flex, child: cells[i].child),
                if (i < cells.length - 1) SizedBox(width: columnSpacing),
              ],
            ],
          ),
        ),
        hoverColor: resolvedHoverColor,
      ),
    );
  }
}

class AddaptativeTableRowCell {
  final Widget child;
  final int flex;
  const AddaptativeTableRowCell(this.child, {this.flex = 1});
}


