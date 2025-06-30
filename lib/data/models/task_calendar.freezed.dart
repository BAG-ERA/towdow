// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_calendar.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TaskCalendar _$TaskCalendarFromJson(Map<String, dynamic> json) {
  return _TaskCalendar.fromJson(json);
}

/// @nodoc
mixin _$TaskCalendar {
// CalDAV server properties
  @HiveField(0)
  String get path => throw _privateConstructorUsedError;
  @HiveField(1)
  String get displayName => throw _privateConstructorUsedError;
  @HiveField(2)
  String get description => throw _privateConstructorUsedError;
  @HiveField(3)
  bool get supportsTodos => throw _privateConstructorUsedError;
  @HiveField(4)
  String? get etag => throw _privateConstructorUsedError;
  @HiveField(5)
  String? get color => throw _privateConstructorUsedError;
  @HiveField(6)
  DateTime? get lastSyncAt => throw _privateConstructorUsedError;
  @HiveField(7)
  bool get isReadOnly => throw _privateConstructorUsedError;
  @HiveField(24)
  String? get syncToken =>
      throw _privateConstructorUsedError; // Required VCALENDAR properties for FlowIt projects
  @HiveField(8)
  String get uid => throw _privateConstructorUsedError;
  @HiveField(9)
  DateTime get dtstamp => throw _privateConstructorUsedError;
  @HiveField(10)
  DateTime get created => throw _privateConstructorUsedError;
  @HiveField(11)
  DateTime get lastModified => throw _privateConstructorUsedError;
  @HiveField(12)
  String get summary => throw _privateConstructorUsedError;
  @HiveField(13)
  String get status => throw _privateConstructorUsedError;
  @HiveField(14)
  int get percentComplete =>
      throw _privateConstructorUsedError; // FlowIt-specific VCALENDAR properties
  @HiveField(15)
  String get flowitType => throw _privateConstructorUsedError; // X-FLOWIT-TYPE
  @HiveField(16)
  bool get flowitAsFlow =>
      throw _privateConstructorUsedError; // X-FLOWIT-ASFLOW
  @HiveField(17)
  String get flowitKanban =>
      throw _privateConstructorUsedError; // X-FLOWIT-KANBAN JSON array
  @HiveField(18)
  String? get flowitOwner =>
      throw _privateConstructorUsedError; // X-FLOWIT-OWNER
  @HiveField(19)
  String? get flowitTemplate =>
      throw _privateConstructorUsedError; // X-FLOWIT-TEMPLATE
  @HiveField(20)
  int get calendarOrder => throw _privateConstructorUsedError; // CALENDAR-ORDER
  @HiveField(21)
  String? get organizer => throw _privateConstructorUsedError; // ORGANIZER
  @HiveField(22)
  List<Attendee> get attendees =>
      throw _privateConstructorUsedError; // ATTENDEE
  @HiveField(23)
  List<String> get categories => throw _privateConstructorUsedError;

  /// Serializes this TaskCalendar to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TaskCalendar
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskCalendarCopyWith<TaskCalendar> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskCalendarCopyWith<$Res> {
  factory $TaskCalendarCopyWith(
          TaskCalendar value, $Res Function(TaskCalendar) then) =
      _$TaskCalendarCopyWithImpl<$Res, TaskCalendar>;
  @useResult
  $Res call(
      {@HiveField(0) String path,
      @HiveField(1) String displayName,
      @HiveField(2) String description,
      @HiveField(3) bool supportsTodos,
      @HiveField(4) String? etag,
      @HiveField(5) String? color,
      @HiveField(6) DateTime? lastSyncAt,
      @HiveField(7) bool isReadOnly,
      @HiveField(24) String? syncToken,
      @HiveField(8) String uid,
      @HiveField(9) DateTime dtstamp,
      @HiveField(10) DateTime created,
      @HiveField(11) DateTime lastModified,
      @HiveField(12) String summary,
      @HiveField(13) String status,
      @HiveField(14) int percentComplete,
      @HiveField(15) String flowitType,
      @HiveField(16) bool flowitAsFlow,
      @HiveField(17) String flowitKanban,
      @HiveField(18) String? flowitOwner,
      @HiveField(19) String? flowitTemplate,
      @HiveField(20) int calendarOrder,
      @HiveField(21) String? organizer,
      @HiveField(22) List<Attendee> attendees,
      @HiveField(23) List<String> categories});
}

/// @nodoc
class _$TaskCalendarCopyWithImpl<$Res, $Val extends TaskCalendar>
    implements $TaskCalendarCopyWith<$Res> {
  _$TaskCalendarCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskCalendar
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? path = null,
    Object? displayName = null,
    Object? description = null,
    Object? supportsTodos = null,
    Object? etag = freezed,
    Object? color = freezed,
    Object? lastSyncAt = freezed,
    Object? isReadOnly = null,
    Object? syncToken = freezed,
    Object? uid = null,
    Object? dtstamp = null,
    Object? created = null,
    Object? lastModified = null,
    Object? summary = null,
    Object? status = null,
    Object? percentComplete = null,
    Object? flowitType = null,
    Object? flowitAsFlow = null,
    Object? flowitKanban = null,
    Object? flowitOwner = freezed,
    Object? flowitTemplate = freezed,
    Object? calendarOrder = null,
    Object? organizer = freezed,
    Object? attendees = null,
    Object? categories = null,
  }) {
    return _then(_value.copyWith(
      path: null == path
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      supportsTodos: null == supportsTodos
          ? _value.supportsTodos
          : supportsTodos // ignore: cast_nullable_to_non_nullable
              as bool,
      etag: freezed == etag
          ? _value.etag
          : etag // ignore: cast_nullable_to_non_nullable
              as String?,
      color: freezed == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String?,
      lastSyncAt: freezed == lastSyncAt
          ? _value.lastSyncAt
          : lastSyncAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isReadOnly: null == isReadOnly
          ? _value.isReadOnly
          : isReadOnly // ignore: cast_nullable_to_non_nullable
              as bool,
      syncToken: freezed == syncToken
          ? _value.syncToken
          : syncToken // ignore: cast_nullable_to_non_nullable
              as String?,
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as String,
      dtstamp: null == dtstamp
          ? _value.dtstamp
          : dtstamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      created: null == created
          ? _value.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastModified: null == lastModified
          ? _value.lastModified
          : lastModified // ignore: cast_nullable_to_non_nullable
              as DateTime,
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      percentComplete: null == percentComplete
          ? _value.percentComplete
          : percentComplete // ignore: cast_nullable_to_non_nullable
              as int,
      flowitType: null == flowitType
          ? _value.flowitType
          : flowitType // ignore: cast_nullable_to_non_nullable
              as String,
      flowitAsFlow: null == flowitAsFlow
          ? _value.flowitAsFlow
          : flowitAsFlow // ignore: cast_nullable_to_non_nullable
              as bool,
      flowitKanban: null == flowitKanban
          ? _value.flowitKanban
          : flowitKanban // ignore: cast_nullable_to_non_nullable
              as String,
      flowitOwner: freezed == flowitOwner
          ? _value.flowitOwner
          : flowitOwner // ignore: cast_nullable_to_non_nullable
              as String?,
      flowitTemplate: freezed == flowitTemplate
          ? _value.flowitTemplate
          : flowitTemplate // ignore: cast_nullable_to_non_nullable
              as String?,
      calendarOrder: null == calendarOrder
          ? _value.calendarOrder
          : calendarOrder // ignore: cast_nullable_to_non_nullable
              as int,
      organizer: freezed == organizer
          ? _value.organizer
          : organizer // ignore: cast_nullable_to_non_nullable
              as String?,
      attendees: null == attendees
          ? _value.attendees
          : attendees // ignore: cast_nullable_to_non_nullable
              as List<Attendee>,
      categories: null == categories
          ? _value.categories
          : categories // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TaskCalendarImplCopyWith<$Res>
    implements $TaskCalendarCopyWith<$Res> {
  factory _$$TaskCalendarImplCopyWith(
          _$TaskCalendarImpl value, $Res Function(_$TaskCalendarImpl) then) =
      __$$TaskCalendarImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) String path,
      @HiveField(1) String displayName,
      @HiveField(2) String description,
      @HiveField(3) bool supportsTodos,
      @HiveField(4) String? etag,
      @HiveField(5) String? color,
      @HiveField(6) DateTime? lastSyncAt,
      @HiveField(7) bool isReadOnly,
      @HiveField(24) String? syncToken,
      @HiveField(8) String uid,
      @HiveField(9) DateTime dtstamp,
      @HiveField(10) DateTime created,
      @HiveField(11) DateTime lastModified,
      @HiveField(12) String summary,
      @HiveField(13) String status,
      @HiveField(14) int percentComplete,
      @HiveField(15) String flowitType,
      @HiveField(16) bool flowitAsFlow,
      @HiveField(17) String flowitKanban,
      @HiveField(18) String? flowitOwner,
      @HiveField(19) String? flowitTemplate,
      @HiveField(20) int calendarOrder,
      @HiveField(21) String? organizer,
      @HiveField(22) List<Attendee> attendees,
      @HiveField(23) List<String> categories});
}

