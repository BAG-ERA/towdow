// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caldav_account.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CaldavAccountAdapter extends TypeAdapter<CaldavAccount> {
  @override
  final int typeId = 1;

  @override
  CaldavAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CaldavAccount(
      id: fields[0] as String,
      providerType: fields[1] as String,
      serverUrl: fields[2] as String,
      username: fields[3] as String,
      password: fields[4] as String?,
      accessToken: fields[5] as String?,
      refreshToken: fields[6] as String?,
      tokenExpiry: fields[7] as DateTime?,
      createdAt: fields[9] as DateTime,
      lastSyncAt: fields[10] as DateTime,
      isActive: fields[11] as bool,
      firstName: fields[12] as String?,
      lastName: fields[13] as String?,
      email: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CaldavAccount obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.providerType)
      ..writeByte(2)
      ..write(obj.serverUrl)
      ..writeByte(3)
      ..write(obj.username)
      ..writeByte(4)
      ..write(obj.password)
      ..writeByte(5)
      ..write(obj.accessToken)
      ..writeByte(6)
      ..write(obj.refreshToken)
      ..writeByte(7)
      ..write(obj.tokenExpiry)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.lastSyncAt)
      ..writeByte(11)
      ..write(obj.isActive)
      ..writeByte(12)
      ..write(obj.firstName)
      ..writeByte(13)
      ..write(obj.lastName)
      ..writeByte(14)
      ..write(obj.email);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaldavAccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CaldavAccountImpl _$$CaldavAccountImplFromJson(Map<String, dynamic> json) =>
    _$CaldavAccountImpl(
      id: json['id'] as String,
      providerType: json['providerType'] as String,
      serverUrl: json['serverUrl'] as String,
      username: json['username'] as String,
      password: json['password'] as String?,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      tokenExpiry: json['tokenExpiry'] == null
          ? null
          : DateTime.parse(json['tokenExpiry'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSyncAt: DateTime.parse(json['lastSyncAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      email: json['email'] as String?,
    );

Map<String, dynamic> _$$CaldavAccountImplToJson(_$CaldavAccountImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'providerType': instance.providerType,
      'serverUrl': instance.serverUrl,
      'username': instance.username,
      'password': instance.password,
      'accessToken': instance.accessToken,
      'refreshToken': instance.refreshToken,
      'tokenExpiry': instance.tokenExpiry?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'lastSyncAt': instance.lastSyncAt.toIso8601String(),
      'isActive': instance.isActive,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'email': instance.email,
    };
