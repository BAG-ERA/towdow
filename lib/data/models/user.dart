// User models for TowDow API integration
// Defines data structures for user information from the users API

import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// Current user response model from /current_user endpoint
@freezed
class CurrentUser with _$CurrentUser {
  const factory CurrentUser({
    required String email,
    required String name,
    required String sub,
    required List<String> role,
    required String locale,
  }) = _CurrentUser;

  factory CurrentUser.fromJson(Map<String, dynamic> json) => _$CurrentUserFromJson(json);
}

/// User information model from /user/{email} endpoint
@freezed
class UserInfo with _$UserInfo {
  const factory UserInfo({
    required int id,
    required bool isGuest,
    required String homePath,
    required String email,
    required String kcId,
    required String firstname,
    required String lastname,
  }) = _UserInfo;

  factory UserInfo.fromJson(Map<String, dynamic> json) => _$UserInfoFromJson(json);
} 