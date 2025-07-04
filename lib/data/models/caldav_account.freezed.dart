// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'caldav_account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CaldavAccount _$CaldavAccountFromJson(Map<String, dynamic> json) {
  return _CaldavAccount.fromJson(json);
}

/// @nodoc
mixin _$CaldavAccount {
  @HiveField(0)
  String get id => throw _privateConstructorUsedError;
  @HiveField(1)
  String get providerType =>
      throw _privateConstructorUsedError; // flowit_cloud, google, nextcloud, custom
  @HiveField(2)
  String get serverUrl => throw _privateConstructorUsedError;
  @HiveField(3)
  String get username => throw _privateConstructorUsedError;
  @HiveField(4)
  String? get password => throw _privateConstructorUsedError; // for basic auth
  @HiveField(5)
  String? get accessToken => throw _privateConstructorUsedError; // for OAuth
  @HiveField(6)
  String? get refreshToken => throw _privateConstructorUsedError; // for OAuth
  @HiveField(7)
  DateTime? get tokenExpiry => throw _privateConstructorUsedError; // for OAuth
  @HiveField(9)
  DateTime get createdAt => throw _privateConstructorUsedError;
  @HiveField(10)
  DateTime get lastSyncAt => throw _privateConstructorUsedError;
  @HiveField(11)
  bool get isActive => throw _privateConstructorUsedError;
  @HiveField(12)
  String? get firstName =>
      throw _privateConstructorUsedError; // user's first name
  @HiveField(13)
  String? get lastName =>
      throw _privateConstructorUsedError; // user's last name
  @HiveField(14)
  String? get email => throw _privateConstructorUsedError;

  /// Serializes this CaldavAccount to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CaldavAccount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CaldavAccountCopyWith<CaldavAccount> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CaldavAccountCopyWith<$Res> {
  factory $CaldavAccountCopyWith(
          CaldavAccount value, $Res Function(CaldavAccount) then) =
      _$CaldavAccountCopyWithImpl<$Res, CaldavAccount>;
  @useResult
  $Res call(
      {@HiveField(0) String id,
      @HiveField(1) String providerType,
      @HiveField(2) String serverUrl,
      @HiveField(3) String username,
      @HiveField(4) String? password,
      @HiveField(5) String? accessToken,
      @HiveField(6) String? refreshToken,
      @HiveField(7) DateTime? tokenExpiry,
      @HiveField(9) DateTime createdAt,
      @HiveField(10) DateTime lastSyncAt,
      @HiveField(11) bool isActive,
      @HiveField(12) String? firstName,
      @HiveField(13) String? lastName,
      @HiveField(14) String? email});
}

/// @nodoc
class _$CaldavAccountCopyWithImpl<$Res, $Val extends CaldavAccount>
    implements $CaldavAccountCopyWith<$Res> {
  _$CaldavAccountCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CaldavAccount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? providerType = null,
    Object? serverUrl = null,
    Object? username = null,
    Object? password = freezed,
    Object? accessToken = freezed,
    Object? refreshToken = freezed,
    Object? tokenExpiry = freezed,
    Object? createdAt = null,
    Object? lastSyncAt = null,
    Object? isActive = null,
    Object? firstName = freezed,
    Object? lastName = freezed,
    Object? email = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      providerType: null == providerType
          ? _value.providerType
          : providerType // ignore: cast_nullable_to_non_nullable
              as String,
      serverUrl: null == serverUrl
          ? _value.serverUrl
          : serverUrl // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      password: freezed == password
          ? _value.password
          : password // ignore: cast_nullable_to_non_nullable
              as String?,
      accessToken: freezed == accessToken
          ? _value.accessToken
          : accessToken // ignore: cast_nullable_to_non_nullable
              as String?,
      refreshToken: freezed == refreshToken
          ? _value.refreshToken
          : refreshToken // ignore: cast_nullable_to_non_nullable
              as String?,
      tokenExpiry: freezed == tokenExpiry
          ? _value.tokenExpiry
          : tokenExpiry // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastSyncAt: null == lastSyncAt
          ? _value.lastSyncAt
          : lastSyncAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      firstName: freezed == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String?,
      lastName: freezed == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String?,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CaldavAccountImplCopyWith<$Res>
    implements $CaldavAccountCopyWith<$Res> {
  factory _$$CaldavAccountImplCopyWith(
          _$CaldavAccountImpl value, $Res Function(_$CaldavAccountImpl) then) =
      __$$CaldavAccountImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) String id,
      @HiveField(1) String providerType,
      @HiveField(2) String serverUrl,
      @HiveField(3) String username,
      @HiveField(4) String? password,
      @HiveField(5) String? accessToken,
      @HiveField(6) String? refreshToken,
      @HiveField(7) DateTime? tokenExpiry,
      @HiveField(9) DateTime createdAt,
      @HiveField(10) DateTime lastSyncAt,
      @HiveField(11) bool isActive,
      @HiveField(12) String? firstName,
      @HiveField(13) String? lastName,
      @HiveField(14) String? email});
}