/// @nodoc
class __$$TaskCalendarImplCopyWithImpl<$Res>
    extends _$TaskCalendarCopyWithImpl<$Res, _$TaskCalendarImpl>
    implements _$$TaskCalendarImplCopyWith<$Res> {
  __$$TaskCalendarImplCopyWithImpl(
      _$TaskCalendarImpl _value, $Res Function(_$TaskCalendarImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskCalendar
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? path = null,
    Object? displayName = null,
    Object? description = null,
    Object? supportsTodos = null,
    Object? etag = freezed,
    Object? color = freezed,
    Object? lastSyncAt = freezed,
    Object? isReadOnly = null,
    Object? syncToken = freezed,
    Object? uid = null,
    Object? dtstamp = null,
    Object? created = null,
    Object? lastModified = null,
    Object? summary = null,
    Object? status = null,
    Object? percentComplete = null,
    Object? flowitType = null,
    Object? flowitAsFlow = null,
    Object? flowitKanban = null,
    Object? flowitOwner = freezed,
    Object? flowitTemplate = freezed,
    Object? calendarOrder = null,
    Object? organizer = freezed,
    Object? attendees = null,
    Object? categories = null,
  }) {
    return _then(_$TaskCalendarImpl(
      path: null == path
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      supportsTodos: null == supportsTodos
          ? _value.supportsTodos
          : supportsTodos // ignore: cast_nullable_to_non_nullable
              as bool,
      etag: freezed == etag
          ? _value.etag
          : etag // ignore: cast_nullable_to_non_nullable
              as String?,
      color: freezed == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String?,
      lastSyncAt: freezed == lastSyncAt
          ? _value.lastSyncAt
          : lastSyncAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isReadOnly: null == isReadOnly
          ? _value.isReadOnly
          : isReadOnly // ignore: cast_nullable_to_non_nullable
              as bool,
      syncToken: freezed == syncToken
          ? _value.syncToken
          : syncToken // ignore: cast_nullable_to_non_nullable
              as String?,
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as String,
      dtstamp: null == dtstamp
          ? _value.dtstamp
          : dtstamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      created: null == created
          ? _value.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastModified: null == lastModified
          ? _value.lastModified
          : lastModified // ignore: cast_nullable_to_non_nullable
              as DateTime,
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      percentComplete: null == percentComplete
          ? _value.percentComplete
          : percentComplete // ignore: cast_nullable_to_non_nullable
              as int,
      flowitType: null == flowitType
          ? _value.flowitType
          : flowitType // ignore: cast_nullable_to_non_nullable
              as String,
      flowitAsFlow: null == flowitAsFlow
          ? _value.flowitAsFlow
          : flowitAsFlow // ignore: cast_nullable_to_non_nullable
              as bool,
      flowitKanban: null == flowitKanban
          ? _value.flowitKanban
          : flowitKanban // ignore: cast_nullable_to_non_nullable
              as String,
      flowitOwner: freezed == flowitOwner
          ? _value.flowitOwner
          : flowitOwner // ignore: cast_nullable_to_non_nullable
              as String?,
      flowitTemplate: freezed == flowitTemplate
          ? _value.flowitTemplate
          : flowitTemplate // ignore: cast_nullable_to_non_nullable
              as String?,
      calendarOrder: null == calendarOrder
          ? _value.calendarOrder
          : calendarOrder // ignore: cast_nullable_to_non_nullable
              as int,
      organizer: freezed == organizer
          ? _value.organizer
          : organizer // ignore: cast_nullable_to_non_nullable
              as String?,
      attendees: null == attendees
          ? _value._attendees
          : attendees // ignore: cast_nullable_to_non_nullable
              as List<Attendee>,
      categories: null == categories
          ? _value._categories
          : categories // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskCalendarImpl implements _TaskCalendar {
  const _$TaskCalendarImpl(
      {@HiveField(0) required this.path,
      @HiveField(1) required this.displayName,
      @HiveField(2) this.description = '',
      @HiveField(3) this.supportsTodos = true,
      @HiveField(4) this.etag,
      @HiveField(5) this.color,
      @HiveField(6) this.lastSyncAt,
      @HiveField(7) this.isReadOnly = false,
      @HiveField(24) this.syncToken,
      @HiveField(8) required this.uid,
      @HiveField(9) required this.dtstamp,
      @HiveField(10) required this.created,
      @HiveField(11) required this.lastModified,
      @HiveField(12) required this.summary,
      @HiveField(13) required this.status,
      @HiveField(14) this.percentComplete = 0,
      @HiveField(15) this.flowitType = 'PROJECT',
      @HiveField(16) this.flowitAsFlow = false,
      @HiveField(17) this.flowitKanban = '[]',
      @HiveField(18) this.flowitOwner,
      @HiveField(19) this.flowitTemplate,
      @HiveField(20) this.calendarOrder = 1,
      @HiveField(21) this.organizer,
      @HiveField(22) final List<Attendee> attendees = const [],
      @HiveField(23) final List<String> categories = const []})
      : _attendees = attendees,
        _categories = categories;

  factory _$TaskCalendarImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskCalendarImplFromJson(json);

// CalDAV server properties
  @override
  @HiveField(0)
  final String path;
  @override
  @HiveField(1)
  final String displayName;
  @override
  @JsonKey()
  @HiveField(2)
  final String description;
  @override
  @JsonKey()
  @HiveField(3)
  final bool supportsTodos;
  @override
  @HiveField(4)
  final String? etag;
  @override
  @HiveField(5)
  final String? color;
  @override
  @HiveField(6)
  final DateTime? lastSyncAt;
  @override
  @JsonKey()
  @HiveField(7)
  final bool isReadOnly;
  @override
  @HiveField(24)
  final String? syncToken;
// Required VCALENDAR properties for FlowIt projects
  @override
  @HiveField(8)
  final String uid;
  @override
  @HiveField(9)
  final DateTime dtstamp;
  @override
  @HiveField(10)
  final DateTime created;
  @override
  @HiveField(11)
  final DateTime lastModified;
  @override
  @HiveField(12)
  final String summary;
  @override
  @HiveField(13)
  final String status;
  @override
  @JsonKey()
  @HiveField(14)
  final int percentComplete;
// FlowIt-specific VCALENDAR properties
  @override
  @JsonKey()
  @HiveField(15)
  final String flowitType;
// X-FLOWIT-TYPE
  @override
  @JsonKey()
  @HiveField(16)
  final bool flowitAsFlow;
// X-FLOWIT-ASFLOW
  @override
  @JsonKey()
  @HiveField(17)
  final String flowitKanban;
// X-FLOWIT-KANBAN JSON array
  @override
  @HiveField(18)
  final String? flowitOwner;
// X-FLOWIT-OWNER
  @override
  @HiveField(19)
  final String? flowitTemplate;
// X-FLOWIT-TEMPLATE
  @override
  @JsonKey()
  @HiveField(20)
  final int calendarOrder;
// CALENDAR-ORDER
  @override
  @HiveField(21)
  final String? organizer;
// ORGANIZER
  final List<Attendee> _attendees;
// ORGANIZER
  @override
  @JsonKey()
  @HiveField(22)
  List<Attendee> get attendees {
    if (_attendees is EqualUnmodifiableListView) return _attendees;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attendees);
  }

// ATTENDEE
  final List<String> _categories;
// ATTENDEE
  @override
  @JsonKey()
  @HiveField(23)
  List<String> get categories {
    if (_categories is EqualUnmodifiableListView) return _categories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categories);
  }

  @override
  String toString() {
    return 'TaskCalendar(path: $path, displayName: $displayName, description: $description, supportsTodos: $supportsTodos, etag: $etag, color: $color, lastSyncAt: $lastSyncAt, isReadOnly: $isReadOnly, syncToken: $syncToken, uid: $uid, dtstamp: $dtstamp, created: $created, lastModified: $lastModified, summary: $summary, status: $status, percentComplete: $percentComplete, flowitType: $flowitType, flowitAsFlow: $flowitAsFlow, flowitKanban: $flowitKanban, flowitOwner: $flowitOwner, flowitTemplate: $flowitTemplate, calendarOrder: $calendarOrder, organizer: $organizer, attendees: $attendees, categories: $categories)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskCalendarImpl &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.supportsTodos, supportsTodos) ||
                other.supportsTodos == supportsTodos) &&
            (identical(other.etag, etag) || other.etag == etag) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.lastSyncAt, lastSyncAt) ||
                other.lastSyncAt == lastSyncAt) &&
            (identical(other.isReadOnly, isReadOnly) ||
                other.isReadOnly == isReadOnly) &&
            (identical(other.syncToken, syncToken) ||
                other.syncToken == syncToken) &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.dtstamp, dtstamp) || other.dtstamp == dtstamp) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.lastModified, lastModified) ||
                other.lastModified == lastModified) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.percentComplete, percentComplete) ||
                other.percentComplete == percentComplete) &&
            (identical(other.flowitType, flowitType) ||
                other.flowitType == flowitType) &&
            (identical(other.flowitAsFlow, flowitAsFlow) ||
                other.flowitAsFlow == flowitAsFlow) &&
            (identical(other.flowitKanban, flowitKanban) ||
                other.flowitKanban == flowitKanban) &&
            (identical(other.flowitOwner, flowitOwner) ||
                other.flowitOwner == flowitOwner) &&
            (identical(other.flowitTemplate, flowitTemplate) ||
                other.flowitTemplate == flowitTemplate) &&
            (identical(other.calendarOrder, calendarOrder) ||
                other.calendarOrder == calendarOrder) &&
            (identical(other.organizer, organizer) ||
                other.organizer == organizer) &&
            const DeepCollectionEquality()
                .equals(other._attendees, _attendees) &&
            const DeepCollectionEquality()
                .equals(other._categories, _categories));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        path,
        displayName,
        description,
        supportsTodos,
        etag,
        color,
        lastSyncAt,
        isReadOnly,
        syncToken,
        uid,
        dtstamp,
        created,
        lastModified,
        summary,
        status,
        percentComplete,
        flowitType,
        flowitAsFlow,
        flowitKanban,
        flowitOwner,
        flowitTemplate,
        calendarOrder,
        organizer,
        const DeepCollectionEquality().hash(_attendees),
        const DeepCollectionEquality().hash(_categories)
      ]);

  /// Create a copy of TaskCalendar
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskCalendarImplCopyWith<_$TaskCalendarImpl> get copyWith =>
      __$$TaskCalendarImplCopyWithImpl<_$TaskCalendarImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskCalendarImplToJson(
      this,
    );
  }
}

