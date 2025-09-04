// ViewModel to provide attendee suggestions for task creation dialogs
// Gathers project-level attendees and shared members, with a fallback to
// attendees found in existing tasks from the same project.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger.dart';
import '../../data/models/task_calendar.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/providers/providers_repositories.dart';
import '../../data/models/task.dart';
import '../../core/result.dart';

class AttendeeSuggestionsState {
  final bool isLoading;
  final String? error;
  final List<String> suggestions;

  const AttendeeSuggestionsState({
    this.isLoading = false,
    this.error,
    this.suggestions = const [],
  });

  AttendeeSuggestionsState copyWith({
    bool? isLoading,
    String? error,
    List<String>? suggestions,
  }) {
    return AttendeeSuggestionsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      suggestions: suggestions ?? this.suggestions,
    );
  }
}

class AttendeeSuggestionsViewModel extends StateNotifier<AttendeeSuggestionsState> {
  final CalendarRepository _calendarRepository;
  final TaskRepository _taskRepository;
  final String? _projectPath;
  StreamSubscription<List<Task>>? _tasksSubscription;
  final Set<String> _calendarLevelEmails = <String>{};

  AttendeeSuggestionsViewModel(
    this._calendarRepository,
    this._taskRepository,
    this._projectPath,
  ) : super(const AttendeeSuggestionsState()) {
    // Auto-load when a project path is provided
    if (_projectPath != null && _projectPath.isNotEmpty) {
      // Schedule load after construction
      Future.microtask(() => load());
    }
  }

  Future<void> load() async {
    if (_projectPath == null || _projectPath.isEmpty) {
      state = state.copyWith(isLoading: false, error: null, suggestions: const []);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final encodedPath = _projectPath.replaceAll('@', '%40');
      // Collect emails from calendar first so we can merge with task-derived emails

      // 1) From project (VCALENDAR) level
      final calRes = await _calendarRepository.getByPath(encodedPath);
      await calRes.when(
        success: (calendar) async {
          if (calendar != null) {
            // Project attendees (VCALENDAR)
            _calendarLevelEmails
                .addAll(calendar.attendees
                .map((a) => a.email.trim())
                .where((e) => e.isNotEmpty));

            // Shared members
            _calendarLevelEmails.addAll(calendar.sharedWithEmails);

            // Owner/Author (if email-like)
            final owner = calendar.flowitOwner?.trim();
            if (owner != null && owner.contains('@')) {
              _calendarLevelEmails.add(owner);
            }
            final author = calendar.flowitAuthor?.trim();
            if (author != null && author.contains('@')) {
              _calendarLevelEmails.add(author);
            }
          }
        },
        failure: (failure) async {
          AppLogger.warning('AttendeeSuggestionsVM: Failed to load calendar: ${failure.message}');
        },
      );

      // 2) Always include attendees derived from tasks and keep live-updated
      final tasksRes = await _taskRepository.getByProject(encodedPath);
      final taskEmails = <String>{};
      tasksRes.when(
        success: (tasks) {
          for (final t in tasks) {
            taskEmails.addAll(t.attendees
                .map((a) => a.email.trim())
                .where((e) => e.isNotEmpty));
            final org = t.organizer?.trim();
            if (org != null && org.contains('@')) taskEmails.add(org);
          }
        },
        failure: (failure) {
          AppLogger.warning('AttendeeSuggestionsVM: Failed to load tasks: ${failure.message}');
        },
      );

      // Merge and publish
      final merged = <String>{..._calendarLevelEmails, ...taskEmails}.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      state = state.copyWith(isLoading: false, error: null, suggestions: merged);

      // Set up reactive updates from tasks
      _tasksSubscription?.cancel();
      _tasksSubscription = _taskRepository.watchTasksByProject(_projectPath)
          .listen((tasks) {
        try {
          final liveTaskEmails = <String>{};
          for (final t in tasks) {
            liveTaskEmails.addAll(t.attendees
                .map((a) => a.email.trim())
                .where((e) => e.isNotEmpty));
            final org = t.organizer?.trim();
            if (org != null && org.contains('@')) liveTaskEmails.add(org);
          }
          final union = <String>{..._calendarLevelEmails, ...liveTaskEmails}.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          state = state.copyWith(suggestions: union);
        } catch (e, st) {
          AppLogger.error('AttendeeSuggestionsVM: Error processing tasks stream', e, st);
        }
      });
    } catch (e, st) {
      AppLogger.error('AttendeeSuggestionsVM: Exception while loading suggestions', e, st);
      state = state.copyWith(isLoading: false, error: 'Failed to load suggestions');
    }
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    super.dispose();
  }
}

final attendeeSuggestionsProvider = StateNotifierProvider.family<AttendeeSuggestionsViewModel, AttendeeSuggestionsState, String?>((ref, projectPath) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final taskRepository = ref.watch(taskRepositoryProvider);
  return AttendeeSuggestionsViewModel(calendarRepository, taskRepository, projectPath);
});


