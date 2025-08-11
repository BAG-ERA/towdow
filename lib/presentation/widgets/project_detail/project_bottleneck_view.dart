// Bottleneck View: Shows steps as columns with task duration bars

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/providers.dart';
import '../../../data/models/task.dart';
import '../../../data/models/requirement.dart';
import '../../../data/models/step.dart';
import '../../../core/theme/chart_theme.dart';
// Logger not used directly in this widget
import '../../viewmodels/bottleneck_viewmodel.dart';

class ProjectBottleneckView extends ConsumerWidget {
  final String projectPath;
  final List<Task> tasks;
  final VoidCallback? onTasksRefresh;

  const ProjectBottleneckView({
    super.key,
    required this.projectPath,
    required this.tasks,
    this.onTasksRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepsAsync = ref.watch(projectStepsProvider(projectPath));
    final requirementsAsync = ref.watch(projectRequirementsProvider(projectPath));

    if (stepsAsync.isLoading || requirementsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (stepsAsync.hasError) {
      return Center(child: Text('Error loading steps: ${stepsAsync.error}'));
    }
    if (requirementsAsync.hasError) {
      return Center(child: Text('Error loading requirements: ${requirementsAsync.error}'));
    }

    final steps = stepsAsync.asData?.value ?? const [];
    final requirements = requirementsAsync.asData?.value ?? const <Requirement>[];

    final state = BottleneckCalculator.compute(
      steps: steps,
      tasks: tasks,
      requirements: requirements,
    );

    if (state.isEmpty) {
      return Center(
        child: Text(
          'No steps to display',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final colors = context.chartTheme.colors;
    final requirementColor = _RequirementColorPicker(baseColors: [
      colors.primary,
      colors.tertiary,
      colors.warning,
      colors.success,
      colors.error,
      Colors.indigo,
      Colors.teal,
      Colors.pink,
    ]);

    final double maxStepDur = state.maxStepDuration.inMilliseconds == 0
        ? 1.0
        : state.maxStepDuration.inMilliseconds.toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final columnGap = 16.0;

        // Compute proportional widths for each step column
        final widths = <double>[];
        double totalWidth = 0;
        for (final col in state.columns) {
          double proportion;
          if (col.isDisabled) {
            proportion = 0.0;
          } else {
            final raw = col.stepDuration.inMilliseconds.toDouble() / maxStepDur;
            if (raw < 0.05) {
              proportion = 0.05;
            } else if (raw > 1.0) {
              proportion = 1.0;
            } else {
              proportion = raw;
            }
          }
          final candidate = availableWidth * proportion;
          final double w = candidate < 80.0
              ? 80.0
              : (candidate > 400.0 ? 400.0 : candidate);
          widths.add(w);
          totalWidth += w;
        }
        totalWidth += columnGap * (state.columns.length - 1);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: (availableWidth > totalWidth ? availableWidth : totalWidth)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < state.columns.length; i++) ...[
                  _StepColumnWidget(
                    column: state.columns[i],
                    width: widths[i],
                    getRequirementColor: (id) => requirementColor.colorFor(id),
                  ),
                  if (i < state.columns.length - 1) SizedBox(width: columnGap),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StepColumnWidget extends StatelessWidget {
  final BottleneckStepColumn column;
  final double width;
  final Color Function(String? requirementId) getRequirementColor;

  const _StepColumnWidget({
    required this.column,
    required this.width,
    required this.getRequirementColor,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        );

    final headerColor = _statusColor(context, column.step.status);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: headerColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(column.step.name, style: titleStyle)),
                if (column.isDisabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Not available', style: Theme.of(context).textTheme.labelSmall),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: column.isDisabled
                ? _DisabledBody()
                : _BarsList(
                    bars: column.bars,
                    getRequirementColor: getRequirementColor,
                  ),
          )
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context, StepStatus status) {
    final colors = context.chartTheme.colors;
    switch (status) {
      case StepStatus.available:
        return colors.warning;
      case StepStatus.completed:
        return colors.success;
      case StepStatus.waiting:
        return colors.onSurfaceVariant;
      case StepStatus.paused:
        return colors.onSurfaceVariant;
      case StepStatus.aborted:
        return colors.error;
    }
    // Fallback (should be unreachable as switch is exhaustive)
    // But Dart analyzer may still require a return
    // Return onSurfaceVariant by default
    // ignore: dead_code
    return colors.onSurfaceVariant;
  }
}

class _BarsList extends StatelessWidget {
  final List<BottleneckTaskBar> bars;
  final Color Function(String? requirementId) getRequirementColor;

  const _BarsList({required this.bars, required this.getRequirementColor});

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return _EmptyStepBody();
    }

    // Compute max duration to scale bars within the column
    int maxMs = 0;
    for (final b in bars) {
      maxMs = max(maxMs, b.duration.inMilliseconds);
    }
    if (maxMs == 0) maxMs = 1;

    return Column(
      children: [
        for (final bar in bars) ...[
          _TaskBarWidget(
            bar: bar,
            scaleMaxMs: maxMs,
            color: getRequirementColor(bar.firstRequirementId),
          ),
          const SizedBox(height: 8),
        ]
      ],
    );
  }
}

class _TaskBarWidget extends StatelessWidget {
  final BottleneckTaskBar bar;
  final int scaleMaxMs;
  final Color color;

  const _TaskBarWidget({required this.bar, required this.scaleMaxMs, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      final width = max(80.0, maxWidth * (bar.duration.inMilliseconds / scaleMaxMs));

      return Tooltip(
        message: '${bar.title} • ${_formatDuration(bar.duration)}',
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 28,
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.transparent, // no background
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color,
                width: bar.isBottleneck ? 2.0 : 1.0,
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              bar.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      );
    });
  }

  String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${max(1, minutes)}m';
  }
}

class _DisabledBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.pause_circle_filled_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(child: Text('Step disabled (no available time)', style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _EmptyStepBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Text('No tasks in this step', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RequirementColorPicker {
  final List<Color> baseColors;
  final Map<String, Color> _cache = {};

  _RequirementColorPicker({required this.baseColors});

  Color colorFor(String? id) {
    if (id == null || id.isEmpty) return Colors.grey;
    final existing = _cache[id];
    if (existing != null) return existing;
    final idx = id.hashCode.abs() % baseColors.length;
    final color = baseColors[idx];
    _cache[id] = color;
    return color;
  }
}