abstract class _TaskCalendar implements TaskCalendar {
  const factory _TaskCalendar(
      {@HiveField(0) required final String path,
      @HiveField(1) required final String displayName,
      @HiveField(2) final String description,
      @HiveField(3) final bool supportsTodos,
      @HiveField(4) final String? etag,
      @HiveField(5) final String? color,
      @HiveField(6) final DateTime? lastSyncAt,
      @HiveField(7) final bool isReadOnly,
      @HiveField(24) final String? syncToken,
      @HiveField(8) required final String uid,
      @HiveField(9) required final DateTime dtstamp,
      @HiveField(10) required final DateTime created,
      @HiveField(11) required final DateTime lastModified,
      @HiveField(12) required final String summary,
      @HiveField(13) required final String status,
      @HiveField(14) final int percentComplete,
      @HiveField(15) final String flowitType,
      @HiveField(16) final bool flowitAsFlow,
      @HiveField(17) final String flowitKanban,
      @HiveField(18) final String? flowitOwner,
      @HiveField(19) final String? flowitTemplate,
      @HiveField(20) final int calendarOrder,
      @HiveField(21) final String? organizer,
      @HiveField(22) final List<Attendee> attendees,
      @HiveField(23) final List<String> categories}) = _$TaskCalendarImpl;

