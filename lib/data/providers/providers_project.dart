// Project/task providers with derived state

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logger.dart';
import '../models/task.dart';
import '../models/task_calendar.dart';
import '../models/step.dart';
import '../models/requirement.dart';
import 'providers_repositories.dart';
import '../models/category.dart';

final taskListProvider = StreamProvider<List<Task>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.watchTasks();
});

final calendarListProvider = StreamProvider<List<TaskCalendar>>((ref) {
  final repository = ref.watch(calendarRepositoryProvider);
  return repository.watchCalendars().asyncMap((_) async {
    final result = await repository.getProjectCalendars();
    return result.when(
      success: (calendars) => calendars,
      failure: (failure) => throw Exception(failure.message),
    );
  });
});

final activeCalendarListProvider = StreamProvider<List<TaskCalendar>>((ref) {
  final repository = ref.watch(calendarRepositoryProvider);
  return repository.watchCalendars().asyncMap((watchedCalendars) async {
    final result = await repository.getProjectCalendars();
    return result.when(
      success: (calendars) {
        final activeCalendars = calendars.where((calendar) => !calendar.isArchived).toList();
        final seen = <String>{};
        final deduped = <TaskCalendar>[];
        for (final cal in activeCalendars) {
          if (!seen.contains(cal.uid)) {
            seen.add(cal.uid);
            deduped.add(cal);
          } else {
            AppLogger.debug('CalendarListProvider: Filtered duplicate calendar with UID: ${cal.uid}');
          }
        }
        return deduped;
      },
      failure: (failure) => throw Exception(failure.message),
    );
  });
});

final projectTasksProvider = StreamProvider.family<List<Task>, String>((ref, projectPath) {
  final taskRepository = ref.read(taskRepositoryProvider);
  final categoryRepository = ref.read(categoryRepositoryProvider);
  final encodedProjectPath = projectPath.replaceAll('@', '%40');
  return taskRepository.watchTasksByProject(projectPath).asyncMap((projectTasks) async {
    final projectCategoriesResult = await categoryRepository.getProjectCategories(encodedProjectPath);
    final projectCategories = await projectCategoriesResult.when(
      success: (categories) async => categories,
      failure: (_) async => <Category>[],
    );
    final validCategoryIds = projectCategories.map((cat) => cat.id).toSet();
    final filteredTasks = projectTasks.map((task) {
      final validIds = task.categoryIds.where(validCategoryIds.contains).toList();
      if (validIds.length != task.categoryIds.length) {
        return task.copyWith(categoryIds: validIds);
      }
      return task;
    }).toList();
    return filteredTasks;
  });
});

// Selected state for project/task in UI
final selectedProjectProvider = StateProvider<String?>((ref) => null);
final selectedTaskProvider = StateProvider<String?>((ref) => null);

// Alias for navbar consumption
final projectListProvider = activeCalendarListProvider;

// Helper function to find next Monday at 00:00
DateTime _getNextMondayMidnight(DateTime from) {
  final currentWeekday = from.weekday; // 1=Mon .. 7=Sun
  final daysUntilNextMonday = currentWeekday == DateTime.monday
      ? 7
      : (DateTime.monday + 7 - currentWeekday) % 7;
  final nextMonday = from.add(Duration(days: daysUntilNextMonday));
  return DateTime(nextMonday.year, nextMonday.month, nextMonday.day);
}

DateTime _getTodayMidnight(DateTime from) => DateTime(from.year, from.month, from.day);

// Time-bucketed task providers
final todayTasksProvider = StreamProvider<List<Task>>((ref) {
  final tasksStream = ref.watch(taskListProvider.stream);
  return tasksStream.map((tasks) {
    final todayMidnight = _getTodayMidnight(DateTime.now());
    final tomorrowMidnight = todayMidnight.add(const Duration(days: 1));
    return tasks.where((t) => t.status != 'COMPLETED' && t.due != null && t.due!.isBefore(tomorrowMidnight)).toList();
  });
});

final soonTasksProvider = StreamProvider<List<Task>>((ref) {
  final tasksStream = ref.watch(taskListProvider.stream);
  return tasksStream.map((tasks) {
    final now = DateTime.now();
    final tomorrowMidnight = _getTodayMidnight(now).add(const Duration(days: 1));
    final nextMondayMidnight = _getNextMondayMidnight(now);
    return tasks.where((t) => t.status != 'COMPLETED' && t.due != null && !t.due!.isBefore(tomorrowMidnight) && t.due!.isBefore(nextMondayMidnight)).toList();
  });
});

