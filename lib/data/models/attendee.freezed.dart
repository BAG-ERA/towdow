// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attendee.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Attendee _$AttendeeFromJson(Map<String, dynamic> json) {
  return _Attendee.fromJson(json);
}

/// @nodoc
mixin _$Attendee {
  /// Email address (URI) - mandatory field
  @HiveField(0)
  String get email => throw _privateConstructorUsedError;

  /// Display name (CN parameter)
  @HiveField(1)
  String? get displayName => throw _privateConstructorUsedError;

  /// Participation status (PARTSTAT parameter)
  @HiveField(2)
  AttendeeStatus get status => throw _privateConstructorUsedError;

  /// Role in the task/project (ROLE parameter)
  @HiveField(3)
  AttendeeRole get role => throw _privateConstructorUsedError;

  /// Whether response is expected (RSVP parameter)
  @HiveField(4)
  bool get rsvpRequested => throw _privateConstructorUsedError;

  /// Calendar user type (CUTYPE parameter)
  @HiveField(5)
  CalendarUserType get userType => throw _privateConstructorUsedError;

  /// Who delegated this task (DELEGATED-FROM parameter)
  @HiveField(6)
  String? get delegatedFrom => throw _privateConstructorUsedError;

  /// Who this task was delegated to (DELEGATED-TO parameter)
  @HiveField(7)
  String? get delegatedTo => throw _privateConstructorUsedError;

  /// Schedule agent responsibility (SCHEDULE-AGENT parameter)
  @HiveField(8)
  String? get scheduleAgent => throw _privateConstructorUsedError;

  /// Group membership (MEMBER parameter)
  @HiveField(9)
  String? get memberOf => throw _privateConstructorUsedError;

  /// Serializes this Attendee to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Attendee
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttendeeCopyWith<Attendee> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttendeeCopyWith<$Res> {
  factory $AttendeeCopyWith(Attendee value, $Res Function(Attendee) then) =
      _$AttendeeCopyWithImpl<$Res, Attendee>;
  @useResult
  $Res call(
      {@HiveField(0) String email,
      @HiveField(1) String? displayName,
      @HiveField(2) AttendeeStatus status,
      @HiveField(3) AttendeeRole role,
      @HiveField(4) bool rsvpRequested,
      @HiveField(5) CalendarUserType userType,
      @HiveField(6) String? delegatedFrom,
      @HiveField(7) String? delegatedTo,
      @HiveField(8) String? scheduleAgent,
      @HiveField(9) String? memberOf});
}

/// @nodoc
class _$AttendeeCopyWithImpl<$Res, $Val extends Attendee>
    implements $AttendeeCopyWith<$Res> {
  _$AttendeeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Attendee
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? email = null,
    Object? displayName = freezed,
    Object? status = null,
    Object? role = null,
    Object? rsvpRequested = null,
    Object? userType = null,
    Object? delegatedFrom = freezed,
    Object? delegatedTo = freezed,
    Object? scheduleAgent = freezed,
    Object? memberOf = freezed,
  }) {
    return _then(_value.copyWith(
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: freezed == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AttendeeStatus,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as AttendeeRole,
      rsvpRequested: null == rsvpRequested
          ? _value.rsvpRequested
          : rsvpRequested // ignore: cast_nullable_to_non_nullable
              as bool,
      userType: null == userType
          ? _value.userType
          : userType // ignore: cast_nullable_to_non_nullable
              as CalendarUserType,
      delegatedFrom: freezed == delegatedFrom
          ? _value.delegatedFrom
          : delegatedFrom // ignore: cast_nullable_to_non_nullable
              as String?,
      delegatedTo: freezed == delegatedTo
          ? _value.delegatedTo
          : delegatedTo // ignore: cast_nullable_to_non_nullable
              as String?,
      scheduleAgent: freezed == scheduleAgent
          ? _value.scheduleAgent
          : scheduleAgent // ignore: cast_nullable_to_non_nullable
              as String?,
      memberOf: freezed == memberOf
          ? _value.memberOf
          : memberOf // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AttendeeImplCopyWith<$Res>
    implements $AttendeeCopyWith<$Res> {
  factory _$$AttendeeImplCopyWith(
          _$AttendeeImpl value, $Res Function(_$AttendeeImpl) then) =
      __$$AttendeeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) String email,
      @HiveField(1) String? displayName,
      @HiveField(2) AttendeeStatus status,
      @HiveField(3) AttendeeRole role,
      @HiveField(4) bool rsvpRequested,
      @HiveField(5) CalendarUserType userType,
      @HiveField(6) String? delegatedFrom,
      @HiveField(7) String? delegatedTo,
      @HiveField(8) String? scheduleAgent,
      @HiveField(9) String? memberOf});
}