  factory _TaskCalendar.fromJson(Map<String, dynamic> json) =
      _$TaskCalendarImpl.fromJson;

// CalDAV server properties
  @override
  @HiveField(0)
  String get path;
  @override
  @HiveField(1)
  String get displayName;
  @override
  @HiveField(2)
  String get description;
  @override
  @HiveField(3)
  bool get supportsTodos;
  @override
  @HiveField(4)
  String? get etag;
  @override
  @HiveField(5)
  String? get color;
  @override
  @HiveField(6)
  DateTime? get lastSyncAt;
  @override
  @HiveField(7)
  bool get isReadOnly;
  @override
  @HiveField(24)
  String? get syncToken; // Required VCALENDAR properties for FlowIt projects
  @override
  @HiveField(8)
  String get uid;
  @override
  @HiveField(9)
  DateTime get dtstamp;
  @override
  @HiveField(10)
  DateTime get created;
  @override
  @HiveField(11)
  DateTime get lastModified;
  @override
  @HiveField(12)
  String get summary;
  @override
  @HiveField(13)
  String get status;
  @override
  @HiveField(14)
  int get percentComplete; // FlowIt-specific VCALENDAR properties
  @override
  @HiveField(15)
  String get flowitType; // X-FLOWIT-TYPE
  @override
  @HiveField(16)
  bool get flowitAsFlow; // X-FLOWIT-ASFLOW
  @override
  @HiveField(17)
  String get flowitKanban; // X-FLOWIT-KANBAN JSON array
  @override
  @HiveField(18)
  String? get flowitOwner; // X-FLOWIT-OWNER
  @override
  @HiveField(19)
  String? get flowitTemplate; // X-FLOWIT-TEMPLATE
  @override
  @HiveField(20)
  int get calendarOrder; // CALENDAR-ORDER
  @override
  @HiveField(21)
  String? get organizer; // ORGANIZER
  @override
  @HiveField(22)
  List<Attendee> get attendees; // ATTENDEE
  @override
  @HiveField(23)
  List<String> get categories;

  /// Create a copy of TaskCalendar
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskCalendarImplCopyWith<_$TaskCalendarImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
