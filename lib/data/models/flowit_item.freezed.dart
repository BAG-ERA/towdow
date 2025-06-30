// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'flowit_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

FlowitItem _$FlowitItemFromJson(Map<String, dynamic> json) {
  return _FlowitItem.fromJson(json);
}

/// @nodoc
mixin _$FlowitItem {
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
  DateTime? get due => throw _privateConstructorUsedError;
  @HiveField(7)
  List<String> get categories => throw _privateConstructorUsedError;
  @HiveField(8)
  String? get organizer => throw _privateConstructorUsedError;
  @HiveField(9)
  List<String> get attendees => throw _privateConstructorUsedError;
  @HiveField(10)
  int get percentComplete =>
      throw _privateConstructorUsedError; // FlowIt-specific fields
  @HiveField(11)
  String get flowitType =>
      throw _privateConstructorUsedError; // project, task, automated-task
  @HiveField(12)
  String? get flowitProcess =>
      throw _privateConstructorUsedError; // UID of parent project/flow
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
  String get flowitContext => throw _privateConstructorUsedError; // JSON string
  @HiveField(18)
  String get flowitAutomate =>
      throw _privateConstructorUsedError; // JSON string (automated-task only)
  @HiveField(19)
  String get flowitKanban =>
      throw _privateConstructorUsedError; // JSON array (project only)
  @HiveField(20)
  String get flowitKanbanColumn =>
      throw _privateConstructorUsedError; // JSON array (task only)
  @HiveField(21)
  bool get flowitAsFlow => throw _privateConstructorUsedError;

  /// Serializes this FlowitItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FlowitItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FlowitItemCopyWith<FlowitItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FlowitItemCopyWith<$Res> {
  factory $FlowitItemCopyWith(
          FlowitItem value, $Res Function(FlowitItem) then) =
      _$FlowitItemCopyWithImpl<$Res, FlowitItem>;
  @useResult
  $Res call(
      {@HiveField(0) String uid,
      @HiveField(1) String summary,
      @HiveField(2) String description,
      @HiveField(3) String status,
      @HiveField(4) DateTime lastModified,
      @HiveField(5) DateTime created,
      @HiveField(6) DateTime? due,
      @HiveField(7) List<String> categories,
      @HiveField(8) String? organizer,
      @HiveField(9) List<String> attendees,
      @HiveField(10) int percentComplete,
      @HiveField(11) String flowitType,
      @HiveField(12) String? flowitProcess,
      @HiveField(13) String? flowitTemplate,
      @HiveField(14) String? flowitReversalTask,
      @HiveField(15) String flowitValidator,
      @HiveField(16) String flowitRequirement,
      @HiveField(17) String flowitContext,
      @HiveField(18) String flowitAutomate,
      @HiveField(19) String flowitKanban,
      @HiveField(20) String flowitKanbanColumn,
      @HiveField(21) bool flowitAsFlow});
}

/// @nodoc
class _$FlowitItemCopyWithImpl<$Res, $Val extends FlowitItem>
    implements $FlowitItemCopyWith<$Res> {
  _$FlowitItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FlowitItem
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
    Object? due = freezed,
    Object? categories = null,
    Object? organizer = freezed,
    Object? attendees = null,
    Object? percentComplete = null,
    Object? flowitType = null,
    Object? flowitProcess = freezed,
    Object? flowitTemplate = freezed,
    Object? flowitReversalTask = freezed,
    Object? flowitValidator = null,
    Object? flowitRequirement = null,
    Object? flowitContext = null,
    Object? flowitAutomate = null,
    Object? flowitKanban = null,
    Object? flowitKanbanColumn = null,
    Object? flowitAsFlow = null,
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
              as List<String>,
      percentComplete: null == percentComplete
          ? _value.percentComplete
          : percentComplete // ignore: cast_nullable_to_non_nullable
              as int,
      flowitType: null == flowitType
          ? _value.flowitType
          : flowitType // ignore: cast_nullable_to_non_nullable
              as String,
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
      flowitContext: null == flowitContext
          ? _value.flowitContext
          : flowitContext // ignore: cast_nullable_to_non_nullable
              as String,
      flowitAutomate: null == flowitAutomate
          ? _value.flowitAutomate
          : flowitAutomate // ignore: cast_nullable_to_non_nullable
              as String,
      flowitKanban: null == flowitKanban
          ? _value.flowitKanban
          : flowitKanban // ignore: cast_nullable_to_non_nullable
              as String,
      flowitKanbanColumn: null == flowitKanbanColumn
          ? _value.flowitKanbanColumn
          : flowitKanbanColumn // ignore: cast_nullable_to_non_nullable
              as String,
      flowitAsFlow: null == flowitAsFlow
          ? _value.flowitAsFlow
          : flowitAsFlow // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FlowitItemImplCopyWith<$Res>
    implements $FlowitItemCopyWith<$Res> {
  factory _$$FlowitItemImplCopyWith(
          _$FlowitItemImpl value, $Res Function(_$FlowitItemImpl) then) =
      __$$FlowitItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) String uid,
      @HiveField(1) String summary,
      @HiveField(2) String description,
      @HiveField(3) String status,
      @HiveField(4) DateTime lastModified,
      @HiveField(5) DateTime created,
      @HiveField(6) DateTime? due,
      @HiveField(7) List<String> categories,
      @HiveField(8) String? organizer,
      @HiveField(9) List<String> attendees,
      @HiveField(10) int percentComplete,
      @HiveField(11) String flowitType,
      @HiveField(12) String? flowitProcess,
      @HiveField(13) String? flowitTemplate,
      @HiveField(14) String? flowitReversalTask,
      @HiveField(15) String flowitValidator,
      @HiveField(16) String flowitRequirement,
      @HiveField(17) String flowitContext,
      @HiveField(18) String flowitAutomate,
      @HiveField(19) String flowitKanban,
      @HiveField(20) String flowitKanbanColumn,
      @HiveField(21) bool flowitAsFlow});
}