/// @nodoc
class __$$AttendeeImplCopyWithImpl<$Res>
    extends _$AttendeeCopyWithImpl<$Res, _$AttendeeImpl>
    implements _$$AttendeeImplCopyWith<$Res> {
  __$$AttendeeImplCopyWithImpl(
      _$AttendeeImpl _value, $Res Function(_$AttendeeImpl) _then)
      : super(_value, _then);

  /// Create a copy of Attendee
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? email = null,
    Object? displayName = freezed,
    Object? status = null,
    Object? role = null,
    Object? rsvpRequested = null,
    Object? userType = null,
    Object? delegatedFrom = freezed,
    Object? delegatedTo = freezed,
    Object? scheduleAgent = freezed,
    Object? memberOf = freezed,
  }) {
    return _then(_$AttendeeImpl(
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: freezed == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AttendeeStatus,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as AttendeeRole,
      rsvpRequested: null == rsvpRequested
          ? _value.rsvpRequested
          : rsvpRequested // ignore: cast_nullable_to_non_nullable
              as bool,
      userType: null == userType
          ? _value.userType
          : userType // ignore: cast_nullable_to_non_nullable
              as CalendarUserType,
      delegatedFrom: freezed == delegatedFrom
          ? _value.delegatedFrom
          : delegatedFrom // ignore: cast_nullable_to_non_nullable
              as String?,
      delegatedTo: freezed == delegatedTo
          ? _value.delegatedTo
          : delegatedTo // ignore: cast_nullable_to_non_nullable
              as String?,
      scheduleAgent: freezed == scheduleAgent
          ? _value.scheduleAgent
          : scheduleAgent // ignore: cast_nullable_to_non_nullable
              as String?,
      memberOf: freezed == memberOf
          ? _value.memberOf
          : memberOf // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AttendeeImpl implements _Attendee {
  const _$AttendeeImpl(
      {@HiveField(0) required this.email,
      @HiveField(1) this.displayName,
      @HiveField(2) this.status = AttendeeStatus.needsAction,
      @HiveField(3) this.role = AttendeeRole.requiredParticipant,
      @HiveField(4) this.rsvpRequested = false,
      @HiveField(5) this.userType = CalendarUserType.individual,
      @HiveField(6) this.delegatedFrom,
      @HiveField(7) this.delegatedTo,
      @HiveField(8) this.scheduleAgent,
      @HiveField(9) this.memberOf});

  factory _$AttendeeImpl.fromJson(Map<String, dynamic> json) =>
      _$$AttendeeImplFromJson(json);

  /// Email address (URI) - mandatory field
  @override
  @HiveField(0)
  final String email;

  /// Display name (CN parameter)
  @override
  @HiveField(1)
  final String? displayName;

  /// Participation status (PARTSTAT parameter)
  @override
  @JsonKey()
  @HiveField(2)
  final AttendeeStatus status;

  /// Role in the task/project (ROLE parameter)
  @override
  @JsonKey()
  @HiveField(3)
  final AttendeeRole role;

  /// Whether response is expected (RSVP parameter)
  @override
  @JsonKey()
  @HiveField(4)
  final bool rsvpRequested;

  /// Calendar user type (CUTYPE parameter)
  @override
  @JsonKey()
  @HiveField(5)
  final CalendarUserType userType;

  /// Who delegated this task (DELEGATED-FROM parameter)
  @override
  @HiveField(6)
  final String? delegatedFrom;

  /// Who this task was delegated to (DELEGATED-TO parameter)
  @override
  @HiveField(7)
  final String? delegatedTo;

  /// Schedule agent responsibility (SCHEDULE-AGENT parameter)
  @override
  @HiveField(8)
  final String? scheduleAgent;

  /// Group membership (MEMBER parameter)
  @override
  @HiveField(9)
  final String? memberOf;

  @override
  String toString() {
    return 'Attendee(email: $email, displayName: $displayName, status: $status, role: $role, rsvpRequested: $rsvpRequested, userType: $userType, delegatedFrom: $delegatedFrom, delegatedTo: $delegatedTo, scheduleAgent: $scheduleAgent, memberOf: $memberOf)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttendeeImpl &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.rsvpRequested, rsvpRequested) ||
                other.rsvpRequested == rsvpRequested) &&
            (identical(other.userType, userType) ||
                other.userType == userType) &&
            (identical(other.delegatedFrom, delegatedFrom) ||
                other.delegatedFrom == delegatedFrom) &&
            (identical(other.delegatedTo, delegatedTo) ||
                other.delegatedTo == delegatedTo) &&
            (identical(other.scheduleAgent, scheduleAgent) ||
                other.scheduleAgent == scheduleAgent) &&
            (identical(other.memberOf, memberOf) ||
                other.memberOf == memberOf));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      email,
      displayName,
      status,
      role,
      rsvpRequested,
      userType,
      delegatedFrom,
      delegatedTo,
      scheduleAgent,
      memberOf);

  /// Create a copy of Attendee
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttendeeImplCopyWith<_$AttendeeImpl> get copyWith =>
      __$$AttendeeImplCopyWithImpl<_$AttendeeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AttendeeImplToJson(
      this,
    );
  }
}

