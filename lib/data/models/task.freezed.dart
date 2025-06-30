// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Task _$TaskFromJson(Map<String, dynamic> json) {
  return _Task.fromJson(json);
}

/// @nodoc
mixin _$Task {
  @HiveField(0)
  String get uid => throw _privateConstructorUsedError;
  @HiveField(1)
  String get summary => throw _privateConstructorUsedError;
  @HiveField(2)
  String get description => throw _privateConstructorUsedError;
  @HiveField(3)
  String get status => throw _privateConstructorUsedError;
  @HiveField(4)
  DateTime get lastModified => throw _privateConstructorUsedError;
  @HiveField(5)
  DateTime get created => throw _privateConstructorUsedError;
  @HiveField(6)
  DateTime get dtstamp =>
      throw _privateConstructorUsedError; // Required by iCalendar
  @HiveField(7)
  DateTime? get due => throw _privateConstructorUsedError;
  @HiveField(8)
  List<String> get categories => throw _privateConstructorUsedError;
  @HiveField(9)
  String? get organizer => throw _privateConstructorUsedError;
  @HiveField(10)
  List<Attendee> get attendees => throw _privateConstructorUsedError;
  @HiveField(11)
  int get percentComplete =>
      throw _privateConstructorUsedError; // Task-specific FlowIt fields
  @HiveField(12)
  String? get sourceCalendarUid =>
      throw _privateConstructorUsedError; // UID of source calendar (project)
  @HiveField(13)
  String? get flowitTemplate =>
      throw _privateConstructorUsedError; // UID of template
  @HiveField(14)
  String? get flowitReversalTask =>
      throw _privateConstructorUsedError; // UID of reversal task
  @HiveField(15)
  String get flowitValidator =>
      throw _privateConstructorUsedError; // JSON string
  @HiveField(16)
  String get flowitRequirement =>
      throw _privateConstructorUsedError; // JSON string
  @HiveField(17)
  String get flowitKanbanColumn => throw _privateConstructorUsedError;

  /// Serializes this Task to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskCopyWith<Task> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskCopyWith<$Res> {
  factory $TaskCopyWith(Task value, $Res Function(Task) then) =
      _$TaskCopyWithImpl<$Res, Task>;
  @useResult
  $Res call(
      {@HiveField(0) String uid,
      @HiveField(1) String summary,
      @HiveField(2) String description,
      @HiveField(3) String status,
      @HiveField(4) DateTime lastModified,
      @HiveField(5) DateTime created,
      @HiveField(6) DateTime dtstamp,
      @HiveField(7) DateTime? due,
      @HiveField(8) List<String> categories,
      @HiveField(9) String? organizer,
      @HiveField(10) List<Attendee> attendees,
      @HiveField(11) int percentComplete,
      @HiveField(12) String? sourceCalendarUid,
      @HiveField(13) String? flowitTemplate,
      @HiveField(14) String? flowitReversalTask,
      @HiveField(15) String flowitValidator,
      @HiveField(16) String flowitRequirement,
      @HiveField(17) String flowitKanbanColumn});
}

