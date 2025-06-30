// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'validator.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

FormQuestion _$FormQuestionFromJson(Map<String, dynamic> json) {
  return _FormQuestion.fromJson(json);
}

/// @nodoc
mixin _$FormQuestion {
  @HiveField(0)
  String get questionId => throw _privateConstructorUsedError;
  @HiveField(1)
  FormQuestionType get questionType => throw _privateConstructorUsedError;
  @HiveField(2)
  String get questionText => throw _privateConstructorUsedError;
  @HiveField(3)
  bool get mandatory => throw _privateConstructorUsedError;
  @HiveField(4)
  List<String> get questionOptions => throw _privateConstructorUsedError;

  /// Serializes this FormQuestion to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FormQuestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FormQuestionCopyWith<FormQuestion> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FormQuestionCopyWith<$Res> {
  factory $FormQuestionCopyWith(
          FormQuestion value, $Res Function(FormQuestion) then) =
      _$FormQuestionCopyWithImpl<$Res, FormQuestion>;
  @useResult
  $Res call(
      {@HiveField(0) String questionId,
      @HiveField(1) FormQuestionType questionType,
      @HiveField(2) String questionText,
      @HiveField(3) bool mandatory,
      @HiveField(4) List<String> questionOptions});
}

/// @nodoc
class _$FormQuestionCopyWithImpl<$Res, $Val extends FormQuestion>
    implements $FormQuestionCopyWith<$Res> {
  _$FormQuestionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FormQuestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? questionId = null,
    Object? questionType = null,
    Object? questionText = null,
    Object? mandatory = null,
    Object? questionOptions = null,
  }) {
    return _then(_value.copyWith(
      questionId: null == questionId
          ? _value.questionId
          : questionId // ignore: cast_nullable_to_non_nullable
              as String,
      questionType: null == questionType
          ? _value.questionType
          : questionType // ignore: cast_nullable_to_non_nullable
              as FormQuestionType,
      questionText: null == questionText
          ? _value.questionText
          : questionText // ignore: cast_nullable_to_non_nullable
              as String,
      mandatory: null == mandatory
          ? _value.mandatory
          : mandatory // ignore: cast_nullable_to_non_nullable
              as bool,
      questionOptions: null == questionOptions
          ? _value.questionOptions
          : questionOptions // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FormQuestionImplCopyWith<$Res>
    implements $FormQuestionCopyWith<$Res> {
  factory _$$FormQuestionImplCopyWith(
          _$FormQuestionImpl value, $Res Function(_$FormQuestionImpl) then) =
      __$$FormQuestionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) String questionId,
      @HiveField(1) FormQuestionType questionType,
      @HiveField(2) String questionText,
      @HiveField(3) bool mandatory,
      @HiveField(4) List<String> questionOptions});
}

/// @nodoc
class __$$FormQuestionImplCopyWithImpl<$Res>
    extends _$FormQuestionCopyWithImpl<$Res, _$FormQuestionImpl>
    implements _$$FormQuestionImplCopyWith<$Res> {
  __$$FormQuestionImplCopyWithImpl(
      _$FormQuestionImpl _value, $Res Function(_$FormQuestionImpl) _then)
      : super(_value, _then);

  /// Create a copy of FormQuestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? questionId = null,
    Object? questionType = null,
    Object? questionText = null,
    Object? mandatory = null,
    Object? questionOptions = null,
  }) {
    return _then(_$FormQuestionImpl(
      questionId: null == questionId
          ? _value.questionId
          : questionId // ignore: cast_nullable_to_non_nullable
              as String,
      questionType: null == questionType
          ? _value.questionType
          : questionType // ignore: cast_nullable_to_non_nullable
              as FormQuestionType,
      questionText: null == questionText
          ? _value.questionText
          : questionText // ignore: cast_nullable_to_non_nullable
              as String,
      mandatory: null == mandatory
          ? _value.mandatory
          : mandatory // ignore: cast_nullable_to_non_nullable
              as bool,
      questionOptions: null == questionOptions
          ? _value._questionOptions
          : questionOptions // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FormQuestionImpl implements _FormQuestion {
  const _$FormQuestionImpl(
      {@HiveField(0) required this.questionId,
      @HiveField(1) required this.questionType,
      @HiveField(2) required this.questionText,
      @HiveField(3) required this.mandatory,
      @HiveField(4) final List<String> questionOptions = const []})
      : _questionOptions = questionOptions;

  factory _$FormQuestionImpl.fromJson(Map<String, dynamic> json) =>
      _$$FormQuestionImplFromJson(json);

  @override
  @HiveField(0)
  final String questionId;
  @override
  @HiveField(1)
  final FormQuestionType questionType;
  @override
  @HiveField(2)
  final String questionText;
  @override
  @HiveField(3)
  final bool mandatory;
  final List<String> _questionOptions;
  @override
  @JsonKey()
  @HiveField(4)
  List<String> get questionOptions {
    if (_questionOptions is EqualUnmodifiableListView) return _questionOptions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_questionOptions);
  }

  @override
  String toString() {
    return 'FormQuestion(questionId: $questionId, questionType: $questionType, questionText: $questionText, mandatory: $mandatory, questionOptions: $questionOptions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FormQuestionImpl &&
            (identical(other.questionId, questionId) ||
                other.questionId == questionId) &&
            (identical(other.questionType, questionType) ||
                other.questionType == questionType) &&
            (identical(other.questionText, questionText) ||
                other.questionText == questionText) &&
            (identical(other.mandatory, mandatory) ||
                other.mandatory == mandatory) &&
            const DeepCollectionEquality()
                .equals(other._questionOptions, _questionOptions));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      questionId,
      questionType,
      questionText,
      mandatory,
      const DeepCollectionEquality().hash(_questionOptions));

  /// Create a copy of FormQuestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FormQuestionImplCopyWith<_$FormQuestionImpl> get copyWith =>
      __$$FormQuestionImplCopyWithImpl<_$FormQuestionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FormQuestionImplToJson(
      this,
    );
  }
}

abstract class _FormQuestion implements FormQuestion {
  const factory _FormQuestion(
      {@HiveField(0) required final String questionId,
      @HiveField(1) required final FormQuestionType questionType,
      @HiveField(2) required final String questionText,
      @HiveField(3) required final bool mandatory,
      @HiveField(4) final List<String> questionOptions}) = _$FormQuestionImpl;

  factory _FormQuestion.fromJson(Map<String, dynamic> json) =
      _$FormQuestionImpl.fromJson;

  @override
  @HiveField(0)
  String get questionId;
  @override
  @HiveField(1)
  FormQuestionType get questionType;
  @override
  @HiveField(2)
  String get questionText;
  @override
  @HiveField(3)
  bool get mandatory;
  @override
  @HiveField(4)
  List<String> get questionOptions;

  /// Create a copy of FormQuestion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FormQuestionImplCopyWith<_$FormQuestionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
