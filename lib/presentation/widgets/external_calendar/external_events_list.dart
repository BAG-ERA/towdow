// External events list widget for displaying calendar events from external CalDAV sources
// Shows events in a timeline format with calendar colors and metadata
// Integrated into home screen timeline tabs

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/calendar_event.dart';
import 'external_event_card.dart';

class ExternalEventsList extends ConsumerStatefulWidget {
  final List<CalendarEvent> events;
  final bool startReduced;
  /// When true, only shows first 3 events in reduced mode. When false, shows all events.
  final bool limitReducedEvents;

  const ExternalEventsList({
    super.key,
    required this.events,
    this.startReduced = false,
    this.limitReducedEvents = true,
  });

  @override
  ConsumerState<ExternalEventsList> createState() => _ExternalEventsListState();
}

class _ExternalEventsListState extends ConsumerState<ExternalEventsList> {
  late bool _isReduced;
  
  @override
  void initState() {
    super.initState();
    _isReduced = widget.startReduced;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group events by date for better organization (using local time)
    final eventsByDate = <DateTime, List<CalendarEvent>>{};
    for (final event in widget.events) {
      final eventDate = DateTime(
        event.dtstart.year,
        event.dtstart.month,
        event.dtstart.day,
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
          // Events list with animation
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              offset: _isReduced ? const Offset(0, -0.1) : Offset.zero,
              child: _isReduced 
                ? Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Tooltip(
                          message: 'Show agenda',
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isReduced = false;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.event_rounded,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Agenda',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: 1.0,
                    child: Column(
                      children: [
                        _buildEventsLayout(context),
                        
                        // Divider after events
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          height: 1,
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventsLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024; // Desktop/large tablet
    final isLargeDesktop = screenWidth >= 1400; // Large desktop for 3+ columns
    
    // Sort events by start time (earlier first)
    final sortedEvents = List<CalendarEvent>.from(widget.events)
      ..sort((a, b) => a.dtstart.compareTo(b.dtstart));
    
    // Group events by date
    final groupedEvents = _groupEventsByDate(sortedEvents);
    
    // Create the main content with button
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main events content
        Expanded(
          child: _buildEventsContent(context, groupedEvents, isDesktop, isLargeDesktop),
        ),
        
        // Collapse button column
        Column(
          children: [
            // Collapse/Expand toggle button with animation
            Tooltip(
              message: _isReduced ? 'Expand calendar' : 'Collapse calendar',
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isReduced = !_isReduced;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: !_isReduced 
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: _isReduced ? 0.0 : 0.5,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: !_isReduced 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildEventsContent(BuildContext context, Map<DateTime, List<CalendarEvent>> groupedEvents, bool isDesktop, bool isLargeDesktop) {
    // Determine number of columns based on screen width and day groups
    if (isLargeDesktop && groupedEvents.length >= 3) {
      return _buildMultiColumnDayLayout(context, groupedEvents, 3);
    } else if (isDesktop && groupedEvents.length >= 2) {
      return _buildMultiColumnDayLayout(context, groupedEvents, 2);
    } else {
      return _buildSingleColumnDayLayout(groupedEvents);
    }
  }
  
  Widget _buildSingleColumnDayLayout(Map<DateTime, List<CalendarEvent>> groupedEvents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: groupedEvents.entries.map((entry) {
        final date = entry.key;
        final events = entry.value;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Day header
            Container(
              margin: const EdgeInsets.only(bottom: 8, top: 16),
              child: Text(
                _formatDayHeader(date),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            
            // Events for this day
            ...events.map((event) => ExternalEventCard(
              event: event,
              hideCalendarName: true,
            )),
          ],
        );
      }).toList(),
    );
  }
  
  Widget _buildMultiColumnDayLayout(BuildContext context, Map<DateTime, List<CalendarEvent>> groupedEvents, int columnCount) {
    // Split day groups between columns, distributing evenly
    final dayGroups = groupedEvents.entries.toList();
    final columnGroups = List.generate(columnCount, (index) => <MapEntry<DateTime, List<CalendarEvent>>>[]);
    
    // Distribute day groups across columns
    for (int i = 0; i < dayGroups.length; i++) {
      final columnIndex = i % columnCount;
      columnGroups[columnIndex].add(dayGroups[i]);
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columnGroups.asMap().entries.map((columnEntry) {
        final columnIndex = columnEntry.key;
        final groups = columnEntry.value;
        
        return [
          // Add spacing between columns (except for the first column)
          if (columnIndex > 0) const SizedBox(width: 8),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: groups.map((entry) {
                final date = entry.key;
                final events = entry.value;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Day header
                    Container(
                      margin: const EdgeInsets.only(bottom: 8, top: 16),
                      child: Text(
                        _formatDayHeader(date),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    
                    // Events for this day
                    ...events.map((event) => ExternalEventCard(
                      event: event,
                      hideCalendarName: true,
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ];
      }).expand((widgets) => widgets).toList(),
    );
  }
  
  Map<DateTime, List<CalendarEvent>> _groupEventsByDate(List<CalendarEvent> events) {
    final Map<DateTime, List<CalendarEvent>> groupedEvents = {};
    
    for (final event in events) {
      // Get date without time for grouping
      final eventDate = DateTime(
        event.dtstart.year,
        event.dtstart.month,
        event.dtstart.day,
      );
      
      if (!groupedEvents.containsKey(eventDate)) {
        groupedEvents[eventDate] = [];
      }
      groupedEvents[eventDate]!.add(event);
    }
    
    return groupedEvents;
  }
  
  String _formatDayHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    // Check for Today/Tomorrow
    if (date == today) {
      return 'Today ${_getOrdinalDay(date.day)}';
    } else if (date == tomorrow) {
      return 'Tomorrow ${_getOrdinalDay(date.day)}';
    } else {
      // Format as "Monday 14th"
      const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final dayName = dayNames[date.weekday - 1];
      return '$dayName ${_getOrdinalDay(date.day)}';
    }
  }
  
  String _getOrdinalDay(int day) {
    if (day >= 11 && day <= 13) {
      return '${day}th';
    }
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }
}