/// @nodoc
class __$$CaldavAccountImplCopyWithImpl<$Res>
    extends _$CaldavAccountCopyWithImpl<$Res, _$CaldavAccountImpl>
    implements _$$CaldavAccountImplCopyWith<$Res> {
  __$$CaldavAccountImplCopyWithImpl(
      _$CaldavAccountImpl _value, $Res Function(_$CaldavAccountImpl) _then)
      : super(_value, _then);

  /// Create a copy of CaldavAccount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? providerType = null,
    Object? serverUrl = null,
    Object? username = null,
    Object? password = freezed,
    Object? accessToken = freezed,
    Object? refreshToken = freezed,
    Object? tokenExpiry = freezed,
    Object? createdAt = null,
    Object? lastSyncAt = null,
    Object? isActive = null,
    Object? firstName = freezed,
    Object? lastName = freezed,
    Object? email = freezed,
  }) {
    return _then(_$CaldavAccountImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      providerType: null == providerType
          ? _value.providerType
          : providerType // ignore: cast_nullable_to_non_nullable
              as String,
      serverUrl: null == serverUrl
          ? _value.serverUrl
          : serverUrl // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      password: freezed == password
          ? _value.password
          : password // ignore: cast_nullable_to_non_nullable
              as String?,
      accessToken: freezed == accessToken
          ? _value.accessToken
          : accessToken // ignore: cast_nullable_to_non_nullable
              as String?,
      refreshToken: freezed == refreshToken
          ? _value.refreshToken
          : refreshToken // ignore: cast_nullable_to_non_nullable
              as String?,
      tokenExpiry: freezed == tokenExpiry
          ? _value.tokenExpiry
          : tokenExpiry // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastSyncAt: null == lastSyncAt
          ? _value.lastSyncAt
          : lastSyncAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      firstName: freezed == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String?,
      lastName: freezed == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String?,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CaldavAccountImpl implements _CaldavAccount {
  const _$CaldavAccountImpl(
      {@HiveField(0) required this.id,
      @HiveField(1) required this.providerType,
      @HiveField(2) required this.serverUrl,
      @HiveField(3) required this.username,
      @HiveField(4) this.password,
      @HiveField(5) this.accessToken,
      @HiveField(6) this.refreshToken,
      @HiveField(7) this.tokenExpiry,
      @HiveField(9) required this.createdAt,
      @HiveField(10) required this.lastSyncAt,
      @HiveField(11) this.isActive = true,
      @HiveField(12) this.firstName,
      @HiveField(13) this.lastName,
      @HiveField(14) this.email});

  factory _$CaldavAccountImpl.fromJson(Map<String, dynamic> json) =>
      _$$CaldavAccountImplFromJson(json);

  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String providerType;
// flowit_cloud, google, nextcloud, custom
  @override
  @HiveField(2)
  final String serverUrl;
  @override
  @HiveField(3)
  final String username;
  @override
  @HiveField(4)
  final String? password;
// for basic auth
  @override
  @HiveField(5)
  final String? accessToken;
// for OAuth
  @override
  @HiveField(6)
  final String? refreshToken;
// for OAuth
  @override
  @HiveField(7)
  final DateTime? tokenExpiry;
// for OAuth
  @override
  @HiveField(9)
  final DateTime createdAt;
  @override
  @HiveField(10)
  final DateTime lastSyncAt;
  @override
  @JsonKey()
  @HiveField(11)
  final bool isActive;
  @override
  @HiveField(12)
  final String? firstName;
// user's first name
  @override
  @HiveField(13)
  final String? lastName;
// user's last name
  @override
  @HiveField(14)
  final String? email;

  @override
  String toString() {
    return 'CaldavAccount(id: $id, providerType: $providerType, serverUrl: $serverUrl, username: $username, password: $password, accessToken: $accessToken, refreshToken: $refreshToken, tokenExpiry: $tokenExpiry, createdAt: $createdAt, lastSyncAt: $lastSyncAt, isActive: $isActive, firstName: $firstName, lastName: $lastName, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CaldavAccountImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.providerType, providerType) ||
                other.providerType == providerType) &&
            (identical(other.serverUrl, serverUrl) ||
                other.serverUrl == serverUrl) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.password, password) ||
                other.password == password) &&
            (identical(other.accessToken, accessToken) ||
                other.accessToken == accessToken) &&
            (identical(other.refreshToken, refreshToken) ||
                other.refreshToken == refreshToken) &&
            (identical(other.tokenExpiry, tokenExpiry) ||
                other.tokenExpiry == tokenExpiry) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastSyncAt, lastSyncAt) ||
                other.lastSyncAt == lastSyncAt) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.email, email) || other.email == email));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      providerType,
      serverUrl,
      username,
      password,
      accessToken,
      refreshToken,
      tokenExpiry,
      createdAt,
      lastSyncAt,
      isActive,
      firstName,
      lastName,
      email);

  /// Create a copy of CaldavAccount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CaldavAccountImplCopyWith<_$CaldavAccountImpl> get copyWith =>
      __$$CaldavAccountImplCopyWithImpl<_$CaldavAccountImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CaldavAccountImplToJson(
      this,
    );
  }
}

