// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'automated_task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AutomatedTask _$AutomatedTaskFromJson(Map<String, dynamic> json) {
  return _AutomatedTask.fromJson(json);
}

/// @nodoc
mixin _$AutomatedTask {
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
  List<String> get categories => throw _privateConstructorUsedError;
  @HiveField(8)
  String? get organizer => throw _privateConstructorUsedError;
  @HiveField(9)
  List<Attendee> get attendees => throw _privateConstructorUsedError;
  @HiveField(10)
  int get percentComplete =>
      throw _privateConstructorUsedError; // Automated task-specific FlowIt fields
  @HiveField(11)
  String? get flowitProcess =>
      throw _privateConstructorUsedError; // UID of parent project
  @HiveField(12)
  String? get flowitTemplate =>
      throw _privateConstructorUsedError; // UID of template
  @HiveField(13)
  String? get flowitReversalTask =>
      throw _privateConstructorUsedError; // UID of reversal task
  @HiveField(14)
  String get flowitValidator =>
      throw _privateConstructorUsedError; // JSON string
  @HiveField(15)
  String get flowitRequirement =>
      throw _privateConstructorUsedError; // JSON string
  @HiveField(16)
  String get flowitAutomate =>
      throw _privateConstructorUsedError; // JSON string
  @HiveField(17)
  String get flowitContext => throw _privateConstructorUsedError;

  /// Serializes this AutomatedTask to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AutomatedTask
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AutomatedTaskCopyWith<AutomatedTask> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AutomatedTaskCopyWith<$Res> {
  factory $AutomatedTaskCopyWith(
          AutomatedTask value, $Res Function(AutomatedTask) then) =
      _$AutomatedTaskCopyWithImpl<$Res, AutomatedTask>;
  @useResult
  $Res call(
      {@HiveField(0) String uid,
      @HiveField(1) String summary,
      @HiveField(2) String description,
      @HiveField(3) String status,
      @HiveField(4) DateTime lastModified,
      @HiveField(5) DateTime created,
      @HiveField(6) DateTime dtstamp,
      @HiveField(7) List<String> categories,
      @HiveField(8) String? organizer,
      @HiveField(9) List<Attendee> attendees,
      @HiveField(10) int percentComplete,
      @HiveField(11) String? flowitProcess,
      @HiveField(12) String? flowitTemplate,
      @HiveField(13) String? flowitReversalTask,
      @HiveField(14) String flowitValidator,
      @HiveField(15) String flowitRequirement,
      @HiveField(16) String flowitAutomate,
      @HiveField(17) String flowitContext});
}

/// @nodoc
class _$AutomatedTaskCopyWithImpl<$Res, $Val extends AutomatedTask>
    implements $AutomatedTaskCopyWith<$Res> {
  _$AutomatedTaskCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AutomatedTask
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
    Object? categories = null,
    Object? organizer = freezed,
    Object? attendees = null,
    Object? percentComplete = null,
    Object? flowitProcess = freezed,
    Object? flowitTemplate = freezed,
    Object? flowitReversalTask = freezed,
    Object? flowitValidator = null,
    Object? flowitRequirement = null,
    Object? flowitAutomate = null,
    Object? flowitContext = null,
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
      flowitProcess: freezed == flowitProcess
          ? _value.flowitProcess
          : flowitProcess // ignore: cast_nullable_to_non_nullable
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
      flowitAutomate: null == flowitAutomate
          ? _value.flowitAutomate
          : flowitAutomate // ignore: cast_nullable_to_non_nullable
              as String,
      flowitContext: null == flowitContext
          ? _value.flowitContext
          : flowitContext // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AutomatedTaskImplCopyWith<$Res>
    implements $AutomatedTaskCopyWith<$Res> {
  factory _$$AutomatedTaskImplCopyWith(
          _$AutomatedTaskImpl value, $Res Function(_$AutomatedTaskImpl) then) =
      __$$AutomatedTaskImplCopyWithImpl<$Res>;
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
      @HiveField(7) List<String> categories,
      @HiveField(8) String? organizer,
      @HiveField(9) List<Attendee> attendees,
      @HiveField(10) int percentComplete,
      @HiveField(11) String? flowitProcess,
      @HiveField(12) String? flowitTemplate,
      @HiveField(13) String? flowitReversalTask,
      @HiveField(14) String flowitValidator,
      @HiveField(15) String flowitRequirement,
      @HiveField(16) String flowitAutomate,
      @HiveField(17) String flowitContext});
}

