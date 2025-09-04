// Shared domain group section component for list screens
// Handles expand/collapse functionality for domain groups with projects/workflows

import 'package:flutter/material.dart';

import '../../../core/theme/chart_theme_usage.dart';

class DomainGroupSection extends StatelessWidget {
  final String title;
  final bool isExpanded;
  final VoidCallback? onToggle;
  final Widget child;

  const DomainGroupSection({
    super.key,
    required this.title,
    required this.isExpanded,
    required this.child,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: context.domainNameStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 8),
            child,
          ],
        ],
      ),
    );
  }
}
