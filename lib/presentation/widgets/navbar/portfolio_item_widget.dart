// Portfolio item widget for displaying calendar portfolios with task count and expand functionality
// Shows calendar name, remaining task count badge, and expand arrow

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/logger.dart';
import '../../../data/providers/providers.dart';

// Provider for counting remaining tasks by source calendar
final portfolioTaskCountProvider = FutureProvider.family<int, String>((ref, calendarUid) async {
  final taskListAsync = ref.watch(taskListProvider);
  return taskListAsync.when(
    data: (tasks) {
      // Count tasks that are not completed and belong to this calendar
      final remainingTasks = tasks.where((task) {
        return task.status != 'COMPLETED' && task.sourceCalendarUid == calendarUid;
      }).length;
      return remainingTasks;
    },
    loading: () => 0,
          error: (_, _) => 0,
  );
});

// Provider for getting categories used in a portfolio
final portfolioCategoriesProvider = FutureProvider.family<List<String>, String>((ref, calendarUid) async {
  final taskListAsync = ref.watch(taskListProvider);
  return taskListAsync.when(
    data: (tasks) {
      final Set<String> categories = {};
      for (final task in tasks) {
        if (task.status != 'COMPLETED' && task.sourceCalendarUid == calendarUid) {
          categories.addAll(task.categories);
        }
      }
      return categories.toList()..sort();
    },
    loading: () => <String>[],
          error: (_, _) => <String>[],
  );
});

// Provider for counting tasks by category in a portfolio
final portfolioCategoryTaskCountProvider = FutureProvider.family<Map<String, int>, String>((ref, calendarUid) async {
  final taskListAsync = ref.watch(taskListProvider);
  return taskListAsync.when(
    data: (tasks) {
      final Map<String, int> categoryCounts = {};
      for (final task in tasks) {
        if (task.status != 'COMPLETED' && task.sourceCalendarUid == calendarUid) {
          for (final category in task.categories) {
            categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
          }
        }
      }
      return categoryCounts;
    },
    loading: () => <String, int>{},
          error: (_, _) => <String, int>{},
  );
});

class PortfolioItemWidget extends ConsumerStatefulWidget {
  final dynamic portfolio;

  const PortfolioItemWidget({
    super.key,
    required this.portfolio,
  });

  @override
  ConsumerState<PortfolioItemWidget> createState() => _PortfolioItemWidgetState();
}

class _PortfolioItemWidgetState extends ConsumerState<PortfolioItemWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = GoRouterState.of(context).uri.path == '/project/${widget.portfolio.uid}';
    final taskCountAsync = ref.watch(portfolioTaskCountProvider(widget.portfolio.uid));
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected 
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            // Main portfolio item
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                // AppLogger.info('PortfolioItem: Navigating to project ${widget.portfolio.uid} (${widget.portfolio.summary})');
                context.go('/project/${widget.portfolio.uid}');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Portfolio name
                    Expanded(
                      child: Text(
                        widget.portfolio.summary,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Task count badge
                    taskCountAsync.when(
                      data: (count) => count > 0 
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.1)
                                    : Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimaryContainer
                                      : Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1),
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    
                    const SizedBox(width: 4),
                    
                    // Expand/collapse arrow
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          _isExpanded 
                              ? Icons.expand_less_rounded 
                              : Icons.expand_more_rounded,
                          size: 18,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Expanded content
            if (_isExpanded) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description section (3-5 lines, weak emphasis)
                      /*if (widget.portfolio.description.isNotEmpty) ...[
                        Text(
                          widget.portfolio.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            height: 1.3,
                          ),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        Text(
                          'No description available for this portfolio.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            fontStyle: FontStyle.italic,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],*/
                      

                      
                      // Categories section
                      _buildCategoriesSection(),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildCategoriesSection() {
    final categoriesAsync = ref.watch(portfolioCategoriesProvider(widget.portfolio.uid));
    final categoryCountsAsync = ref.watch(portfolioCategoryTaskCountProvider(widget.portfolio.uid));
    
    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return categoryCountsAsync.when(
          data: (categoryCounts) => Column(
            children: categories.map((category) {
              final count = categoryCounts[category] ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    // Category name aligned left
                    Expanded(
                      child: Text(
                        category,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    // Count badge aligned right
                    if (count > 0) 
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
          loading: () => const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1),
          ),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 1),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
} 
