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

/// Provider for today's external calendar events
final todayExternalEventsProvider = FutureProvider<List<CalendarEvent>>((ref) async {
  AppLogger.info('ExternalEvents: Loading today\'s events...');
  final eventRepository = ref.watch(externalEventRepositoryProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  
  AppLogger.debug('ExternalEvents: Querying events from $startOfDay to $endOfDay');
  final result = await eventRepository.getEventsInRange(startOfDay, endOfDay);
  return result.when(
    success: (events) {
      AppLogger.info('ExternalEvents: Found ${events.length} today events');
      return events;
    },
    failure: (error) {
      AppLogger.warning('ExternalEvents: Failed to load today events: $error');
      return <CalendarEvent>[];
    },
  );
});

/// Provider for soon external calendar events (tomorrow until next Monday)
final soonExternalEventsProvider = FutureProvider<List<CalendarEvent>>((ref) async {
  final eventRepository = ref.watch(externalEventRepositoryProvider);
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  
  // Find next Monday
  final nextMonday = tomorrow.add(Duration(days: (DateTime.monday - tomorrow.weekday) % 7));
  
  final result = await eventRepository.getEventsInRange(tomorrow, nextMonday);
  return result.when(
    success: (events) => events,
    failure: (_) => <CalendarEvent>[],
  );
});

/// Provider for next week external calendar events
final nextWeekExternalEventsProvider = FutureProvider<List<CalendarEvent>>((ref) async {
  final eventRepository = ref.watch(externalEventRepositoryProvider);
  final now = DateTime.now();
  
  // Find next Monday
  final daysUntilNextMonday = (DateTime.monday - now.weekday) % 7;
  final nextMonday = DateTime(now.year, now.month, now.day).add(Duration(days: daysUntilNextMonday));
  final mondayAfterNext = nextMonday.add(const Duration(days: 7));
  
  final result = await eventRepository.getEventsInRange(nextMonday, mondayAfterNext);
  return result.when(
    success: (events) => events,
    failure: (_) => <CalendarEvent>[],
  );
});

/// Provider for later external calendar events (after next week)
final laterExternalEventsProvider = FutureProvider<List<CalendarEvent>>((ref) async {
  final eventRepository = ref.watch(externalEventRepositoryProvider);
  final now = DateTime.now();
  
  // Find Monday after next week
  final daysUntilNextMonday = (DateTime.monday - now.weekday) % 7;
  final nextMonday = DateTime(now.year, now.month, now.day).add(Duration(days: daysUntilNextMonday));
  final mondayAfterNext = nextMonday.add(const Duration(days: 7));
  
  // Get events from Monday after next until far future (1 year)
  final farFuture = mondayAfterNext.add(const Duration(days: 365));
  
  final result = await eventRepository.getEventsInRange(mondayAfterNext, farFuture);
  return result.when(
    success: (events) => events,
    failure: (_) => <CalendarEvent>[],
  );
});

/// Provider for events without specific time constraints (less relevant for external calendars)
final anytimeExternalEventsProvider = FutureProvider<List<CalendarEvent>>((ref) async {
  // External calendar events typically have dates, so this might be empty
  // Or we could show all-day events without end dates
  return <CalendarEvent>[];
});
