// Riverpod providers for Home screen
// Provides simple state management without ViewModel

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/providers.dart';
import '../../data/models/calendar_event.dart';

/// Provider for current selected tab index
final selectedTabIndexProvider = StateProvider<int>((ref) => 0);

/// Guards applying the initial tab selection once per route (keyed by initialTab)
final initialTabAppliedProvider = StateProvider.autoDispose.family<bool, int>((ref, initialTab) => false);

/// Provider for checking if any commands are executing  
final isAnyCommandExecutingProvider = Provider<bool>((ref) {
  // Pour l'instant, retourne false
  // On peut ajouter la logique des commands plus tard si nécessaire
  return false;
});

// External calendar event providers filtered by date range
// These are now stream-based to automatically react to repository changes

/// Helper function to filter events by date range
List<CalendarEvent> _filterEventsByDateRange(List<CalendarEvent> events, DateTime start, DateTime end) {
  return events.where((event) {
    final eventDate = event.dtstart;
    return eventDate.isAfter(start.subtract(const Duration(milliseconds: 1))) && 
           eventDate.isBefore(end);
  }).toList();
}

/// Provider for today's external calendar events
final todayExternalEventsProvider = Provider<AsyncValue<List<CalendarEvent>>>((ref) {
  final eventsAsync = ref.watch(enabledExternalEventListProvider);
  
  return eventsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
    data: (events) {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final filteredEvents = _filterEventsByDateRange(events, startOfDay, endOfDay);
      return AsyncValue.data(filteredEvents);
    },
  );
});

/// Provider for soon external calendar events (tomorrow until next Monday)
final soonExternalEventsProvider = Provider<AsyncValue<List<CalendarEvent>>>((ref) {
  final eventsAsync = ref.watch(enabledExternalEventListProvider);
  
  return eventsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
    data: (events) {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      
      // Find next Monday
      final daysUntilNextMonday = (DateTime.monday + 7 - tomorrow.weekday) % 7;
      final nextMonday = tomorrow.add(Duration(days: daysUntilNextMonday == 0 ? 7 : daysUntilNextMonday));
      
      final filteredEvents = _filterEventsByDateRange(events, tomorrow, nextMonday);
      return AsyncValue.data(filteredEvents);
    },
  );
});

/// Provider for next week external calendar events
final nextWeekExternalEventsProvider = Provider<AsyncValue<List<CalendarEvent>>>((ref) {
  final eventsAsync = ref.watch(enabledExternalEventListProvider);
  
  return eventsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
    data: (events) {
      final now = DateTime.now();
      
      // Find next Monday
      final daysUntilNextMonday = (DateTime.monday + 7 - now.weekday) % 7;
      final nextMonday = DateTime(now.year, now.month, now.day).add(Duration(days: daysUntilNextMonday == 0 ? 7 : daysUntilNextMonday));
      final mondayAfterNext = nextMonday.add(const Duration(days: 7));
      
      final filteredEvents = _filterEventsByDateRange(events, nextMonday, mondayAfterNext);
      return AsyncValue.data(filteredEvents);
    },
  );
});

/// Provider for later external calendar events (after next week)
final laterExternalEventsProvider = Provider<AsyncValue<List<CalendarEvent>>>((ref) {
  final eventsAsync = ref.watch(enabledExternalEventListProvider);
  
  return eventsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
    data: (events) {
      final now = DateTime.now();
      
      // Find Monday after next week
      final daysUntilNextMonday = (DateTime.monday + 7 - now.weekday) % 7;
      final nextMonday = DateTime(now.year, now.month, now.day).add(Duration(days: daysUntilNextMonday == 0 ? 7 : daysUntilNextMonday));
      final mondayAfterNext = nextMonday.add(const Duration(days: 7));
      
      // Get events from Monday after next until far future (1 year)
      final farFuture = mondayAfterNext.add(const Duration(days: 365));
      
      final filteredEvents = _filterEventsByDateRange(events, mondayAfterNext, farFuture);
      return AsyncValue.data(filteredEvents);
    },
  );
});

/// Provider for events without specific time constraints (less relevant for external calendars)
final anytimeExternalEventsProvider = Provider<AsyncValue<List<CalendarEvent>>>((ref) {
  // External calendar events typically have dates, so this returns empty
  // Could be extended to show all-day events without end dates if needed
  return const AsyncValue.data(<CalendarEvent>[]);
});

/// Suggests the first non-empty tab index for the task views, starting from [initialIndex].
/// Order is: Today (0), Soon (1), Next Week (2), Later (3), Anytime (4).
/// If all tabs are empty, falls back to Today (0).
final suggestedTabIndexProvider = Provider.family<AsyncValue<int>, int>((ref, initialIndex) {
  final today = ref.watch(todayTasksProvider);
  final soon = ref.watch(soonTasksProvider);
  final nextWeek = ref.watch(nextWeekTasksProvider);
  final later = ref.watch(laterTasksProvider);
  final anytime = ref.watch(anytimeTasksProvider);

  final list = [today, soon, nextWeek, later, anytime];

  // If any are loading, defer suggestion until all have resolved to avoid flicker
  if (list.any((a) => a.isLoading)) {
    return const AsyncValue.loading();
  }

  // On error, be conservative and keep Today
  if (list.any((a) => a.hasError)) {
    return const AsyncValue.data(0);
  }

  final counts = <int>[
    today.value?.length ?? 0,
    soon.value?.length ?? 0,
    nextWeek.value?.length ?? 0,
    later.value?.length ?? 0,
    anytime.value?.length ?? 0,
  ];

  // Scan from the provided initial index forward
  for (int i = initialIndex; i < counts.length; i++) {
    if (counts[i] > 0) {
      return AsyncValue.data(i);
    }
  }

  // If none from initial onward, and all are empty, return Today
  return const AsyncValue.data(0);
});
