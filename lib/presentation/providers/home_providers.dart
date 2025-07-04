// Riverpod providers for Home screen
// Provides simple state management without ViewModel

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/providers.dart';
import '../../data/models/calendar_event.dart';
import '../../core/logger.dart';

/// Provider for current selected tab index
final selectedTabIndexProvider = StateProvider<int>((ref) => 0);

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
    final eventDate = event.localDtstart;
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
      AppLogger.debug('ExternalEvents: Found ${filteredEvents.length} today events');
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
