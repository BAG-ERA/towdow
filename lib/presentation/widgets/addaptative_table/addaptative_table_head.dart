// Adaptive table header
// Renders a responsive header row with columns that can show label and optional trailing widget
// like sort icons. The layout uses Flexible to fit within available width gracefully.

import 'package:flutter/material.dart';

class AddaptativeTableHead extends StatelessWidget {
  final List<AddaptativeTableHeadCell> cells;
  final EdgeInsetsGeometry padding;
  final double columnSpacing;

  const AddaptativeTableHead({
    super.key,
    required this.cells,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    this.columnSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          fontWeight: FontWeight.w600,
        );
    return Padding(
      padding: padding,
      child: Row(
        children: [
          for (int i = 0; i < cells.length; i++) ...[
            Expanded(
              flex: cells[i].flex,
              child: Align(
                alignment: cells[i].alignment ?? Alignment.centerLeft,
                child: DefaultTextStyle(
                  style: textStyle ?? const TextStyle(fontSize: 12),
                  child: InkWell(
                    onTap: cells[i].onTap,
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            cells[i].label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (cells[i].trailing != null) ...[
                          const SizedBox(width: 4),
                          cells[i].trailing!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (i < cells.length - 1) SizedBox(width: columnSpacing),
          ],
        ],
      ),
    );
  }
}

class AddaptativeTableHeadCell {
  final String label;
  final Widget? trailing;
  final int flex;
  final Alignment? alignment;
  final VoidCallback? onTap;
  const AddaptativeTableHeadCell({
    required this.label,
    this.trailing,
    this.flex = 1,
    this.alignment,
    this.onTap,
  });
}


