// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 6;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      uid: fields[0] as String,
      summary: fields[1] as String,
      description: fields[2] as String,
      status: fields[3] as String,
      lastModified: fields[4] as DateTime,
      created: fields[5] as DateTime,
      dtstamp: fields[6] as DateTime,
      due: fields[7] as DateTime?,
      categories: (fields[8] as List).cast<String>(),
      organizer: fields[9] as String?,
      attendees: (fields[10] as List).cast<Attendee>(),
      percentComplete: fields[11] as int,
      sourceCalendarUid: fields[12] as String?,
      flowitTemplate: fields[13] as String?,
      flowitReversalTask: fields[14] as String?,
      flowitValidator: fields[15] as String,
      flowitRequirement: fields[16] as String,
      flowitKanbanColumn: fields[17] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.summary)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.lastModified)
      ..writeByte(5)
      ..write(obj.created)
      ..writeByte(6)
      ..write(obj.dtstamp)
      ..writeByte(7)
      ..write(obj.due)
      ..writeByte(8)
      ..write(obj.categories)
      ..writeByte(9)
      ..write(obj.organizer)
      ..writeByte(10)
      ..write(obj.attendees)
      ..writeByte(11)
      ..write(obj.percentComplete)
      ..writeByte(12)
      ..write(obj.sourceCalendarUid)
      ..writeByte(13)
      ..write(obj.flowitTemplate)
      ..writeByte(14)
      ..write(obj.flowitReversalTask)
      ..writeByte(15)
      ..write(obj.flowitValidator)
      ..writeByte(16)
      ..write(obj.flowitRequirement)
      ..writeByte(17)
      ..write(obj.flowitKanbanColumn);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TaskImpl _$$TaskImplFromJson(Map<String, dynamic> json) => _$TaskImpl(
      uid: json['uid'] as String,
      summary: json['summary'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      lastModified: DateTime.parse(json['lastModified'] as String),
      created: DateTime.parse(json['created'] as String),
      dtstamp: DateTime.parse(json['dtstamp'] as String),
      due: json['due'] == null ? null : DateTime.parse(json['due'] as String),
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      organizer: json['organizer'] as String?,
      attendees: (json['attendees'] as List<dynamic>?)
              ?.map((e) => Attendee.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      percentComplete: (json['percentComplete'] as num?)?.toInt() ?? 0,
      sourceCalendarUid: json['sourceCalendarUid'] as String?,
      flowitTemplate: json['flowitTemplate'] as String?,
      flowitReversalTask: json['flowitReversalTask'] as String?,
      flowitValidator:
          json['flowitValidator'] as String? ?? '{"type":"default"}',
      flowitRequirement: json['flowitRequirement'] as String? ?? '{}',
      flowitKanbanColumn: json['flowitKanbanColumn'] as String? ?? '[]',
    );

Map<String, dynamic> _$$TaskImplToJson(_$TaskImpl instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'summary': instance.summary,
      'description': instance.description,
      'status': instance.status,
      'lastModified': instance.lastModified.toIso8601String(),
      'created': instance.created.toIso8601String(),
      'dtstamp': instance.dtstamp.toIso8601String(),
      'due': instance.due?.toIso8601String(),
      'categories': instance.categories,
      'organizer': instance.organizer,
      'attendees': instance.attendees,
      'percentComplete': instance.percentComplete,
      'sourceCalendarUid': instance.sourceCalendarUid,
      'flowitTemplate': instance.flowitTemplate,
      'flowitReversalTask': instance.flowitReversalTask,
      'flowitValidator': instance.flowitValidator,
      'flowitRequirement': instance.flowitRequirement,
      'flowitKanbanColumn': instance.flowitKanbanColumn,
    };
