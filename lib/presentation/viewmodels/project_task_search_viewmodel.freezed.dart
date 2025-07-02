// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_task_search_viewmodel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ProjectTaskSearchState {
  String get searchQuery => throw _privateConstructorUsedError;
  bool get isSearchActive => throw _privateConstructorUsedError;

  /// Create a copy of ProjectTaskSearchState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProjectTaskSearchStateCopyWith<ProjectTaskSearchState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProjectTaskSearchStateCopyWith<$Res> {
  factory $ProjectTaskSearchStateCopyWith(ProjectTaskSearchState value,
          $Res Function(ProjectTaskSearchState) then) =
      _$ProjectTaskSearchStateCopyWithImpl<$Res, ProjectTaskSearchState>;
  @useResult
  $Res call({String searchQuery, bool isSearchActive});
}

/// @nodoc
class _$ProjectTaskSearchStateCopyWithImpl<$Res,
        $Val extends ProjectTaskSearchState>
    implements $ProjectTaskSearchStateCopyWith<$Res> {
  _$ProjectTaskSearchStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProjectTaskSearchState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? searchQuery = null,
    Object? isSearchActive = null,
  }) {
    return _then(_value.copyWith(
      searchQuery: null == searchQuery
          ? _value.searchQuery
          : searchQuery // ignore: cast_nullable_to_non_nullable
              as String,
      isSearchActive: null == isSearchActive
          ? _value.isSearchActive
          : isSearchActive // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ProjectTaskSearchStateImplCopyWith<$Res>
    implements $ProjectTaskSearchStateCopyWith<$Res> {
  factory _$$ProjectTaskSearchStateImplCopyWith(
          _$ProjectTaskSearchStateImpl value,
          $Res Function(_$ProjectTaskSearchStateImpl) then) =
      __$$ProjectTaskSearchStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String searchQuery, bool isSearchActive});
}

/// @nodoc
class __$$ProjectTaskSearchStateImplCopyWithImpl<$Res>
    extends _$ProjectTaskSearchStateCopyWithImpl<$Res,
        _$ProjectTaskSearchStateImpl>
    implements _$$ProjectTaskSearchStateImplCopyWith<$Res> {
  __$$ProjectTaskSearchStateImplCopyWithImpl(
      _$ProjectTaskSearchStateImpl _value,
      $Res Function(_$ProjectTaskSearchStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ProjectTaskSearchState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? searchQuery = null,
    Object? isSearchActive = null,
  }) {
    return _then(_$ProjectTaskSearchStateImpl(
      searchQuery: null == searchQuery
          ? _value.searchQuery
          : searchQuery // ignore: cast_nullable_to_non_nullable
              as String,
      isSearchActive: null == isSearchActive
          ? _value.isSearchActive
          : isSearchActive // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$ProjectTaskSearchStateImpl implements _ProjectTaskSearchState {
  const _$ProjectTaskSearchStateImpl(
      {this.searchQuery = '', this.isSearchActive = false});

  @override
  @JsonKey()
  final String searchQuery;
  @override
  @JsonKey()
  final bool isSearchActive;

  @override
  String toString() {
    return 'ProjectTaskSearchState(searchQuery: $searchQuery, isSearchActive: $isSearchActive)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProjectTaskSearchStateImpl &&
            (identical(other.searchQuery, searchQuery) ||
                other.searchQuery == searchQuery) &&
            (identical(other.isSearchActive, isSearchActive) ||
                other.isSearchActive == isSearchActive));
  }

  @override
  int get hashCode => Object.hash(runtimeType, searchQuery, isSearchActive);

  /// Create a copy of ProjectTaskSearchState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProjectTaskSearchStateImplCopyWith<_$ProjectTaskSearchStateImpl>
      get copyWith => __$$ProjectTaskSearchStateImplCopyWithImpl<
          _$ProjectTaskSearchStateImpl>(this, _$identity);
}

abstract class _ProjectTaskSearchState implements ProjectTaskSearchState {
  const factory _ProjectTaskSearchState(
      {final String searchQuery,
      final bool isSearchActive}) = _$ProjectTaskSearchStateImpl;

  @override
  String get searchQuery;
  @override
  bool get isSearchActive;

  /// Create a copy of ProjectTaskSearchState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProjectTaskSearchStateImplCopyWith<_$ProjectTaskSearchStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
