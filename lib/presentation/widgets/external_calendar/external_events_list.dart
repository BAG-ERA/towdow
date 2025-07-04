// Widget to display external calendar events in the home view
// Shows VEVENT items filtered by date range for each timeline tab

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/calendar_event.dart';
import '../../../core/logger.dart';

class ExternalEventsList extends StatelessWidget {
  final List<CalendarEvent> events;
  final String emptyMessage;
  
  const ExternalEventsList({
    super.key,
    required this.events,
    this.emptyMessage = 'No events for this period',
  });

  @override
  Widget build(BuildContext context) {
    return _ExternalEventsListContent(events: events);
  }
}

class _ExternalEventsListContent extends StatelessWidget {
  final List<CalendarEvent> events;
  
  const _ExternalEventsListContent({required this.events});

  @override
  Widget build(BuildContext context) {
    // Always show something, even when no events (for testing)
    if (events.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              width: 4,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No calendar events for this period',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
            color: Theme.of(context).dividerColor.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

class _ExternalEventCard extends StatelessWidget {
  final CalendarEvent event;
  
  const _ExternalEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    // Determine if event is all-day
    final isAllDay = event.isAllDay ?? false;
    
    // Format time display
    String timeDisplay = '';
    if (!isAllDay) {
      final startTime = TimeOfDay.fromDateTime(event.dtstart);
      timeDisplay = startTime.format(context);
      
      if (event.dtend != null) {
        final endTime = TimeOfDay.fromDateTime(event.dtend!);
        timeDisplay += ' - ${endTime.format(context)}';
      }
    } else if (isAllDay) {
      timeDisplay = 'All Day';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            width: 4,
            color: _getEventColor(context, event),
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
                
                // TODO: Add calendar name from external calendar repository
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getEventColor(BuildContext context, CalendarEvent event) {
    // TODO: Get calendar color from external calendar repository
    // For now, use primary color
    return Theme.of(context).colorScheme.primary;
  }
} 