/// @nodoc
class __$$FlowitItemImplCopyWithImpl<$Res>
    extends _$FlowitItemCopyWithImpl<$Res, _$FlowitItemImpl>
    implements _$$FlowitItemImplCopyWith<$Res> {
  __$$FlowitItemImplCopyWithImpl(
      _$FlowitItemImpl _value, $Res Function(_$FlowitItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlowitItem
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
    Object? due = freezed,
    Object? categories = null,
    Object? organizer = freezed,
    Object? attendees = null,
    Object? percentComplete = null,
    Object? flowitType = null,
    Object? flowitProcess = freezed,
    Object? flowitTemplate = freezed,
    Object? flowitReversalTask = freezed,
    Object? flowitValidator = null,
    Object? flowitRequirement = null,
    Object? flowitContext = null,
    Object? flowitAutomate = null,
    Object? flowitKanban = null,
    Object? flowitKanbanColumn = null,
    Object? flowitAsFlow = null,
  }) {
    return _then(_$FlowitItemImpl(
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
              as List<String>,
      percentComplete: null == percentComplete
          ? _value.percentComplete
          : percentComplete // ignore: cast_nullable_to_non_nullable
              as int,
      flowitType: null == flowitType
          ? _value.flowitType
          : flowitType // ignore: cast_nullable_to_non_nullable
              as String,
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
      flowitContext: null == flowitContext
          ? _value.flowitContext
          : flowitContext // ignore: cast_nullable_to_non_nullable
              as String,
      flowitAutomate: null == flowitAutomate
          ? _value.flowitAutomate
          : flowitAutomate // ignore: cast_nullable_to_non_nullable
              as String,
      flowitKanban: null == flowitKanban
          ? _value.flowitKanban
          : flowitKanban // ignore: cast_nullable_to_non_nullable
              as String,
      flowitKanbanColumn: null == flowitKanbanColumn
          ? _value.flowitKanbanColumn
          : flowitKanbanColumn // ignore: cast_nullable_to_non_nullable
              as String,
      flowitAsFlow: null == flowitAsFlow
          ? _value.flowitAsFlow
          : flowitAsFlow // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FlowitItemImpl implements _FlowitItem {
  const _$FlowitItemImpl(
      {@HiveField(0) required this.uid,
      @HiveField(1) required this.summary,
      @HiveField(2) required this.description,
      @HiveField(3) required this.status,
      @HiveField(4) required this.lastModified,
      @HiveField(5) required this.created,
      @HiveField(6) this.due,
      @HiveField(7) final List<String> categories = const [],
      @HiveField(8) this.organizer,
      @HiveField(9) final List<String> attendees = const [],
      @HiveField(10) this.percentComplete = 0,
      @HiveField(11) required this.flowitType,
      @HiveField(12) this.flowitProcess,
      @HiveField(13) this.flowitTemplate,
      @HiveField(14) this.flowitReversalTask,
      @HiveField(15) this.flowitValidator = '{}',
      @HiveField(16) this.flowitRequirement = '{}',
      @HiveField(17) this.flowitContext = '{}',
      @HiveField(18) this.flowitAutomate = '{}',
      @HiveField(19) this.flowitKanban = '[]',
      @HiveField(20) this.flowitKanbanColumn = '[]',
      @HiveField(21) this.flowitAsFlow = false})
      : _categories = categories,
        _attendees = attendees;

  factory _$FlowitItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$FlowitItemImplFromJson(json);

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
  final DateTime? due;
  final List<String> _categories;
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
  final List<String> _attendees;
  @override
  @JsonKey()
  @HiveField(9)
  List<String> get attendees {
    if (_attendees is EqualUnmodifiableListView) return _attendees;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attendees);
  }

  @override
  @JsonKey()
  @HiveField(10)
  final int percentComplete;
// FlowIt-specific fields
  @override
  @HiveField(11)
  final String flowitType;
// project, task, automated-task
  @override
  @HiveField(12)
  final String? flowitProcess;
// UID of parent project/flow
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
  final String flowitContext;
// JSON string
  @override
  @JsonKey()
  @HiveField(18)
  final String flowitAutomate;
// JSON string (automated-task only)
  @override
  @JsonKey()
  @HiveField(19)
  final String flowitKanban;
// JSON array (project only)
  @override
  @JsonKey()
  @HiveField(20)
  final String flowitKanbanColumn;
// JSON array (task only)
  @override
  @JsonKey()
  @HiveField(21)
  final bool flowitAsFlow;

  @override
  String toString() {
    return 'FlowitItem(uid: $uid, summary: $summary, description: $description, status: $status, lastModified: $lastModified, created: $created, due: $due, categories: $categories, organizer: $organizer, attendees: $attendees, percentComplete: $percentComplete, flowitType: $flowitType, flowitProcess: $flowitProcess, flowitTemplate: $flowitTemplate, flowitReversalTask: $flowitReversalTask, flowitValidator: $flowitValidator, flowitRequirement: $flowitRequirement, flowitContext: $flowitContext, flowitAutomate: $flowitAutomate, flowitKanban: $flowitKanban, flowitKanbanColumn: $flowitKanbanColumn, flowitAsFlow: $flowitAsFlow)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlowitItemImpl &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastModified, lastModified) ||
                other.lastModified == lastModified) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.due, due) || other.due == due) &&
            const DeepCollectionEquality()
                .equals(other._categories, _categories) &&
            (identical(other.organizer, organizer) ||
                other.organizer == organizer) &&
            const DeepCollectionEquality()
                .equals(other._attendees, _attendees) &&
            (identical(other.percentComplete, percentComplete) ||
                other.percentComplete == percentComplete) &&
            (identical(other.flowitType, flowitType) ||
                other.flowitType == flowitType) &&
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
            (identical(other.flowitContext, flowitContext) ||
                other.flowitContext == flowitContext) &&
            (identical(other.flowitAutomate, flowitAutomate) ||
                other.flowitAutomate == flowitAutomate) &&
            (identical(other.flowitKanban, flowitKanban) ||
                other.flowitKanban == flowitKanban) &&
            (identical(other.flowitKanbanColumn, flowitKanbanColumn) ||
                other.flowitKanbanColumn == flowitKanbanColumn) &&
            (identical(other.flowitAsFlow, flowitAsFlow) ||
                other.flowitAsFlow == flowitAsFlow));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        uid,
        summary,
        description,
        status,
        lastModified,
        created,
        due,
        const DeepCollectionEquality().hash(_categories),
        organizer,
        const DeepCollectionEquality().hash(_attendees),
        percentComplete,
        flowitType,
        flowitProcess,
        flowitTemplate,
        flowitReversalTask,
        flowitValidator,
        flowitRequirement,
        flowitContext,
        flowitAutomate,
        flowitKanban,
        flowitKanbanColumn,
        flowitAsFlow
      ]);

  /// Create a copy of FlowitItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlowitItemImplCopyWith<_$FlowitItemImpl> get copyWith =>
      __$$FlowitItemImplCopyWithImpl<_$FlowitItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FlowitItemImplToJson(
      this,
    );
  }
}