/// @nodoc
class __$$AutomatedTaskImplCopyWithImpl<$Res>
    extends _$AutomatedTaskCopyWithImpl<$Res, _$AutomatedTaskImpl>
    implements _$$AutomatedTaskImplCopyWith<$Res> {
  __$$AutomatedTaskImplCopyWithImpl(
      _$AutomatedTaskImpl _value, $Res Function(_$AutomatedTaskImpl) _then)
      : super(_value, _then);

  /// Create a copy of AutomatedTask
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
    Object? categories = null,
    Object? organizer = freezed,
    Object? attendees = null,
    Object? percentComplete = null,
    Object? flowitProcess = freezed,
    Object? flowitTemplate = freezed,
    Object? flowitReversalTask = freezed,
    Object? flowitValidator = null,
    Object? flowitRequirement = null,
    Object? flowitAutomate = null,
    Object? flowitContext = null,
  }) {
    return _then(_$AutomatedTaskImpl(
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
      flowitProcess: freezed == flowitProcess
          ? _value.flowitProcess
          : flowitProcess // ignore: cast_nullable_to_non_nullable
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
      flowitAutomate: null == flowitAutomate
          ? _value.flowitAutomate
          : flowitAutomate // ignore: cast_nullable_to_non_nullable
              as String,
      flowitContext: null == flowitContext
          ? _value.flowitContext
          : flowitContext // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AutomatedTaskImpl implements _AutomatedTask {
  const _$AutomatedTaskImpl(
      {@HiveField(0) required this.uid,
      @HiveField(1) required this.summary,
      @HiveField(2) required this.description,
      @HiveField(3) required this.status,
      @HiveField(4) required this.lastModified,
      @HiveField(5) required this.created,
      @HiveField(6) required this.dtstamp,
      @HiveField(7) final List<String> categories = const [],
      @HiveField(8) this.organizer,
      @HiveField(9) final List<Attendee> attendees = const [],
      @HiveField(10) this.percentComplete = 0,
      @HiveField(11) this.flowitProcess,
      @HiveField(12) this.flowitTemplate,
      @HiveField(13) this.flowitReversalTask,
      @HiveField(14) this.flowitValidator = '{"type":"default"}',
      @HiveField(15) this.flowitRequirement = '{}',
      @HiveField(16) this.flowitAutomate = '{}',
      @HiveField(17) this.flowitContext = '{}'})
      : _categories = categories,
        _attendees = attendees;

  factory _$AutomatedTaskImpl.fromJson(Map<String, dynamic> json) =>
      _$$AutomatedTaskImplFromJson(json);

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
  final List<String> _categories;
// Required by iCalendar
  @override
  @JsonKey()
  @HiveField(7)
  List<String> get categories {
    if (_categories is EqualUnmodifiableListView) return _categories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categories);
  }

  @override
  @HiveField(8)
  final String? organizer;
  final List<Attendee> _attendees;
  @override
  @JsonKey()
  @HiveField(9)
  List<Attendee> get attendees {
    if (_attendees is EqualUnmodifiableListView) return _attendees;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attendees);
  }

  @override
  @JsonKey()
  @HiveField(10)
  final int percentComplete;
// Automated task-specific FlowIt fields
  @override
  @HiveField(11)
  final String? flowitProcess;
// UID of parent project
  @override
  @HiveField(12)
  final String? flowitTemplate;
// UID of template
  @override
  @HiveField(13)
  final String? flowitReversalTask;
// UID of reversal task
  @override
  @JsonKey()
  @HiveField(14)
  final String flowitValidator;
// JSON string
  @override
  @JsonKey()
  @HiveField(15)
  final String flowitRequirement;
// JSON string
  @override
  @JsonKey()
  @HiveField(16)
  final String flowitAutomate;
// JSON string
  @override
  @JsonKey()
  @HiveField(17)
  final String flowitContext;

  @override
  String toString() {
    return 'AutomatedTask(uid: $uid, summary: $summary, description: $description, status: $status, lastModified: $lastModified, created: $created, dtstamp: $dtstamp, categories: $categories, organizer: $organizer, attendees: $attendees, percentComplete: $percentComplete, flowitProcess: $flowitProcess, flowitTemplate: $flowitTemplate, flowitReversalTask: $flowitReversalTask, flowitValidator: $flowitValidator, flowitRequirement: $flowitRequirement, flowitAutomate: $flowitAutomate, flowitContext: $flowitContext)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AutomatedTaskImpl &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastModified, lastModified) ||
                other.lastModified == lastModified) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.dtstamp, dtstamp) || other.dtstamp == dtstamp) &&
            const DeepCollectionEquality()
                .equals(other._categories, _categories) &&
            (identical(other.organizer, organizer) ||
                other.organizer == organizer) &&
            const DeepCollectionEquality()
                .equals(other._attendees, _attendees) &&
            (identical(other.percentComplete, percentComplete) ||
                other.percentComplete == percentComplete) &&
            (identical(other.flowitProcess, flowitProcess) ||
                other.flowitProcess == flowitProcess) &&
            (identical(other.flowitTemplate, flowitTemplate) ||
                other.flowitTemplate == flowitTemplate) &&
            (identical(other.flowitReversalTask, flowitReversalTask) ||
                other.flowitReversalTask == flowitReversalTask) &&
            (identical(other.flowitValidator, flowitValidator) ||
                other.flowitValidator == flowitValidator) &&
            (identical(other.flowitRequirement, flowitRequirement) ||
                other.flowitRequirement == flowitRequirement) &&
            (identical(other.flowitAutomate, flowitAutomate) ||
                other.flowitAutomate == flowitAutomate) &&
            (identical(other.flowitContext, flowitContext) ||
                other.flowitContext == flowitContext));
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
      const DeepCollectionEquality().hash(_categories),
      organizer,
      const DeepCollectionEquality().hash(_attendees),
      percentComplete,
      flowitProcess,
      flowitTemplate,
      flowitReversalTask,
      flowitValidator,
      flowitRequirement,
      flowitAutomate,
      flowitContext);

  /// Create a copy of AutomatedTask
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AutomatedTaskImplCopyWith<_$AutomatedTaskImpl> get copyWith =>
      __$$AutomatedTaskImplCopyWithImpl<_$AutomatedTaskImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AutomatedTaskImplToJson(
      this,
    );
  }
}