/// @nodoc
class _$TaskCopyWithImpl<$Res, $Val extends Task>
    implements $TaskCopyWith<$Res> {
  _$TaskCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? summary = null,
    Object? description = null,
    Object? status = null,
    Object? lastModified = null,
    Object? created = null,
    Object? dtstamp = null,
    Object? due = freezed,
    Object? categories = null,
    Object? organizer = freezed,
    Object? attendees = null,
    Object? percentComplete = null,
    Object? sourceCalendarUid = freezed,
    Object? flowitTemplate = freezed,
    Object? flowitReversalTask = freezed,
    Object? flowitValidator = null,
    Object? flowitRequirement = null,
    Object? flowitKanbanColumn = null,
  }) {
    return _then(_value.copyWith(
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as String,
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      lastModified: null == lastModified
          ? _value.lastModified
          : lastModified // ignore: cast_nullable_to_non_nullable
              as DateTime,
      created: null == created
          ? _value.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dtstamp: null == dtstamp
          ? _value.dtstamp
          : dtstamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      due: freezed == due
          ? _value.due
          : due // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      categories: null == categories
          ? _value.categories
          : categories // ignore: cast_nullable_to_non_nullable
              as List<String>,
      organizer: freezed == organizer
          ? _value.organizer
          : organizer // ignore: cast_nullable_to_non_nullable
              as String?,
      attendees: null == attendees
          ? _value.attendees
          : attendees // ignore: cast_nullable_to_non_nullable
              as List<Attendee>,
      percentComplete: null == percentComplete
          ? _value.percentComplete
          : percentComplete // ignore: cast_nullable_to_non_nullable
              as int,
      sourceCalendarUid: freezed == sourceCalendarUid
          ? _value.sourceCalendarUid
          : sourceCalendarUid // ignore: cast_nullable_to_non_nullable
              as String?,
      flowitTemplate: freezed == flowitTemplate
          ? _value.flowitTemplate
          : flowitTemplate // ignore: cast_nullable_to_non_nullable
              as String?,
      flowitReversalTask: freezed == flowitReversalTask
          ? _value.flowitReversalTask
          : flowitReversalTask // ignore: cast_nullable_to_non_nullable
              as String?,
      flowitValidator: null == flowitValidator
          ? _value.flowitValidator
          : flowitValidator // ignore: cast_nullable_to_non_nullable
              as String,
      flowitRequirement: null == flowitRequirement
          ? _value.flowitRequirement
          : flowitRequirement // ignore: cast_nullable_to_non_nullable
              as String,
      flowitKanbanColumn: null == flowitKanbanColumn
          ? _value.flowitKanbanColumn
          : flowitKanbanColumn // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TaskImplCopyWith<$Res> implements $TaskCopyWith<$Res> {
  factory _$$TaskImplCopyWith(
          _$TaskImpl value, $Res Function(_$TaskImpl) then) =
      __$$TaskImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) String uid,
      @HiveField(1) String summary,
      @HiveField(2) String description,
      @HiveField(3) String status,
      @HiveField(4) DateTime lastModified,
      @HiveField(5) DateTime created,
      @HiveField(6) DateTime dtstamp,
      @HiveField(7) DateTime? due,
      @HiveField(8) List<String> categories,
      @HiveField(9) String? organizer,
      @HiveField(10) List<Attendee> attendees,
      @HiveField(11) int percentComplete,
      @HiveField(12) String? sourceCalendarUid,
      @HiveField(13) String? flowitTemplate,
      @HiveField(14) String? flowitReversalTask,
      @HiveField(15) String flowitValidator,
      @HiveField(16) String flowitRequirement,
      @HiveField(17) String flowitKanbanColumn});
}

