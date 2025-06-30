/// Attendee model for calendar events following RFC 5545 specification
/// Represents participants in calendar events with proper CalDAV/iCal compatibility

library;

/// Attendee model for FlowIt task management
/// 
/// This file defines the Attendee model used to represent users or entities
/// associated with a task or project. It handles their role, engagement,
/// response status, and potential delegations according to iCalendar standards.

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'attendee.freezed.dart';
part 'attendee.g.dart';

/// Attendance status values for PARTSTAT field
@HiveType(typeId: 2)
enum AttendeeStatus {
  @HiveField(0)
  @JsonValue('NEEDS-ACTION')
  needsAction('NEEDS-ACTION'),
  @HiveField(1)
  @JsonValue('ACCEPTED')
  accepted('ACCEPTED'),
  @HiveField(2)
  @JsonValue('DECLINED') 
  declined('DECLINED'),
  @HiveField(3)
  @JsonValue('TENTATIVE')
  tentative('TENTATIVE'),
  @HiveField(4)
  @JsonValue('DELEGATED')
  delegated('DELEGATED');

  const AttendeeStatus(this.value);
  final String value;
  
  static AttendeeStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'NEEDS-ACTION':
        return AttendeeStatus.needsAction;
      case 'ACCEPTED':
        return AttendeeStatus.accepted;
      case 'DECLINED':
        return AttendeeStatus.declined;
      case 'TENTATIVE':
        return AttendeeStatus.tentative;
      case 'DELEGATED':
        return AttendeeStatus.delegated;
      default:
        return AttendeeStatus.needsAction;
    }
  }
}

/// Role values for ROLE field
@HiveType(typeId: 3)
enum AttendeeRole {
  @HiveField(0)
  @JsonValue('REQ-PARTICIPANT')
  requiredParticipant('REQ-PARTICIPANT'),
  @HiveField(1)
  @JsonValue('OPT-PARTICIPANT')
  optionalParticipant('OPT-PARTICIPANT'),
  @HiveField(2)
  @JsonValue('NON-PARTICIPANT')
  nonParticipant('NON-PARTICIPANT'),
  @HiveField(3)
  @JsonValue('CHAIR')
  chair('CHAIR');

  const AttendeeRole(this.value);
  final String value;
  
  static AttendeeRole fromString(String value) {
    switch (value.toUpperCase()) {
      case 'REQ-PARTICIPANT':
        return AttendeeRole.requiredParticipant;
      case 'OPT-PARTICIPANT':
        return AttendeeRole.optionalParticipant;
      case 'NON-PARTICIPANT':
        return AttendeeRole.nonParticipant;
      case 'CHAIR':
        return AttendeeRole.chair;
      default:
        return AttendeeRole.requiredParticipant;
    }
  }
}

/// Calendar user type for CUTYPE field
@HiveType(typeId: 4)
enum CalendarUserType {
  @HiveField(0)
  @JsonValue('INDIVIDUAL')
  individual('INDIVIDUAL'),
  @HiveField(1)
  @JsonValue('GROUP')
  group('GROUP'),
  @HiveField(2)
  @JsonValue('RESOURCE')
  resource('RESOURCE'),
  @HiveField(3)
  @JsonValue('ROOM')
  room('ROOM'),
  @HiveField(4)
  @JsonValue('UNKNOWN')
  unknown('UNKNOWN');

  const CalendarUserType(this.value);
  final String value;
  
  static CalendarUserType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'INDIVIDUAL':
        return CalendarUserType.individual;
      case 'GROUP':
        return CalendarUserType.group;
      case 'RESOURCE':
        return CalendarUserType.resource;
      case 'ROOM':
        return CalendarUserType.room;
      default:
        return CalendarUserType.individual;
    }
  }
}

/// Attendee model representing a participant in a task or project
@HiveType(typeId: 5)
@freezed
class Attendee with _$Attendee {
  const factory Attendee({
    /// Email address (URI) - mandatory field
    @HiveField(0) required String email,
    
    /// Display name (CN parameter)
    @HiveField(1) String? displayName,
    
    /// Participation status (PARTSTAT parameter)
    @HiveField(2) @Default(AttendeeStatus.needsAction) AttendeeStatus status,
    
    /// Role in the task/project (ROLE parameter)
    @HiveField(3) @Default(AttendeeRole.requiredParticipant) AttendeeRole role,
    
    /// Whether response is expected (RSVP parameter)
    @HiveField(4) @Default(false) bool rsvpRequested,
    
    /// Calendar user type (CUTYPE parameter)
    @HiveField(5) @Default(CalendarUserType.individual) CalendarUserType userType,
    
    /// Who delegated this task (DELEGATED-FROM parameter)
    @HiveField(6) String? delegatedFrom,
    
    /// Who this task was delegated to (DELEGATED-TO parameter)
    @HiveField(7) String? delegatedTo,
    
    /// Schedule agent responsibility (SCHEDULE-AGENT parameter)
    @HiveField(8) String? scheduleAgent,
    
    /// Group membership (MEMBER parameter)
    @HiveField(9) String? memberOf,
  }) = _Attendee;

  factory Attendee.fromJson(Map<String, dynamic> json) => _$AttendeeFromJson(json);
}

/// Extension methods for Attendee
extension AttendeeExtensions on Attendee {
  /// Get a human-readable status description
  String get statusDescription {
    switch (status) {
      case AttendeeStatus.needsAction:
        return 'Pas encore répondu';
      case AttendeeStatus.accepted:
        return 'Accepté';
      case AttendeeStatus.declined:
        return 'Refusé';
      case AttendeeStatus.tentative:
        return 'Disponible si besoin';
      case AttendeeStatus.delegated:
        return 'Délégué';
    }
  }
  
  /// Get a human-readable role description
  String get roleDescription {
    switch (role) {
      case AttendeeRole.requiredParticipant:
        return 'Participant requis';
      case AttendeeRole.optionalParticipant:
        return 'Participant optionnel';
      case AttendeeRole.nonParticipant:
        return 'Observateur';
      case AttendeeRole.chair:
        return 'Responsable';
    }
  }
  
  /// Get display name or email as fallback
  String get effectiveDisplayName => displayName ?? email;
  
  /// Check if this attendee is delegated
  bool get isDelegated => status == AttendeeStatus.delegated;
  
  /// Check if this attendee has accepted
  bool get hasAccepted => status == AttendeeStatus.accepted;
  
  /// Check if this attendee is available as backup
  bool get isTentative => status == AttendeeStatus.tentative;
}

/// Factory extensions for Attendee creation
extension AttendeeFactory on Attendee {
  /// Create an Attendee from just an email (for migration/simple cases)
  static Attendee fromEmail(String email, {
    String? displayName,
    AttendeeStatus status = AttendeeStatus.needsAction,
    AttendeeRole role = AttendeeRole.requiredParticipant,
  }) {
    return Attendee(
      email: email,
      displayName: displayName,
      status: status,
      role: role,
    );
  }
  
  /// Create an Attendee from an organizer email (with chair role)
  static Attendee fromOrganizer(String email, {String? displayName}) {
    return Attendee(
      email: email,
      displayName: displayName,
      status: AttendeeStatus.accepted,
      role: AttendeeRole.chair,
    );
  }
} 
