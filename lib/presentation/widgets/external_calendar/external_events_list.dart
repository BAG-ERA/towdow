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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final screenHeight = MediaQuery.of(context).size.height;
                        final isMobile = MediaQuery.of(context).size.width < 600;
                        
                        // On mobile, limit external calendar height to 30% of screen
                        final maxHeight = isMobile ? screenHeight * 0.3 : double.infinity;
                        
                        final content = Column(
                          children: [
                            _buildEventsLayout(context),
                            
                            // Divider after events
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              height: 1,
                              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                            ),
                          ],
                        );
                        
                        if (isMobile) {
                          return ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: maxHeight,
                            ),
                            child: SingleChildScrollView(
                              child: content,
                            ),
                          );
                        } else {
                          return content;
                        }
                      },
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventsLayout(BuildContext context) {
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
          child: _buildResponsiveGridLayout(context, groupedEvents),
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
  
  Widget _buildResponsiveGridLayout(BuildContext context, Map<DateTime, List<CalendarEvent>> groupedEvents) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate optimal number of columns based on available width
        final availableWidth = constraints.maxWidth;
        final minColumnWidth = 240.0; // Minimum width for a day column (reduced for more flexibility)
        final columnSpacing = 16.0; // Spacing between columns
        
        // Calculate how many columns can fit
        int maxColumns = (availableWidth / (minColumnWidth + columnSpacing)).floor();
        maxColumns = maxColumns.clamp(1, 8); // Allow up to 8 columns for very wide screens
        
        // If we have fewer day groups than max columns, use the number of day groups
        final dayGroups = groupedEvents.entries.toList();
        final columnCount = dayGroups.length < maxColumns ? dayGroups.length : maxColumns;
        
        if (columnCount == 1) {
          return _buildSingleColumnLayout(groupedEvents);
        } else {
          return _buildMultiColumnLayout(context, groupedEvents, columnCount);
        }
      },
    );
  }
  
  Widget _buildSingleColumnLayout(Map<DateTime, List<CalendarEvent>> groupedEvents) {
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
            ...events.asMap().entries.map((entry) {
              final index = entry.key;
              final event = entry.value;
              final isFirst = index == 0;
              final isLast = index == events.length - 1;
              
              BorderRadius? borderRadius;
              if (isFirst && isLast) {
                // Single event - all corners rounded
                borderRadius = BorderRadius.circular(8);
              } else if (isFirst) {
                // First event - top corners only
                borderRadius = const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                );
              } else if (isLast) {
                // Last event - bottom corners only
                borderRadius = const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                );
              } else {
                borderRadius = BorderRadius.zero;
              }
              // Middle events - no corners (default)
              
              return ExternalEventCard(
                event: event,
                hideCalendarName: true,
                borderRadius: borderRadius,
              );
            }),
          ],
        );
      }).toList(),
    );
  }
  
  Widget _buildMultiColumnLayout(BuildContext context, Map<DateTime, List<CalendarEvent>> groupedEvents, int maxColumnCount) {
    // Start with one column per day
    final dayGroups = groupedEvents.entries.toList();
    final currentColumnCount = dayGroups.length;
    
    // Calculate estimated heights for each day group
    final dayGroupHeights = <MapEntry<DateTime, List<CalendarEvent>>, double>{};
    for (final entry in dayGroups) {
      final events = entry.value;
      // Estimate height: header (40) + events (80 each) + margins
      final estimatedHeight = 40.0 + (events.length * 80.0) + 16.0;
      dayGroupHeights[entry] = estimatedHeight;
    }
    
    // If current column count <= max column count, use one column per day
    if (currentColumnCount <= maxColumnCount) {
      final columnGroups = List.generate(currentColumnCount, (index) => <MapEntry<DateTime, List<CalendarEvent>>>[]);
      for (int i = 0; i < dayGroups.length; i++) {
        columnGroups[i].add(dayGroups[i]);
      }
      return _buildColumnLayout(context, columnGroups);
    }
    
    // Otherwise, we need to combine columns
    var columnGroups = <List<MapEntry<DateTime, List<CalendarEvent>>>>[];
    var columnHeights = <double>[];
    
    // Initialize: one day per column
    for (int i = 0; i < dayGroups.length; i++) {
      columnGroups.add([dayGroups[i]]);
      columnHeights.add(dayGroupHeights[dayGroups[i]]!);
    }
    
    // Combine columns until we reach the target count
    while (columnGroups.length > maxColumnCount) {
      // Find the two adjacent columns with smallest combined height
      int bestIndex = 0;
      double bestCombinedHeight = columnHeights[0] + columnHeights[1];
      
      for (int i = 0; i < columnGroups.length - 1; i++) {
        final combinedHeight = columnHeights[i] + columnHeights[i + 1];
        if (combinedHeight < bestCombinedHeight) {
          bestCombinedHeight = combinedHeight;
          bestIndex = i;
        }
      }
      
      // Combine the two columns
      columnGroups[bestIndex].addAll(columnGroups[bestIndex + 1]);
      columnHeights[bestIndex] = bestCombinedHeight;
      
      // Remove the second column
      columnGroups.removeAt(bestIndex + 1);
      columnHeights.removeAt(bestIndex + 1);
    }
    
    return _buildColumnLayout(context, columnGroups);
  }
  
  Widget _buildColumnLayout(BuildContext context, List<List<MapEntry<DateTime, List<CalendarEvent>>>> columnGroups) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columnGroups.asMap().entries.map((columnEntry) {
        final columnIndex = columnEntry.key;
        final groups = columnEntry.value;
        
        return [
          // Add spacing between columns (except for the first column)
          if (columnIndex > 0) const SizedBox(width: 16),
          
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
                    ...events.asMap().entries.map((entry) {
                      final index = entry.key;
                      final event = entry.value;
                      final isFirst = index == 0;
                      final isLast = index == events.length - 1;
                      
                      BorderRadius? borderRadius;
                      if (isFirst && isLast) {
                        // Single event - all corners rounded
                        borderRadius = BorderRadius.circular(8);
                      } else if (isFirst) {
                        // First event - top corners only
                        borderRadius = const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        );
                      } else if (isLast) {
                        // Last event - bottom corners only
                        borderRadius = const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        );
                      } else {
                        borderRadius = BorderRadius.zero;
                      }
                      
                      return ExternalEventCard(
                        event: event,
                        hideCalendarName: true,
                        borderRadius: borderRadius,
                      );
                    }),
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