final nextWeekTasksProvider = StreamProvider<List<Task>>((ref) {
  final tasksStream = ref.watch(taskListProvider.stream);
  return tasksStream.map((tasks) {
    final nextMondayMidnight = _getNextMondayMidnight(DateTime.now());
    final mondayAfterNextMidnight = nextMondayMidnight.add(const Duration(days: 7));
    return tasks.where((t) => t.status != 'COMPLETED' && t.due != null && !t.due!.isBefore(nextMondayMidnight) && t.due!.isBefore(mondayAfterNextMidnight)).toList();
  });
});

final laterTasksProvider = StreamProvider<List<Task>>((ref) {
  final tasksStream = ref.watch(taskListProvider.stream);
  return tasksStream.map((tasks) {
    final nextMondayMidnight = _getNextMondayMidnight(DateTime.now());
    final mondayAfterNextMidnight = nextMondayMidnight.add(const Duration(days: 7));
    return tasks.where((t) => t.status != 'COMPLETED' && t.due != null && !t.due!.isBefore(mondayAfterNextMidnight)).toList();
  });
});

final anytimeTasksProvider = StreamProvider<List<Task>>((ref) {
  final tasksStream = ref.watch(taskListProvider.stream);
  return tasksStream.map((tasks) => tasks.where((t) => t.status != 'COMPLETED' && t.due == null).toList());
});

// Project requirements provider
final projectRequirementsProvider = StreamProvider.family<List<Requirement>, String>((ref, projectPath) async* {
  final requirementRepository = ref.watch(requirementRepositoryProvider);
  final encoded = projectPath.replaceAll('@', '%40');
  final initial = await requirementRepository.getProjectRequirements(encoded);
  yield initial.when(success: (reqs) => reqs, failure: (_) => <Requirement>[]);
  await for (final _ in ref.watch(calendarListProvider.stream)) {
    final res = await requirementRepository.getProjectRequirements(encoded);
    yield res.when(success: (reqs) => reqs, failure: (_) => <Requirement>[]);
  }
});

// Steps provider per project
final projectStepsProvider = StreamProvider.family<List<ProjectStep>, String>((ref, projectPath) async* {
  final stepRepository = ref.watch(stepRepositoryProvider);
  final encoded = projectPath.replaceAll('@', '%40');
  final initialResult = await stepRepository.getProjectSteps(encoded);
  final initial = await initialResult.when(
    success: (s) async {
      if (s.isNotEmpty) return s;
      await stepRepository.ensureDefaultStep(encoded);
      final second = await stepRepository.getProjectSteps(encoded);
      return second.when(success: (v) => v, failure: (_) => <ProjectStep>[]);
    },
    failure: (_) async => <ProjectStep>[],
  );
  yield initial;
  await for (final _ in ref.watch(calendarListProvider.stream)) {
    final calendars = await ref.watch(calendarRepositoryProvider).getAll().then((r) => r.when(success: (c) => c, failure: (_) => <TaskCalendar>[]));
    await stepRepository.refreshIfChanged(calendars);
    final result = await stepRepository.getProjectSteps(encoded);
    final steps = await result.when(success: (s) async => s, failure: (_) async => <ProjectStep>[]);
    yield steps;
  }
});

// Project task search
final projectSearchQueryProvider = StateProvider.family<String, String>((ref, projectPath) => '');

// Reactive task provider that watches individual tasks by UID
final taskProvider = StreamProvider.family<Task?, String>((ref, taskUid) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  return taskRepository.watchTasks().map((tasks) {
    try {
      return tasks.firstWhere((task) => task.uid == taskUid);
    } catch (e) {
      return null;
    }
  });
});

final filteredProjectTasksProvider = Provider.family<List<Task>, String>((ref, projectPath) {
  final projectTasksAsync = ref.watch(projectTasksProvider(projectPath));
  final searchQuery = ref.watch(projectSearchQueryProvider(projectPath));
  final allTasks = projectTasksAsync.maybeWhen(data: (tasks) => tasks, orElse: () => <Task>[]);
  if (searchQuery.trim().isEmpty) return allTasks;
  final q = searchQuery.toLowerCase();
  return allTasks.where((t) {
    return t.summary.toLowerCase().contains(q) ||
        t.description.toLowerCase().contains(q) ||
        t.categoryIds.any((id) => id.toLowerCase().contains(q));
  }).toList();
});