abstract class _Attendee implements Attendee {
  const factory _Attendee(
      {@HiveField(0) required final String email,
      @HiveField(1) final String? displayName,
      @HiveField(2) final AttendeeStatus status,
      @HiveField(3) final AttendeeRole role,
      @HiveField(4) final bool rsvpRequested,
      @HiveField(5) final CalendarUserType userType,
      @HiveField(6) final String? delegatedFrom,
      @HiveField(7) final String? delegatedTo,
      @HiveField(8) final String? scheduleAgent,
      @HiveField(9) final String? memberOf}) = _$AttendeeImpl;

  factory _Attendee.fromJson(Map<String, dynamic> json) =
      _$AttendeeImpl.fromJson;

  /// Email address (URI) - mandatory field
  @override
  @HiveField(0)
  String get email;

  /// Display name (CN parameter)
  @override
  @HiveField(1)
  String? get displayName;

  /// Participation status (PARTSTAT parameter)
  @override
  @HiveField(2)
  AttendeeStatus get status;

  /// Role in the task/project (ROLE parameter)
  @override
  @HiveField(3)
  AttendeeRole get role;

  /// Whether response is expected (RSVP parameter)
  @override
  @HiveField(4)
  bool get rsvpRequested;

  /// Calendar user type (CUTYPE parameter)
  @override
  @HiveField(5)
  CalendarUserType get userType;

  /// Who delegated this task (DELEGATED-FROM parameter)
  @override
  @HiveField(6)
  String? get delegatedFrom;

  /// Who this task was delegated to (DELEGATED-TO parameter)
  @override
  @HiveField(7)
  String? get delegatedTo;

  /// Schedule agent responsibility (SCHEDULE-AGENT parameter)
  @override
  @HiveField(8)
  String? get scheduleAgent;

  /// Group membership (MEMBER parameter)
  @override
  @HiveField(9)
  String? get memberOf;

  /// Create a copy of Attendee
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttendeeImplCopyWith<_$AttendeeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
