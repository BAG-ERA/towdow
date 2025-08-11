// Bottleneck computed view state and calculator
// Produces per-step columns and per-task bars with duration-based sizing

import 'dart:convert';

// No Flutter UI imports here; this is a pure calculator

import '../../data/models/step.dart';
import '../../data/models/task.dart';
import '../../data/models/requirement.dart';
import '../../core/logger.dart';

class BottleneckTaskBar {
  final String taskUid;
  final String title;
  final Duration duration;
  final bool isCompleted;
  final bool isBottleneck;
  final String? firstRequirementId;

  const BottleneckTaskBar({
    required this.taskUid,
    required this.title,
    required this.duration,
    required this.isCompleted,
    required this.isBottleneck,
    required this.firstRequirementId,
  });
}

class BottleneckStepColumn {
  final ProjectStep step;
  final bool isDisabled; // true when availableDate is null
  final Duration stepDuration; // completionOrNow - availableDate (>= 0)
  final List<BottleneckTaskBar> bars;

  const BottleneckStepColumn({
    required this.step,
    required this.isDisabled,
    required this.stepDuration,
    required this.bars,
  });
}

class BottleneckState {
  final List<BottleneckStepColumn> columns; // ordered by step.order
  final Duration maxStepDuration; // max across columns

  const BottleneckState({
    required this.columns,
    required this.maxStepDuration,
  });

  bool get isEmpty => columns.isEmpty;
}

class BottleneckCalculator {
  static BottleneckState compute({
    required List<ProjectStep> steps,
    required List<Task> tasks,
    required List<Requirement> requirements,
    DateTime? now,
  }) {
    final DateTime current = now ?? DateTime.now();

    // Index tasks by stepId
    final Map<String, List<Task>> tasksByStep = {};
    for (final task in tasks) {
      final sid = task.stepId;
      if (sid == null || sid.isEmpty) continue; // per user, ignore
      (tasksByStep[sid] ??= <Task>[]).add(task);
    }

    // Build columns
    final List<BottleneckStepColumn> columns = [];
    for (final step in [...steps]..sort((a, b) => a.order.compareTo(b.order))) {
      final available = step.availableDate;
      if (available == null) {
        columns.add(BottleneckStepColumn(
          step: step,
          isDisabled: true,
          stepDuration: Duration.zero,
          bars: const [],
        ));
        continue;
      }

      final stepEnd = step.completionDate ?? current;
      final stepDuration = _safeNonNegative(stepEnd.difference(available));

      // Build bars for tasks in this step
      final stepTasks = tasksByStep[step.id] ?? const <Task>[];
      final List<_TaskWithDuration> computed = [];
      for (final t in stepTasks) {
        final start = t.created.isAfter(available) ? t.created : available;
        DateTime end;
        if (t.status == 'COMPLETED') {
          // Use lastModified for now; clamp to step bounds later
          end = t.lastModified;
        } else {
          end = current;
        }
        // Clamp to [available, step.completionDate]
        if (end.isBefore(available)) {
          // inconsistent → clamp and warn once
          AppLogger.warning('Bottleneck: Task ${t.uid} end before step available; clamping');
          end = available;
        }
        if (step.completionDate != null && end.isAfter(step.completionDate!)) {
          end = step.completionDate!;
        }
        final duration = _safeNonNegative(end.difference(start));
        computed.add(_TaskWithDuration(task: t, duration: duration));
      }

      // Identify bottleneck (max duration)
      Duration maxDur = Duration.zero;
      for (final c in computed) {
        if (c.duration > maxDur) maxDur = c.duration;
      }

      final bars = computed.map((c) {
        final firstReqId = _firstRequirementId(c.task.flowitRequirement);
        return BottleneckTaskBar(
          taskUid: c.task.uid,
          title: c.task.summary,
          duration: c.duration,
          isCompleted: c.task.status == 'COMPLETED',
          isBottleneck: c.duration == maxDur && maxDur > Duration.zero,
          firstRequirementId: firstReqId,
        );
      }).toList();

      columns.add(BottleneckStepColumn(
        step: step,
        isDisabled: false,
        stepDuration: stepDuration,
        bars: bars,
      ));
    }

    // Compute max step duration across columns
    Duration maxStepDur = Duration.zero;
    for (final col in columns) {
      if (col.stepDuration > maxStepDur) maxStepDur = col.stepDuration;
    }

    return BottleneckState(columns: columns, maxStepDuration: maxStepDur);
  }

  static Duration _safeNonNegative(Duration d) {
    if (d.isNegative) return Duration.zero;
    return d;
  }

  static String? _firstRequirementId(String requirementJson) {
    try {
      // Expecting JSON array string: ["id1", "id2"]
      final dynamic decoded = _tryDecodeJson(requirementJson);
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is String && first.isNotEmpty) return first;
      }
      // Legacy forms handled as empty
      return null;
    } catch (_) {
      return null;
    }
  }

  static dynamic _tryDecodeJson(String json) {
    try {
      return json.isEmpty ? [] : (jsonDecode(json));
    } catch (_) {
      // If it was an object like {}, treat as empty list
      return [];
    }
  }
}

class _TaskWithDuration {
  final Task task;
  final Duration duration;
  const _TaskWithDuration({required this.task, required this.duration});
}


