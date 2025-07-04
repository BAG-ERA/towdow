// Calendar event model for external CalDAV VEVENT items
// Represents events from external read-only calendars
// Supports persistent storage with Hive and basic calendar functionality

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'attendee.dart';

part 'calendar_event.freezed.dart';
part 'calendar_event.g.dart';

@HiveType(typeId: 31)
@freezed
class CalendarEvent with _$CalendarEvent {
  const factory CalendarEvent({
    // Basic event properties (RFC 5545)
    @HiveField(0) required String uid,
    @HiveField(1) required String summary,
    @HiveField(2) @Default('') String description,
    @HiveField(3) required DateTime dtstamp,
    @HiveField(4) required DateTime created,
    @HiveField(5) required DateTime lastModified,
    @HiveField(6) required DateTime dtstart,
    @HiveField(7) DateTime? dtend,
    @HiveField(8) String? duration, // Alternative to dtend
    @HiveField(9) @Default('CONFIRMED') String status, // TENTATIVE, CONFIRMED, CANCELLED
    @HiveField(10) @Default('OPAQUE') String transparency, // OPAQUE, TRANSPARENT
    @HiveField(11) @Default('PUBLIC') String classification, // PUBLIC, PRIVATE, CONFIDENTIAL
    @HiveField(12) @Default(0) int sequence,
    @HiveField(13) @Default(0) int priority, // 0-9
    
    // Location and contact info
    @HiveField(14) String? location,
    @HiveField(15) String? organizer,
    @HiveField(16) @Default([]) List<Attendee> attendees,
    @HiveField(17) String? contact,
    @HiveField(18) String? url,
    
    // Categories and classification
    @HiveField(19) @Default([]) List<String> categories,
    @HiveField(20) @Default([]) List<String> resources,
    
    // Timezone and recurrence
    @HiveField(21) String? timeZone,
    @HiveField(22) String? recurrenceRule, // RRULE
    @HiveField(23) @Default([]) List<DateTime> recurrenceDates, // RDATE
    @HiveField(24) @Default([]) List<DateTime> exceptionDates, // EXDATE
    @HiveField(25) String? recurrenceId, // For recurring event exceptions
    
    // Alarms and reminders
    @HiveField(26) @Default([]) List<String> alarms,
    
    // External calendar info
    @HiveField(27) required String sourceCalendarUid,
    @HiveField(28) required String accountId,
    @HiveField(29) String? etag,
    @HiveField(30) String? href, // CalDAV URL
    
    // Computed properties
    @HiveField(31) @Default(false) bool isAllDay,
    @HiveField(32) @Default(false) bool isRecurring,
    @HiveField(33) @Default(false) bool isException, // Exception to recurring series
    @HiveField(34) Duration? computedDuration,
  }) = _CalendarEvent;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => _$CalendarEventFromJson(json);
}

// Factory methods for creating calendar events
extension CalendarEventFactory on CalendarEvent {
  static CalendarEvent createFromVEvent({
    required String uid,
    required String summary,
    required String sourceCalendarUid,
    required String accountId,
    required DateTime dtstart,
    DateTime? dtend,
    String description = '',
    String? location,
    String? organizer,
    List<Attendee> attendees = const [],
    List<String> categories = const [],
    String status = 'CONFIRMED',
    String? etag,
    String? href,
    bool isAllDay = false,
    String? timeZone,
    String? recurrenceRule,
  }) {
    final now = DateTime.now();
    return CalendarEvent(
      uid: uid,
      summary: summary,
      description: description,
      sourceCalendarUid: sourceCalendarUid,
      accountId: accountId,
      dtstart: dtstart,
      dtend: dtend,
      location: location,
      organizer: organizer,
      attendees: attendees,
      categories: categories,
      status: status,
      etag: etag,
      href: href,
      isAllDay: isAllDay,
      timeZone: timeZone,
      recurrenceRule: recurrenceRule,
      isRecurring: recurrenceRule != null,
      computedDuration: dtend != null ? dtend.difference(dtstart) : null,
      dtstamp: now,
      created: now,
      lastModified: now,
    );
  }
}

// Extension for calendar event operations
extension CalendarEventOperations on CalendarEvent {
  /// Alias for uid (for compatibility with sync service)
  String get id => uid;
  
  /// Check if event is happening today
  bool get isToday {
    final today = DateTime.now();
    final eventDate = dtstart;
    return eventDate.year == today.year &&
           eventDate.month == today.month &&
           eventDate.day == today.day;
  }
  
  /// Check if event is in the future
  bool get isFuture => dtstart.isAfter(DateTime.now());
  
  /// Check if event is in the past
  bool get isPast => (dtend ?? dtstart).isBefore(DateTime.now());
  
  /// Check if event is currently happening
  bool get isNow {
    final now = DateTime.now();
    return dtstart.isBefore(now) && (dtend?.isAfter(now) ?? false);
  }
  
  /// Get event duration as a string
  String get durationString {
    if (computedDuration == null) return '';
    final duration = computedDuration!;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
  
  /// Get formatted date and time
  String get formattedDateTime {
    if (isAllDay) {
      return '${dtstart.day}/${dtstart.month}/${dtstart.year}';
    } else {
      return '${dtstart.day}/${dtstart.month}/${dtstart.year} ${dtstart.hour}:${dtstart.minute.toString().padLeft(2, '0')}';
    }
  }
  
  /// Get formatted time range
  String get formattedTimeRange {
    if (isAllDay) {
      return 'All day';
    } else if (dtend != null) {
      return '${dtstart.hour}:${dtstart.minute.toString().padLeft(2, '0')} - ${dtend!.hour}:${dtend!.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dtstart.hour}:${dtstart.minute.toString().padLeft(2, '0')}';
    }
  }
  
  /// Create a copy with updated sync info
  CalendarEvent withSyncUpdate({
    String? etag,
    DateTime? lastModified,
  }) {
    return copyWith(
      etag: etag,
      lastModified: lastModified ?? DateTime.now(),
    );
  }
  
  /// Check if event has attendees
  bool get hasAttendees => attendees.isNotEmpty;
  
  /// Check if event has organizer
  bool get hasOrganizer => organizer != null && organizer!.isNotEmpty;
  
  /// Check if event has location
  bool get hasLocation => location != null && location!.isNotEmpty;
  
  /// Check if event is cancelled
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';
  
  /// Check if event is tentative
  bool get isTentative => status.toUpperCase() == 'TENTATIVE';
  
  /// Check if event is confirmed
  bool get isConfirmed => status.toUpperCase() == 'CONFIRMED';
} 