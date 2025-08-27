// External event card widget for displaying individual calendar events
// Shows event details with calendar colors, time, location, and metadata
// Used in external events list and other calendar displays

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger.dart';
import '../../../data/models/calendar_event.dart';
import '../../../data/models/external_calendar.dart';
import '../../../data/providers/providers.dart';
import '../utils/popup/external_event_details_dialog.dart';

class ExternalEventCard extends ConsumerWidget {
  final CalendarEvent event;
  final bool hideCalendarName;
  final bool isReduced;
  final BorderRadius? borderRadius;
  
  const ExternalEventCard({
    super.key,
    required this.event,
    this.hideCalendarName = false,
    this.isReduced = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    // Determine if event is all-day
    final isAllDay = event.isAllDay;
    
    // Format time display using timezone-aware utilities
    String timeDisplay = '';
    if (!isAllDay) {
      // Debug logging to check time display
      AppLogger.debug('External Event: ${event.summary}');
      AppLogger.debug('  dtstart: ${event.dtstart}');
      if (event.dtend != null) {
        AppLogger.debug('  dtend: ${event.dtend}');
      }
      
      final startTime = TimeOfDay.fromDateTime(event.dtstart);
      timeDisplay = startTime.format(context);
      
      if (event.dtend != null) {
        final endTime = TimeOfDay.fromDateTime(event.dtend!);
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Container(
        padding: EdgeInsets.all(hideCalendarName ? 8 : 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
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
              width: 50,
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
    
    if (isReduced) {
      return _buildReducedEventCard(
        context,
        timeDisplay,
        eventColor,
        textTheme,
        colorScheme,
      );
    }
    
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => ExternalEventDetailsDialog.show(context, event: event),
            child: Container(
            padding: EdgeInsets.all(hideCalendarName ? 8 : 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: borderRadius ?? BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time column
                SizedBox(
                  width: 80,
                  child: Text(
                    timeDisplay,
                    style: textTheme.bodySmall?.copyWith(
                      color: eventColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Event content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event title and location icon on same line
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.summary.isNotEmpty == true ? event.summary : 'Untitled Event',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (event.location?.isNotEmpty == true)
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                      
                      // Calendar name with color indicator
                      if (calendar != null && !hideCalendarName) ...[
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
          ),
        ),
      ),
    );
  }

  Widget _buildReducedEventCard(
    BuildContext context,
    String timeDisplay,
    Color eventColor,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: GestureDetector(
        onTap: () => ExternalEventDetailsDialog.show(context, event: event),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: borderRadius ?? BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Time column (no day context)
              if (timeDisplay.isNotEmpty)
                SizedBox(
                  width: 80,
                  child: Text(
                    timeDisplay,
                    style: textTheme.bodySmall?.copyWith(
                      color: eventColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              
              SizedBox(width: timeDisplay.isNotEmpty ? 8 : 0),
              
              // Event content
              Expanded(
                child: Text(
                  event.summary.isNotEmpty == true ? event.summary : 'Untitled Event',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 