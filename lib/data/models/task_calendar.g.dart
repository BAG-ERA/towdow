// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_calendar.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskCalendarAdapter extends TypeAdapter<TaskCalendar> {
  @override
  final int typeId = 10;

  @override
  TaskCalendar read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskCalendar(
      path: fields[0] as String,
      displayName: fields[1] as String,
      description: fields[2] as String,
      supportsTodos: fields[3] as bool,
      etag: fields[4] as String?,
      color: fields[5] as String?,
      lastSyncAt: fields[6] as DateTime?,
      isReadOnly: fields[7] as bool,
      syncToken: fields[24] as String?,
      uid: fields[8] as String,
      dtstamp: fields[9] as DateTime,
      created: fields[10] as DateTime,
      lastModified: fields[11] as DateTime,
      summary: fields[12] as String,
      status: fields[13] as String,
      percentComplete: fields[14] as int,
      flowitType: fields[15] as String,
      flowitAsFlow: fields[16] as bool,
      flowitKanban: fields[17] as String,
      flowitOwner: fields[18] as String?,
      flowitTemplate: fields[19] as String?,
      calendarOrder: fields[20] as int,
      organizer: fields[21] as String?,
      attendees: (fields[22] as List).cast<Attendee>(),
      categories: (fields[23] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, TaskCalendar obj) {
    writer
      ..writeByte(25)
      ..writeByte(0)
      ..write(obj.path)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.supportsTodos)
      ..writeByte(4)
      ..write(obj.etag)
      ..writeByte(5)
      ..write(obj.color)
      ..writeByte(6)
      ..write(obj.lastSyncAt)
      ..writeByte(7)
      ..write(obj.isReadOnly)
      ..writeByte(24)
      ..write(obj.syncToken)
      ..writeByte(8)
      ..write(obj.uid)
      ..writeByte(9)
      ..write(obj.dtstamp)
      ..writeByte(10)
      ..write(obj.created)
      ..writeByte(11)
      ..write(obj.lastModified)
      ..writeByte(12)
      ..write(obj.summary)
      ..writeByte(13)
      ..write(obj.status)
      ..writeByte(14)
      ..write(obj.percentComplete)
      ..writeByte(15)
      ..write(obj.flowitType)
      ..writeByte(16)
      ..write(obj.flowitAsFlow)
      ..writeByte(17)
      ..write(obj.flowitKanban)
      ..writeByte(18)
      ..write(obj.flowitOwner)
      ..writeByte(19)
      ..write(obj.flowitTemplate)
      ..writeByte(20)
      ..write(obj.calendarOrder)
      ..writeByte(21)
      ..write(obj.organizer)
      ..writeByte(22)
      ..write(obj.attendees)
      ..writeByte(23)
      ..write(obj.categories);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskCalendarAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TaskCalendarImpl _$$TaskCalendarImplFromJson(Map<String, dynamic> json) =>
    _$TaskCalendarImpl(
      path: json['path'] as String,
      displayName: json['displayName'] as String,
      description: json['description'] as String? ?? '',
      supportsTodos: json['supportsTodos'] as bool? ?? true,
      etag: json['etag'] as String?,
      color: json['color'] as String?,
      lastSyncAt: json['lastSyncAt'] == null
          ? null
          : DateTime.parse(json['lastSyncAt'] as String),
      isReadOnly: json['isReadOnly'] as bool? ?? false,
      syncToken: json['syncToken'] as String?,
      uid: json['uid'] as String,
      dtstamp: DateTime.parse(json['dtstamp'] as String),
      created: DateTime.parse(json['created'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
      summary: json['summary'] as String,
      status: json['status'] as String,
      percentComplete: (json['percentComplete'] as num?)?.toInt() ?? 0,
      flowitType: json['flowitType'] as String? ?? 'PROJECT',
      flowitAsFlow: json['flowitAsFlow'] as bool? ?? false,
      flowitKanban: json['flowitKanban'] as String? ?? '[]',
      flowitOwner: json['flowitOwner'] as String?,
      flowitTemplate: json['flowitTemplate'] as String?,
      calendarOrder: (json['calendarOrder'] as num?)?.toInt() ?? 1,
      organizer: json['organizer'] as String?,
      attendees: (json['attendees'] as List<dynamic>?)
              ?.map((e) => Attendee.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$TaskCalendarImplToJson(_$TaskCalendarImpl instance) =>
    <String, dynamic>{
      'path': instance.path,
      'displayName': instance.displayName,
      'description': instance.description,
      'supportsTodos': instance.supportsTodos,
      'etag': instance.etag,
      'color': instance.color,
      'lastSyncAt': instance.lastSyncAt?.toIso8601String(),
      'isReadOnly': instance.isReadOnly,
      'syncToken': instance.syncToken,
      'uid': instance.uid,
      'dtstamp': instance.dtstamp.toIso8601String(),
      'created': instance.created.toIso8601String(),
      'lastModified': instance.lastModified.toIso8601String(),
      'summary': instance.summary,
      'status': instance.status,
      'percentComplete': instance.percentComplete,
      'flowitType': instance.flowitType,
      'flowitAsFlow': instance.flowitAsFlow,
      'flowitKanban': instance.flowitKanban,
      'flowitOwner': instance.flowitOwner,
      'flowitTemplate': instance.flowitTemplate,
      'calendarOrder': instance.calendarOrder,
      'organizer': instance.organizer,
      'attendees': instance.attendees,
      'categories': instance.categories,
    };
