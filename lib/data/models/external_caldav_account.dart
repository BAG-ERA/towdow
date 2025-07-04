// External CalDAV account model for external calendar connections
// Represents read-only CalDAV accounts for external calendar integration
// Supports different authentication methods and server types

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'external_caldav_account.freezed.dart';
part 'external_caldav_account.g.dart';

// Authentication type for external CalDAV accounts
@HiveType(typeId: 33)
enum ExternalCalendarAuthType {
  @HiveField(0)
  basic,
  @HiveField(1)
  oauth,
  @HiveField(2)
  anonymous,
}

@HiveType(typeId: 32)
@freezed
class ExternalCaldavAccount with _$ExternalCaldavAccount {
  const factory ExternalCaldavAccount({
    @HiveField(0) required String id,
    @HiveField(1) required String displayName, // User-friendly name
    @HiveField(2) required String serverUrl,
    @HiveField(3) required String username,
    @HiveField(4) String? password, // for basic auth
    @HiveField(5) String? accessToken, // for OAuth
    @HiveField(6) String? refreshToken, // for OAuth
    @HiveField(7) DateTime? tokenExpiry, // for OAuth
    @HiveField(8) @Default('custom') String providerType, // google, outlook, icloud, nextcloud, custom
    @HiveField(9) required DateTime createdAt,
    @HiveField(10) DateTime? lastSyncAt,
    @HiveField(11) @Default(true) bool isActive,
    @HiveField(12) @Default(true) bool isReadOnly, // External accounts are read-only
    @HiveField(30) @Default(ExternalCalendarAuthType.basic) ExternalCalendarAuthType authType,
    
    // Server capabilities and info
    @HiveField(13) String? serverInfo,
    @HiveField(14) String? principalUrl,
    @HiveField(15) String? calendarHomeUrl,
    @HiveField(16) @Default([]) List<String> supportedComponents, // VEVENT, VTODO, etc.
    @HiveField(17) @Default([]) List<String> supportedFeatures, // sync-collection, etc.
    
    // User information
    @HiveField(18) String? userDisplayName,
    @HiveField(19) String? userEmail,
    @HiveField(20) String? userTimeZone,
    
    // Sync settings
    @HiveField(21) @Default(true) bool autoSync,
    @HiveField(22) @Default(300) int syncIntervalSeconds, // 5 minutes default
    @HiveField(23) DateTime? lastSuccessfulSync,
    @HiveField(24) String? lastSyncError,
    @HiveField(25) @Default(0) int syncErrorCount,
    
    // Statistics
    @HiveField(26) @Default(0) int totalCalendars,
    @HiveField(27) @Default(0) int activeCalendars,
    @HiveField(28) @Default(0) int totalEvents,
    @HiveField(29) DateTime? lastEventSync,
  }) = _ExternalCaldavAccount;

  factory ExternalCaldavAccount.fromJson(Map<String, dynamic> json) => _$ExternalCaldavAccountFromJson(json);
}

// Factory methods for creating external accounts
extension ExternalCaldavAccountFactory on ExternalCaldavAccount {
  static ExternalCaldavAccount createNew({
    required String displayName,
    required String serverUrl,
    required String username,
    String? password,
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiry,
    String providerType = 'custom',
    ExternalCalendarAuthType authType = ExternalCalendarAuthType.basic,
    String? userDisplayName,
    String? userEmail,
    String? userTimeZone,
  }) {
    final now = DateTime.now();
    return ExternalCaldavAccount(
      id: 'external-${now.millisecondsSinceEpoch}',
      displayName: displayName,
      serverUrl: serverUrl,
      username: username,
      password: password,
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenExpiry: tokenExpiry,
      providerType: providerType,
      authType: authType,
      userDisplayName: userDisplayName,
      userEmail: userEmail,
      userTimeZone: userTimeZone,
      createdAt: now,
      lastSyncAt: now,
    );
  }
  
  static ExternalCaldavAccount createFromDiscovery({
    required String displayName,
    required String serverUrl,
    required String username,
    String? password,
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiry,
    String providerType = 'custom',
    ExternalCalendarAuthType authType = ExternalCalendarAuthType.basic,
    String? serverInfo,
    String? principalUrl,
    String? calendarHomeUrl,
    List<String> supportedComponents = const ['VEVENT'],
    List<String> supportedFeatures = const [],
    String? userDisplayName,
    String? userEmail,
    String? userTimeZone,
  }) {
    final now = DateTime.now();
    return ExternalCaldavAccount(
      id: 'external-${now.millisecondsSinceEpoch}',
      displayName: displayName,
      serverUrl: serverUrl,
      username: username,
      password: password,
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenExpiry: tokenExpiry,
      providerType: providerType,
      authType: authType,
      serverInfo: serverInfo,
      principalUrl: principalUrl,
      calendarHomeUrl: calendarHomeUrl,
      supportedComponents: supportedComponents,
      supportedFeatures: supportedFeatures,
      userDisplayName: userDisplayName,
      userEmail: userEmail,
      userTimeZone: userTimeZone,
      createdAt: now,
      lastSyncAt: now,
    );
  }
}

