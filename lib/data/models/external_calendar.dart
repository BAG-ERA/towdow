// External calendar model for CalDAV calendar information
// Represents external read-only calendars that sync VEVENT items
// Supports persistent storage with Hive and synchronization tracking

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

part 'external_calendar.freezed.dart';
part 'external_calendar.g.dart';

@HiveType(typeId: 30)
@freezed
class ExternalCalendar with _$ExternalCalendar {
  const factory ExternalCalendar({
    // CalDAV server properties
    @HiveField(0) required String path,
    @HiveField(1) required String displayName,
    @HiveField(2) @Default('') String description,
    @HiveField(3) @Default(true) bool supportsEvents,
    @HiveField(4) String? etag,
    @HiveField(5) String? color,
    @HiveField(6) DateTime? lastSyncAt,
    @HiveField(7) @Default(true) bool isReadOnly, // External calendars are read-only
    @HiveField(8) String? syncToken,
    @HiveField(9) required String uid,
    @HiveField(10) required DateTime created,
    @HiveField(11) required DateTime lastModified,
    @HiveField(12) @Default(true) bool isEnabled, // Whether to sync this calendar
    
    // External calendar account reference
    @HiveField(13) required String accountId,
    
    // Calendar metadata
    @HiveField(14) String? timeZone,
    @HiveField(15) @Default([]) List<String> supportedComponents, // VEVENT, VTODO, etc.
    @HiveField(16) String? ownerName,
    @HiveField(17) String? ownerEmail,
    @HiveField(18) @Default(0) int sortOrder,
    
    // Statistics
    @HiveField(19) @Default(0) int eventCount,
    @HiveField(20) DateTime? lastEventDate,
    @HiveField(21) DateTime? nextEventDate,
    
    // Sync error tracking
    @HiveField(22) String? lastSyncError,
    @HiveField(23) @Default(0) int syncErrorCount,
    @HiveField(24) DateTime? lastSuccessfulSync,
  }) = _ExternalCalendar;

  factory ExternalCalendar.fromJson(Map<String, dynamic> json) => _$ExternalCalendarFromJson(json);
}

// Factory methods for creating external calendars
extension ExternalCalendarFactory on ExternalCalendar {
  static ExternalCalendar createNew({
    required String accountId,
    required String path,
    required String displayName,
    String description = '',
    String? color,
    String? timeZone,
    List<String> supportedComponents = const ['VEVENT'],
    String? ownerName,
    String? ownerEmail,
  }) {
    final now = DateTime.now();
    return ExternalCalendar(
      accountId: accountId,
      path: path,
      displayName: displayName,
      description: description,
      color: color,
      timeZone: timeZone,
      supportedComponents: supportedComponents,
      ownerName: ownerName,
      ownerEmail: ownerEmail,
      uid: 'external-${now.millisecondsSinceEpoch}-${displayName.hashCode}',
      created: now,
      lastModified: now,
    );
  }
  
  static ExternalCalendar fromCalDAVDiscovery({
    required String accountId,
    required String path,
    required String displayName,
    String description = '',
    String? etag,
    String? color,
    String? timeZone,
    List<String> supportedComponents = const ['VEVENT'],
    String? ownerName,
    String? ownerEmail,
    String? uid,
  }) {
    final now = DateTime.now();
    return ExternalCalendar(
      accountId: accountId,
      path: path,
      displayName: displayName,
      description: description,
      etag: etag,
      color: color,
      timeZone: timeZone,
      supportedComponents: supportedComponents,
      ownerName: ownerName,
      ownerEmail: ownerEmail,
      uid: uid ?? 'discovered-${path.hashCode}',
      created: now,
      lastModified: now,
    );
  }
}

// Extension for external calendar operations
extension ExternalCalendarOperations on ExternalCalendar {
  /// Alias for uid (for compatibility with sync service)
  String get id => uid;
  
  /// Get href (path) for CalDAV operations
  String get href => path;
  
  /// Check if this calendar supports VEVENT
  bool get supportsVEvent => supportedComponents.contains('VEVENT');
  
  /// Check if this calendar is active for sync
  bool get isActiveForSync => isEnabled && supportsVEvent;
  
  /// Get display name with account info
  String get displayNameWithAccount => '$displayName ($accountId)';
  
  /// Create a copy with updated sync info
  ExternalCalendar withSyncUpdate({
    String? syncToken,
    DateTime? lastSyncAt,
    int? eventCount,
    DateTime? lastEventDate,
    DateTime? nextEventDate,
  }) {
    return copyWith(
      syncToken: syncToken,
      lastSyncAt: lastSyncAt ?? DateTime.now(),
      eventCount: eventCount ?? this.eventCount,
      lastEventDate: lastEventDate ?? this.lastEventDate,
      nextEventDate: nextEventDate ?? this.nextEventDate,
      lastModified: DateTime.now(),
    );
  }
  
  /// Create a copy with enabled/disabled state
  ExternalCalendar withEnabled(bool enabled) {
    return copyWith(
      isEnabled: enabled,
      lastModified: DateTime.now(),
    );
  }
  
  /// Create a copy with sync error info
  ExternalCalendar withSyncError(String error) {
    return copyWith(
      lastSyncError: error,
      syncErrorCount: syncErrorCount + 1,
      lastModified: DateTime.now(),
    );
  }
  
  /// Create a copy with successful sync info
  ExternalCalendar withSyncSuccess({
    String? syncToken,
    int? eventCount,
    DateTime? lastEventDate,
    DateTime? nextEventDate,
  }) {
    return copyWith(
      syncToken: syncToken,
      lastSyncAt: DateTime.now(),
      lastSuccessfulSync: DateTime.now(),
      lastSyncError: null, // Clear error on success
      syncErrorCount: 0, // Reset error count
      eventCount: eventCount ?? this.eventCount,
      lastEventDate: lastEventDate ?? this.lastEventDate,
      nextEventDate: nextEventDate ?? this.nextEventDate,
      lastModified: DateTime.now(),
    );
  }
} 