// Adaptive table container
// Provides a simple card-based container for a table-like layout with an optional header
// and a list of row widgets. This widget does not manage scrolling; callers should wrap
// it with appropriate scroll views for their layouts.

import 'package:flutter/material.dart';

class AddaptativeTableContainer extends StatelessWidget {
  final Widget? header;
  final List<Widget> rows;
  final EdgeInsetsGeometry contentPadding;
  final double rowDividerIndent; // left indent for dividers to align under first column content
  final bool showHeaderDivider;
  final bool showRowDividers;

  const AddaptativeTableContainer({
    super.key,
    this.header,
    required this.rows,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.rowDividerIndent = 0,
    this.showHeaderDivider = false,
    this.showRowDividers = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: contentPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (header != null) ...[
              header!,
              if (showHeaderDivider) ...[
                const SizedBox(height: 8),
                Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor),
              ]
            ],
            // Rows
            for (int i = 0; i < rows.length; i++) ...[
              rows[i],
              if (showRowDividers && i < rows.length - 1)
                Padding(
                  padding: EdgeInsets.only(left: rowDividerIndent),
                  child: Divider(height: 1, color: Theme.of(context).dividerColor),
                ),
            ],
          ],
        ),
      ),
    );
  }
}