abstract class _FlowitItem implements FlowitItem {
  const factory _FlowitItem(
      {@HiveField(0) required final String uid,
      @HiveField(1) required final String summary,
      @HiveField(2) required final String description,
      @HiveField(3) required final String status,
      @HiveField(4) required final DateTime lastModified,
      @HiveField(5) required final DateTime created,
      @HiveField(6) final DateTime? due,
      @HiveField(7) final List<String> categories,
      @HiveField(8) final String? organizer,
      @HiveField(9) final List<String> attendees,
      @HiveField(10) final int percentComplete,
      @HiveField(11) required final String flowitType,
      @HiveField(12) final String? flowitProcess,
      @HiveField(13) final String? flowitTemplate,
      @HiveField(14) final String? flowitReversalTask,
      @HiveField(15) final String flowitValidator,
      @HiveField(16) final String flowitRequirement,
      @HiveField(17) final String flowitContext,
      @HiveField(18) final String flowitAutomate,
      @HiveField(19) final String flowitKanban,
      @HiveField(20) final String flowitKanbanColumn,
      @HiveField(21) final bool flowitAsFlow}) = _$FlowitItemImpl;

  factory _FlowitItem.fromJson(Map<String, dynamic> json) =
      _$FlowitItemImpl.fromJson;

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
  DateTime? get due;
  @override
  @HiveField(7)
  List<String> get categories;
  @override
  @HiveField(8)
  String? get organizer;
  @override
  @HiveField(9)
  List<String> get attendees;
  @override
  @HiveField(10)
  int get percentComplete; // FlowIt-specific fields
  @override
  @HiveField(11)
  String get flowitType; // project, task, automated-task
  @override
  @HiveField(12)
  String? get flowitProcess; // UID of parent project/flow
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
  String get flowitContext; // JSON string
  @override
  @HiveField(18)
  String get flowitAutomate; // JSON string (automated-task only)
  @override
  @HiveField(19)
  String get flowitKanban; // JSON array (project only)
  @override
  @HiveField(20)
  String get flowitKanbanColumn; // JSON array (task only)
  @override
  @HiveField(21)
  bool get flowitAsFlow;

  /// Create a copy of FlowitItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlowitItemImplCopyWith<_$FlowitItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