/// @nodoc
class __$$TaskImplCopyWithImpl<$Res>
    extends _$TaskCopyWithImpl<$Res, _$TaskImpl>
    implements _$$TaskImplCopyWith<$Res> {
  __$$TaskImplCopyWithImpl(_$TaskImpl _value, $Res Function(_$TaskImpl) _then)
      : super(_value, _then);

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? summary = null,
    Object? description = null,
    Object? status = null,
    Object? lastModified = null,
    Object? created = null,
    Object? dtstamp = null,
    Object? due = freezed,
    Object? categories = null,
    Object? organizer = freezed,
    Object? attendees = null,
    Object? percentComplete = null,
    Object? sourceCalendarUid = freezed,
    Object? flowitTemplate = freezed,
    Object? flowitReversalTask = freezed,
    Object? flowitValidator = null,
    Object? flowitRequirement = null,
    Object? flowitKanbanColumn = null,
  }) {
    return _then(_$TaskImpl(
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as String,
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      lastModified: null == lastModified
          ? _value.lastModified
          : lastModified // ignore: cast_nullable_to_non_nullable
              as DateTime,
      created: null == created
          ? _value.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dtstamp: null == dtstamp
          ? _value.dtstamp
          : dtstamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      due: freezed == due
          ? _value.due
          : due // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      categories: null == categories
          ? _value._categories
          : categories // ignore: cast_nullable_to_non_nullable
              as List<String>,
      organizer: freezed == organizer
          ? _value.organizer
          : organizer // ignore: cast_nullable_to_non_nullable
              as String?,
      attendees: null == attendees
          ? _value._attendees
          : attendees // ignore: cast_nullable_to_non_nullable
              as List<Attendee>,
      percentComplete: null == percentComplete
          ? _value.percentComplete
          : percentComplete // ignore: cast_nullable_to_non_nullable
              as int,
      sourceCalendarUid: freezed == sourceCalendarUid
          ? _value.sourceCalendarUid
          : sourceCalendarUid // ignore: cast_nullable_to_non_nullable
              as String?,
      flowitTemplate: freezed == flowitTemplate
          ? _value.flowitTemplate
          : flowitTemplate // ignore: cast_nullable_to_non_nullable
              as String?,
      flowitReversalTask: freezed == flowitReversalTask
          ? _value.flowitReversalTask
          : flowitReversalTask // ignore: cast_nullable_to_non_nullable
              as String?,
      flowitValidator: null == flowitValidator
          ? _value.flowitValidator
          : flowitValidator // ignore: cast_nullable_to_non_nullable
              as String,
      flowitRequirement: null == flowitRequirement
          ? _value.flowitRequirement
          : flowitRequirement // ignore: cast_nullable_to_non_nullable
              as String,
      flowitKanbanColumn: null == flowitKanbanColumn
          ? _value.flowitKanbanColumn
          : flowitKanbanColumn // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskImpl implements _Task {
  const _$TaskImpl(
      {@HiveField(0) required this.uid,
      @HiveField(1) required this.summary,
      @HiveField(2) required this.description,
      @HiveField(3) required this.status,
      @HiveField(4) required this.lastModified,
      @HiveField(5) required this.created,
      @HiveField(6) required this.dtstamp,
      @HiveField(7) this.due,
      @HiveField(8) final List<String> categories = const [],
      @HiveField(9) this.organizer,
      @HiveField(10) final List<Attendee> attendees = const [],
      @HiveField(11) this.percentComplete = 0,
      @HiveField(12) this.sourceCalendarUid,
      @HiveField(13) this.flowitTemplate,
      @HiveField(14) this.flowitReversalTask,
      @HiveField(15) this.flowitValidator = '{"type":"default"}',
      @HiveField(16) this.flowitRequirement = '{}',
      @HiveField(17) this.flowitKanbanColumn = '[]'})
      : _categories = categories,
        _attendees = attendees;

  factory _$TaskImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskImplFromJson(json);

  @override
  @HiveField(0)
  final String uid;
  @override
  @HiveField(1)
  final String summary;
  @override
  @HiveField(2)
  final String description;
  @override
  @HiveField(3)
  final String status;
  @override
  @HiveField(4)
  final DateTime lastModified;
  @override
  @HiveField(5)
  final DateTime created;
  @override
  @HiveField(6)
  final DateTime dtstamp;
// Required by iCalendar
  @override
  @HiveField(7)
  final DateTime? due;
  final List<String> _categories;
  @override
  @JsonKey()
  @HiveField(8)
  List<String> get categories {
    if (_categories is EqualUnmodifiableListView) return _categories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categories);
  }

  @override
  @HiveField(9)
  final String? organizer;
  final List<Attendee> _attendees;
  @override
  @JsonKey()
  @HiveField(10)
  List<Attendee> get attendees {
    if (_attendees is EqualUnmodifiableListView) return _attendees;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attendees);
  }

  @override
  @JsonKey()
  @HiveField(11)
  final int percentComplete;
// Task-specific FlowIt fields
  @override
  @HiveField(12)
  final String? sourceCalendarUid;
// UID of source calendar (project)
  @override
  @HiveField(13)
  final String? flowitTemplate;
// UID of template
  @override
  @HiveField(14)
  final String? flowitReversalTask;
// UID of reversal task
  @override
  @JsonKey()
  @HiveField(15)
  final String flowitValidator;
// JSON string
  @override
  @JsonKey()
  @HiveField(16)
  final String flowitRequirement;
// JSON string
  @override
  @JsonKey()
  @HiveField(17)
  final String flowitKanbanColumn;

  @override
  String toString() {
    return 'Task(uid: $uid, summary: $summary, description: $description, status: $status, lastModified: $lastModified, created: $created, dtstamp: $dtstamp, due: $due, categories: $categories, organizer: $organizer, attendees: $attendees, percentComplete: $percentComplete, sourceCalendarUid: $sourceCalendarUid, flowitTemplate: $flowitTemplate, flowitReversalTask: $flowitReversalTask, flowitValidator: $flowitValidator, flowitRequirement: $flowitRequirement, flowitKanbanColumn: $flowitKanbanColumn)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskImpl &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastModified, lastModified) ||
                other.lastModified == lastModified) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.dtstamp, dtstamp) || other.dtstamp == dtstamp) &&
            (identical(other.due, due) || other.due == due) &&
            const DeepCollectionEquality()
                .equals(other._categories, _categories) &&
            (identical(other.organizer, organizer) ||
                other.organizer == organizer) &&
            const DeepCollectionEquality()
                .equals(other._attendees, _attendees) &&
            (identical(other.percentComplete, percentComplete) ||
                other.percentComplete == percentComplete) &&
            (identical(other.sourceCalendarUid, sourceCalendarUid) ||
                other.sourceCalendarUid == sourceCalendarUid) &&
            (identical(other.flowitTemplate, flowitTemplate) ||
                other.flowitTemplate == flowitTemplate) &&
            (identical(other.flowitReversalTask, flowitReversalTask) ||
                other.flowitReversalTask == flowitReversalTask) &&
            (identical(other.flowitValidator, flowitValidator) ||
                other.flowitValidator == flowitValidator) &&
            (identical(other.flowitRequirement, flowitRequirement) ||
                other.flowitRequirement == flowitRequirement) &&
            (identical(other.flowitKanbanColumn, flowitKanbanColumn) ||
                other.flowitKanbanColumn == flowitKanbanColumn));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      uid,
      summary,
      description,
      status,
      lastModified,
      created,
      dtstamp,
      due,
      const DeepCollectionEquality().hash(_categories),
      organizer,
      const DeepCollectionEquality().hash(_attendees),
      percentComplete,
      sourceCalendarUid,
      flowitTemplate,
      flowitReversalTask,
      flowitValidator,
      flowitRequirement,
      flowitKanbanColumn);

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskImplCopyWith<_$TaskImpl> get copyWith =>
      __$$TaskImplCopyWithImpl<_$TaskImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskImplToJson(
      this,
    );
  }
}

