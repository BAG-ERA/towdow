// External event details dialog widget
// Displays comprehensive event information in a popup dialog
// Shows all available event data including time, location, attendees, and metadata

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/models/calendar_event.dart';
import '../../../../data/models/external_calendar.dart';
import '../../../../data/providers/providers.dart';

class ExternalEventDetailsDialog extends ConsumerWidget {
  final CalendarEvent event;

  const ExternalEventDetailsDialog({
    super.key,
    required this.event,
  });

  /// Shows the external event details dialog
  static Future<void> show(
    BuildContext context, {
    required CalendarEvent event,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => ExternalEventDetailsDialog(event: event),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    // Watch external calendars for calendar information
    final calendarsAsync = ref.watch(externalCalendarListProvider);
    
    return calendarsAsync.when(
      loading: () => _buildLoadingDialog(context, colorScheme, textTheme),
      error: (error, stackTrace) => _buildEventDialog(
        context, 
        colorScheme, 
        textTheme, 
        null,
      ),
      data: (calendars) {
        final calendar = calendars.where((c) => c.uid == event.sourceCalendarUid).firstOrNull;
        return _buildEventDialog(context, colorScheme, textTheme, calendar);
      },
    );
  }

  Widget _buildLoadingDialog(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return AlertDialog(
      title: const Text('Event Details'),
      content: const SizedBox(
        width: 500,
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildEventDialog(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    ExternalCalendar? calendar,
  ) {
    final eventColor = calendar?.color != null 
        ? Color(int.parse(calendar!.color!.replaceFirst('#', '0xFF')))
        : colorScheme.primary;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: eventColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              event.summary.isNotEmpty ? event.summary : 'Untitled Event',
              style: textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Time and Date Section
              _buildTimeSection(context, colorScheme, textTheme),
              
              const SizedBox(height: 16),
              
              // Location Section
              if (event.location?.isNotEmpty == true) ...[
                _buildLocationSection(context, colorScheme, textTheme),
                const SizedBox(height: 16),
              ],
              
              // Description Section
              if (event.description.isNotEmpty) ...[
                _buildDescriptionSection(context, colorScheme, textTheme),
                const SizedBox(height: 16),
              ],
              
              // Attendees Section
              if (event.attendees.isNotEmpty) ...[
                _buildAttendeesSection(context, colorScheme, textTheme),
                const SizedBox(height: 16),
              ],
              
              // Organizer Section
              if (event.organizer?.isNotEmpty == true) ...[
                _buildOrganizerSection(context, colorScheme, textTheme),
                const SizedBox(height: 16),
              ],
              
              // Categories Section
              if (event.categories.isNotEmpty) ...[
                _buildCategoriesSection(context, colorScheme, textTheme),
                const SizedBox(height: 16),
              ],
              
              // Calendar Information
              if (calendar != null) ...[
                _buildCalendarSection(context, colorScheme, textTheme, calendar),
                const SizedBox(height: 16),
              ],
              
              // Event Metadata
              _buildMetadataSection(context, colorScheme, textTheme),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildTimeSection(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    final isAllDay = event.isAllDay ?? false;
    final dateFormat = DateFormat('EEEE, MMMM d, y');
    final timeFormat = DateFormat('h:mm a');
    
    String timeDisplay = '';
    if (!isAllDay) {
      final startTime = timeFormat.format(event.dtstart);
      timeDisplay = startTime;
      
      if (event.dtend != null) {
        final endTime = timeFormat.format(event.dtend!);
        timeDisplay += ' - $endTime';
      }
    } else {
      timeDisplay = 'All Day';
    }

    return _buildSection(
      context,
      colorScheme,
      textTheme,
      'Time & Date',
      Icons.schedule,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateFormat.format(event.dtstart),
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeDisplay,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (event.effectiveDuration != null && !isAllDay) ...[
            const SizedBox(height: 4),
            Text(
              'Duration: ${event.durationString}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return _buildSection(
      context,
      colorScheme,
      textTheme,
      'Location',
      Icons.location_on_outlined,
      Text(
        event.location!,
        style: textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return _buildSection(
      context,
      colorScheme,
      textTheme,
      'Description',
      Icons.description_outlined,
      Text(
        event.description,
        style: textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildAttendeesSection(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return _buildSection(
      context,
      colorScheme,
      textTheme,
      'Attendees',
      Icons.people_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: event.attendees.map((attendee) {
          final isOrganizer = attendee.email == event.organizer;
          final status = attendee.status.value;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  _getAttendeeIcon(status),
                  size: 16,
                  color: _getAttendeeColor(status, colorScheme),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attendee.displayName ?? attendee.email,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: isOrganizer ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      if (attendee.email != attendee.displayName) ...[
                        Text(
                          attendee.email,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getAttendeeColor(status, colorScheme).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: textTheme.bodySmall?.copyWith(
                      color: _getAttendeeColor(status, colorScheme),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrganizerSection(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return _buildSection(
      context,
      colorScheme,
      textTheme,
      'Organizer',
      Icons.person_outlined,
      Text(
        event.organizer!,
        style: textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildCategoriesSection(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return _buildSection(
      context,
      colorScheme,
      textTheme,
      'Categories',
      Icons.label_outlined,
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: event.categories.map((category) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              category,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarSection(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    ExternalCalendar calendar,
  ) {
    return _buildSection(
      context,
      colorScheme,
      textTheme,
      'Calendar',
      Icons.calendar_today_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            calendar.displayName,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (calendar.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              calendar.description,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataSection(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    final metadata = <Widget>[];
    
    // Status
    if (event.status != 'CONFIRMED') {
      metadata.add(_buildMetadataItem(
        context,
        colorScheme,
        textTheme,
        'Status',
        event.status,
        Icons.info_outline,
      ));
    }
    
    // Priority
    if (event.priority > 0) {
      metadata.add(_buildMetadataItem(
        context,
        colorScheme,
        textTheme,
        'Priority',
        '${event.priority}/9',
        Icons.priority_high,
      ));
    }
    
    // URL
    if (event.url?.isNotEmpty == true) {
      metadata.add(_buildMetadataItem(
        context,
        colorScheme,
        textTheme,
        'URL',
        event.url!,
        Icons.link,
      ));
    }
    
    // Recurrence
    if (event.isRecurring == true) {
      metadata.add(_buildMetadataItem(
        context,
        colorScheme,
        textTheme,
        'Recurring',
        'Yes',
        Icons.repeat,
      ));
    }
    
    // Timezone
    if (event.timeZone?.isNotEmpty == true) {
      metadata.add(_buildMetadataItem(
        context,
        colorScheme,
        textTheme,
        'Timezone',
        event.timeZone!,
        Icons.access_time,
      ));
    }
    
    if (metadata.isEmpty) return const SizedBox.shrink();
    
    return _buildSection(
      context,
      colorScheme,
      textTheme,
      'Event Details',
      Icons.info_outline,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: metadata,
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    String title,
    IconData icon,
    Widget content,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  Widget _buildMetadataItem(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAttendeeIcon(String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
        return Icons.check_circle_outline;
      case 'DECLINED':
        return Icons.cancel_outlined;
      case 'TENTATIVE':
        return Icons.help_outline;
      case 'DELEGATED':
        return Icons.forward_outlined;
      default:
        return Icons.schedule;
    }
  }

  Color _getAttendeeColor(String status, ColorScheme colorScheme) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
        return Colors.green;
      case 'DECLINED':
        return Colors.red;
      case 'TENTATIVE':
        return Colors.orange;
      case 'DELEGATED':
        return Colors.blue;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }
} 