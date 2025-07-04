// External events list widget for displaying calendar events from external CalDAV sources
// Shows events in a timeline format with calendar colors and metadata
// Integrated into home screen timeline tabs

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger.dart';
import '../../../data/models/calendar_event.dart';
import '../../../data/models/external_calendar.dart';
import '../../../data/providers/providers.dart';

class ExternalEventsList extends ConsumerWidget {
  final List<CalendarEvent> events;
  
  const ExternalEventsList({
    super.key,
    required this.events,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group events by date for better organization (using local time)
    final eventsByDate = <DateTime, List<CalendarEvent>>{};
    for (final event in events) {
      final localStart = event.localDtstart;
      final eventDate = DateTime(
        localStart.year,
        localStart.month,
        localStart.day,
      );
      eventsByDate.putIfAbsent(eventDate, () => []).add(event);
    }

    if (eventsByDate.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_rounded,
              color: Theme.of(context).colorScheme.outline,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'No upcoming events',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.event_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Agenda',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${events.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Events list
          ...events.map((event) => _ExternalEventCard(event: event)),
          
          // Divider after events
          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _ExternalEventCard extends ConsumerWidget {
  final CalendarEvent event;
  
  const _ExternalEventCard({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    // Determine if event is all-day
    final isAllDay = event.isAllDay ?? false;
    
    // Format time display using timezone-aware utilities
    String timeDisplay = '';
    if (!isAllDay) {
      // Debug logging to check timezone conversion
      AppLogger.debug('External Event: ${event.summary}');
      AppLogger.debug('  Raw dtstart: ${event.dtstart} (isUtc: ${event.dtstart.isUtc})');
      AppLogger.debug('  Local dtstart: ${event.localDtstart} (isUtc: ${event.localDtstart.isUtc})');
      if (event.dtend != null) {
        AppLogger.debug('  Raw dtend: ${event.dtend} (isUtc: ${event.dtend!.isUtc})');
        AppLogger.debug('  Local dtend: ${event.localDtend} (isUtc: ${event.localDtend?.isUtc})');
      }
      
      final startTime = TimeOfDay.fromDateTime(event.localDtstart);
      timeDisplay = startTime.format(context);
      
      if (event.localDtend != null) {
        final endTime = TimeOfDay.fromDateTime(event.localDtend!);
        timeDisplay += ' - ${endTime.format(context)}';
      }
    } else {
      timeDisplay = 'All Day';
    }

    // Watch external calendars for efficient color lookup
    final calendarsAsync = ref.watch(externalCalendarListProvider);
    
    return calendarsAsync.when(
      loading: () => _buildLoadingSkeleton(colorScheme),
      error: (error, stackTrace) => _buildEventCard(
        context, 
        timeDisplay, 
        colorScheme.primary, 
        textTheme, 
        null,
      ),
      data: (calendars) {
        final calendar = calendars.where((c) => c.uid == event.sourceCalendarUid).firstOrNull;
        final eventColor = calendar?.color != null 
            ? Color(int.parse(calendar!.color!.replaceFirst('#', '0xFF')))
            : colorScheme.primary;
        
        return _buildEventCard(
          context, 
          timeDisplay, 
          eventColor, 
          textTheme, 
          calendar,
        );
      },
    );
  }
  
  Widget _buildLoadingSkeleton(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            width: 4,
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column skeleton
          SizedBox(
            width: 60,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Event content skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 12,
                  width: 150,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventCard(
    BuildContext context,
    String timeDisplay,
    Color eventColor,
    TextTheme textTheme,
    ExternalCalendar? calendar,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            width: 4,
            color: eventColor,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (timeDisplay.isNotEmpty)
                  Text(
                    timeDisplay,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Event content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event title
                Text(
                  event.summary?.isNotEmpty == true ? event.summary! : 'Untitled Event',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                // Location
                if (event.location?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                
                // Calendar name with color indicator
                if (calendar != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: eventColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          calendar.displayName,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
} 