abstract class _Task implements Task {
  const factory _Task(
      {@HiveField(0) required final String uid,
      @HiveField(1) required final String summary,
      @HiveField(2) required final String description,
      @HiveField(3) required final String status,
      @HiveField(4) required final DateTime lastModified,
      @HiveField(5) required final DateTime created,
      @HiveField(6) required final DateTime dtstamp,
      @HiveField(7) final DateTime? due,
      @HiveField(8) final List<String> categories,
      @HiveField(9) final String? organizer,
      @HiveField(10) final List<Attendee> attendees,
      @HiveField(11) final int percentComplete,
      @HiveField(12) final String? sourceCalendarUid,
      @HiveField(13) final String? flowitTemplate,
      @HiveField(14) final String? flowitReversalTask,
      @HiveField(15) final String flowitValidator,
      @HiveField(16) final String flowitRequirement,
      @HiveField(17) final String flowitKanbanColumn}) = _$TaskImpl;

  factory _Task.fromJson(Map<String, dynamic> json) = _$TaskImpl.fromJson;

  @override
  @HiveField(0)
  String get uid;
  @override
  @HiveField(1)
  String get summary;
  @override
  @HiveField(2)
  String get description;
  @override
  @HiveField(3)
  String get status;
  @override
  @HiveField(4)
  DateTime get lastModified;
  @override
  @HiveField(5)
  DateTime get created;
  @override
  @HiveField(6)
  DateTime get dtstamp; // Required by iCalendar
  @override
  @HiveField(7)
  DateTime? get due;
  @override
  @HiveField(8)
  List<String> get categories;
  @override
  @HiveField(9)
  String? get organizer;
  @override
  @HiveField(10)
  List<Attendee> get attendees;
  @override
  @HiveField(11)
  int get percentComplete; // Task-specific FlowIt fields
  @override
  @HiveField(12)
  String? get sourceCalendarUid; // UID of source calendar (project)
  @override
  @HiveField(13)
  String? get flowitTemplate; // UID of template
  @override
  @HiveField(14)
  String? get flowitReversalTask; // UID of reversal task
  @override
  @HiveField(15)
  String get flowitValidator; // JSON string
  @override
  @HiveField(16)
  String get flowitRequirement; // JSON string
  @override
  @HiveField(17)
  String get flowitKanbanColumn;

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskImplCopyWith<_$TaskImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
