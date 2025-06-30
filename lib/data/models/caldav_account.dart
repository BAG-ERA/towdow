// CalDAV account model for storing connection information
// Supports different provider types including Google OAuth

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'caldav_account.freezed.dart';
part 'caldav_account.g.dart';

@HiveType(typeId: 1)
@freezed
class CaldavAccount with _$CaldavAccount {
  const factory CaldavAccount({
    @HiveField(0) required String id,
    @HiveField(1) required String providerType, // flowit_cloud, google, nextcloud, custom
    @HiveField(2) required String serverUrl,
    @HiveField(3) required String username,
    @HiveField(4) String? password, // for basic auth
    @HiveField(5) String? accessToken, // for OAuth
    @HiveField(6) String? refreshToken, // for OAuth
    @HiveField(7) DateTime? tokenExpiry, // for OAuth

    @HiveField(9) required DateTime createdAt,
    @HiveField(10) required DateTime lastSyncAt,
    @HiveField(11) @Default(true) bool isActive,
    @HiveField(12) String? firstName, // user's first name
    @HiveField(13) String? lastName, // user's last name
    @HiveField(14) String? email, // user's email address
  }) = _CaldavAccount;

  factory CaldavAccount.fromJson(Map<String, dynamic> json) => _$CaldavAccountFromJson(json);
} 