abstract class _CaldavAccount implements CaldavAccount {
  const factory _CaldavAccount(
      {@HiveField(0) required final String id,
      @HiveField(1) required final String providerType,
      @HiveField(2) required final String serverUrl,
      @HiveField(3) required final String username,
      @HiveField(4) final String? password,
      @HiveField(5) final String? accessToken,
      @HiveField(6) final String? refreshToken,
      @HiveField(7) final DateTime? tokenExpiry,
      @HiveField(9) required final DateTime createdAt,
      @HiveField(10) required final DateTime lastSyncAt,
      @HiveField(11) final bool isActive,
      @HiveField(12) final String? firstName,
      @HiveField(13) final String? lastName,
      @HiveField(14) final String? email}) = _$CaldavAccountImpl;

  factory _CaldavAccount.fromJson(Map<String, dynamic> json) =
      _$CaldavAccountImpl.fromJson;

  @override
  @HiveField(0)
  String get id;
  @override
  @HiveField(1)
  String get providerType; // flowit_cloud, google, nextcloud, custom
  @override
  @HiveField(2)
  String get serverUrl;
  @override
  @HiveField(3)
  String get username;
  @override
  @HiveField(4)
  String? get password; // for basic auth
  @override
  @HiveField(5)
  String? get accessToken; // for OAuth
  @override
  @HiveField(6)
  String? get refreshToken; // for OAuth
  @override
  @HiveField(7)
  DateTime? get tokenExpiry; // for OAuth
  @override
  @HiveField(9)
  DateTime get createdAt;
  @override
  @HiveField(10)
  DateTime get lastSyncAt;
  @override
  @HiveField(11)
  bool get isActive;
  @override
  @HiveField(12)
  String? get firstName; // user's first name
  @override
  @HiveField(13)
  String? get lastName; // user's last name
  @override
  @HiveField(14)
  String? get email;

  /// Create a copy of CaldavAccount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CaldavAccountImplCopyWith<_$CaldavAccountImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