abstract class _AutomatedTask implements AutomatedTask {
  const factory _AutomatedTask(
      {@HiveField(0) required final String uid,
      @HiveField(1) required final String summary,
      @HiveField(2) required final String description,
      @HiveField(3) required final String status,
      @HiveField(4) required final DateTime lastModified,
      @HiveField(5) required final DateTime created,
      @HiveField(6) required final DateTime dtstamp,
      @HiveField(7) final List<String> categories,
      @HiveField(8) final String? organizer,
      @HiveField(9) final List<Attendee> attendees,
      @HiveField(10) final int percentComplete,
      @HiveField(11) final String? flowitProcess,
      @HiveField(12) final String? flowitTemplate,
      @HiveField(13) final String? flowitReversalTask,
      @HiveField(14) final String flowitValidator,
      @HiveField(15) final String flowitRequirement,
      @HiveField(16) final String flowitAutomate,
      @HiveField(17) final String flowitContext}) = _$AutomatedTaskImpl;

  factory _AutomatedTask.fromJson(Map<String, dynamic> json) =
      _$AutomatedTaskImpl.fromJson;

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
  List<String> get categories;
  @override
  @HiveField(8)
  String? get organizer;
  @override
  @HiveField(9)
  List<Attendee> get attendees;
  @override
  @HiveField(10)
  int get percentComplete; // Automated task-specific FlowIt fields
  @override
  @HiveField(11)
  String? get flowitProcess; // UID of parent project
  @override
  @HiveField(12)
  String? get flowitTemplate; // UID of template
  @override
  @HiveField(13)
  String? get flowitReversalTask; // UID of reversal task
  @override
  @HiveField(14)
  String get flowitValidator; // JSON string
  @override
  @HiveField(15)
  String get flowitRequirement; // JSON string
  @override
  @HiveField(16)
  String get flowitAutomate; // JSON string
  @override
  @HiveField(17)
  String get flowitContext;

  /// Create a copy of AutomatedTask
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AutomatedTaskImplCopyWith<_$AutomatedTaskImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
