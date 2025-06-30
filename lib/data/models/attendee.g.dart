// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendee.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttendeeAdapter extends TypeAdapter<Attendee> {
  @override
  final int typeId = 5;

  @override
  Attendee read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Attendee(
      email: fields[0] as String,
      displayName: fields[1] as String?,
      status: fields[2] as AttendeeStatus,
      role: fields[3] as AttendeeRole,
      rsvpRequested: fields[4] as bool,
      userType: fields[5] as CalendarUserType,
      delegatedFrom: fields[6] as String?,
      delegatedTo: fields[7] as String?,
      scheduleAgent: fields[8] as String?,
      memberOf: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Attendee obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.email)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.role)
      ..writeByte(4)
      ..write(obj.rsvpRequested)
      ..writeByte(5)
      ..write(obj.userType)
      ..writeByte(6)
      ..write(obj.delegatedFrom)
      ..writeByte(7)
      ..write(obj.delegatedTo)
      ..writeByte(8)
      ..write(obj.scheduleAgent)
      ..writeByte(9)
      ..write(obj.memberOf);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendeeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AttendeeStatusAdapter extends TypeAdapter<AttendeeStatus> {
  @override
  final int typeId = 2;

  @override
  AttendeeStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AttendeeStatus.needsAction;
      case 1:
        return AttendeeStatus.accepted;
      case 2:
        return AttendeeStatus.declined;
      case 3:
        return AttendeeStatus.tentative;
      case 4:
        return AttendeeStatus.delegated;
      default:
        return AttendeeStatus.needsAction;
    }
  }

  @override
  void write(BinaryWriter writer, AttendeeStatus obj) {
    switch (obj) {
      case AttendeeStatus.needsAction:
        writer.writeByte(0);
        break;
      case AttendeeStatus.accepted:
        writer.writeByte(1);
        break;
      case AttendeeStatus.declined:
        writer.writeByte(2);
        break;
      case AttendeeStatus.tentative:
        writer.writeByte(3);
        break;
      case AttendeeStatus.delegated:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendeeStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AttendeeRoleAdapter extends TypeAdapter<AttendeeRole> {
  @override
  final int typeId = 3;

  @override
  AttendeeRole read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AttendeeRole.requiredParticipant;
      case 1:
        return AttendeeRole.optionalParticipant;
      case 2:
        return AttendeeRole.nonParticipant;
      case 3:
        return AttendeeRole.chair;
      default:
        return AttendeeRole.requiredParticipant;
    }
  }

  @override
  void write(BinaryWriter writer, AttendeeRole obj) {
    switch (obj) {
      case AttendeeRole.requiredParticipant:
        writer.writeByte(0);
        break;
      case AttendeeRole.optionalParticipant:
        writer.writeByte(1);
        break;
      case AttendeeRole.nonParticipant:
        writer.writeByte(2);
        break;
      case AttendeeRole.chair:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendeeRoleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CalendarUserTypeAdapter extends TypeAdapter<CalendarUserType> {
  @override
  final int typeId = 4;

  @override
  CalendarUserType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CalendarUserType.individual;
      case 1:
        return CalendarUserType.group;
      case 2:
        return CalendarUserType.resource;
      case 3:
        return CalendarUserType.room;
      case 4:
        return CalendarUserType.unknown;
      default:
        return CalendarUserType.individual;
    }
  }

  @override
  void write(BinaryWriter writer, CalendarUserType obj) {
    switch (obj) {
      case CalendarUserType.individual:
        writer.writeByte(0);
        break;
      case CalendarUserType.group:
        writer.writeByte(1);
        break;
      case CalendarUserType.resource:
        writer.writeByte(2);
        break;
      case CalendarUserType.room:
        writer.writeByte(3);
        break;
      case CalendarUserType.unknown:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarUserTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AttendeeImpl _$$AttendeeImplFromJson(Map<String, dynamic> json) =>
    _$AttendeeImpl(
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      status: $enumDecodeNullable(_$AttendeeStatusEnumMap, json['status']) ??
          AttendeeStatus.needsAction,
      role: $enumDecodeNullable(_$AttendeeRoleEnumMap, json['role']) ??
          AttendeeRole.requiredParticipant,
      rsvpRequested: json['rsvpRequested'] as bool? ?? false,
      userType:
          $enumDecodeNullable(_$CalendarUserTypeEnumMap, json['userType']) ??
              CalendarUserType.individual,
      delegatedFrom: json['delegatedFrom'] as String?,
      delegatedTo: json['delegatedTo'] as String?,
      scheduleAgent: json['scheduleAgent'] as String?,
      memberOf: json['memberOf'] as String?,
    );

Map<String, dynamic> _$$AttendeeImplToJson(_$AttendeeImpl instance) =>
    <String, dynamic>{
      'email': instance.email,
      'displayName': instance.displayName,
      'status': _$AttendeeStatusEnumMap[instance.status]!,
      'role': _$AttendeeRoleEnumMap[instance.role]!,
      'rsvpRequested': instance.rsvpRequested,
      'userType': _$CalendarUserTypeEnumMap[instance.userType]!,
      'delegatedFrom': instance.delegatedFrom,
      'delegatedTo': instance.delegatedTo,
      'scheduleAgent': instance.scheduleAgent,
      'memberOf': instance.memberOf,
    };

const _$AttendeeStatusEnumMap = {
  AttendeeStatus.needsAction: 'NEEDS-ACTION',
  AttendeeStatus.accepted: 'ACCEPTED',
  AttendeeStatus.declined: 'DECLINED',
  AttendeeStatus.tentative: 'TENTATIVE',
  AttendeeStatus.delegated: 'DELEGATED',
};

const _$AttendeeRoleEnumMap = {
  AttendeeRole.requiredParticipant: 'REQ-PARTICIPANT',
  AttendeeRole.optionalParticipant: 'OPT-PARTICIPANT',
  AttendeeRole.nonParticipant: 'NON-PARTICIPANT',
  AttendeeRole.chair: 'CHAIR',
};

const _$CalendarUserTypeEnumMap = {
  CalendarUserType.individual: 'INDIVIDUAL',
  CalendarUserType.group: 'GROUP',
  CalendarUserType.resource: 'RESOURCE',
  CalendarUserType.room: 'ROOM',
  CalendarUserType.unknown: 'UNKNOWN',
};