// Extension for external account operations
extension ExternalCaldavAccountOperations on ExternalCaldavAccount {
  /// Check if account uses OAuth authentication
  bool get usesOAuth => accessToken != null;
  
  /// Check if account uses basic authentication
  bool get usesBasicAuth => password != null;
  
  /// Check if account is anonymous (public calendar)
  bool get isAnonymous => !usesOAuth && !usesBasicAuth;
  
  /// Check if OAuth token is expired
  bool get isTokenExpired {
    if (tokenExpiry == null) return false;
    return DateTime.now().isAfter(tokenExpiry!);
  }
  
  /// Check if account needs authentication refresh
  bool get needsAuthRefresh => usesOAuth && (isTokenExpired || accessToken == null);
  
  /// Check if account has sync errors
  bool get hasSyncErrors => syncErrorCount > 0;
  
  /// Check if account supports VEVENT
  bool get supportsVEvent => supportedComponents.contains('VEVENT');
  
  /// Check if account supports sync-collection
  bool get supportsSyncCollection => supportedFeatures.contains('sync-collection');
  
  /// Get display name for account
  String get accountDisplayName => userDisplayName ?? displayName;
  
  /// Check if account needs sync (ready for sync and hasn't synced recently)
  bool get needsSync {
    if (!isActive || !supportsVEvent) return false;
    if (lastSyncAt == null) return true;
    
    final now = DateTime.now();
    final timeSinceSync = now.difference(lastSyncAt!);
    return timeSinceSync.inSeconds > syncIntervalSeconds;
  }
  
  /// Get authentication type as string (legacy method, use authType enum)
  String get authTypeString {
    switch (authType) {
      case ExternalCalendarAuthType.oauth:
        return 'OAuth';
      case ExternalCalendarAuthType.basic:
        return 'Basic Auth';
      case ExternalCalendarAuthType.anonymous:
        return 'Anonymous';
    }
  }
  
  /// Get provider display name
  String get providerDisplayName {
    switch (providerType.toLowerCase()) {
      case 'google':
        return 'Google Calendar';
      case 'outlook':
        return 'Outlook Calendar';
      case 'icloud':
        return 'iCloud Calendar';
      case 'nextcloud':
        return 'Nextcloud';
      case 'owncloud':
        return 'ownCloud';
      case 'sabre':
        return 'Sabre/DAV';
      case 'radicale':
        return 'Radicale';
      default:
        return 'Custom CalDAV';
    }
  }
  
  /// Create a copy with updated sync info
  ExternalCaldavAccount withSyncUpdate({
    DateTime? lastSyncAt,
    DateTime? lastSuccessfulSync,
    String? lastSyncError,
    int? syncErrorCount,
    int? totalCalendars,
    int? activeCalendars,
    int? totalEvents,
    DateTime? lastEventSync,
  }) {
    return copyWith(
      lastSyncAt: lastSyncAt ?? DateTime.now(),
      lastSuccessfulSync: lastSuccessfulSync,
      lastSyncError: lastSyncError,
      syncErrorCount: syncErrorCount ?? this.syncErrorCount,
      totalCalendars: totalCalendars ?? this.totalCalendars,
      activeCalendars: activeCalendars ?? this.activeCalendars,
      totalEvents: totalEvents ?? this.totalEvents,
      lastEventSync: lastEventSync ?? this.lastEventSync,
    );
  }
  
  /// Create a copy with auth refresh
  ExternalCaldavAccount withAuthRefresh({
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiry,
  }) {
    return copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenExpiry: tokenExpiry,
      syncErrorCount: 0, // Reset error count on successful auth refresh
      lastSyncError: null,
    );
  }
  
  /// Create a copy with error
  ExternalCaldavAccount withError(String error) {
    return copyWith(
      lastSyncError: error,
      syncErrorCount: syncErrorCount + 1,
      lastSyncAt: DateTime.now(),
    );
  }
  
  /// Create a copy with active/inactive state
  ExternalCaldavAccount withActive(bool active) {
    return copyWith(
      isActive: active,
      lastSyncAt: DateTime.now(),
    );
  }
} 