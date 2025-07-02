// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flowit_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FlowitItemAdapter extends TypeAdapter<FlowitItem> {
  @override
  final int typeId = 0;

  @override
  FlowitItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FlowitItem(
      uid: fields[0] as String,
      summary: fields[1] as String,
      description: fields[2] as String,
      status: fields[3] as String,
      lastModified: fields[4] as DateTime,
      created: fields[5] as DateTime,
      due: fields[6] as DateTime?,
      categories: (fields[7] as List).cast<String>(),
      organizer: fields[8] as String?,
      attendees: (fields[9] as List).cast<String>(),
      percentComplete: fields[10] as int,
      flowitType: fields[11] as String,
      flowitProcess: fields[12] as String?,
      flowitTemplate: fields[13] as String?,
      flowitReversalTask: fields[14] as String?,
      flowitValidator: fields[15] as String,
      flowitRequirement: fields[16] as String,
      flowitContext: fields[17] as String,
      flowitAutomate: fields[18] as String,
      flowitKanban: fields[19] as String,
      flowitKanbanColumn: fields[20] as String,
      flowitAsFlow: fields[21] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, FlowitItem obj) {
    writer
      ..writeByte(22)
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
      ..write(obj.due)
      ..writeByte(7)
      ..write(obj.categories)
      ..writeByte(8)
      ..write(obj.organizer)
      ..writeByte(9)
      ..write(obj.attendees)
      ..writeByte(10)
      ..write(obj.percentComplete)
      ..writeByte(11)
      ..write(obj.flowitType)
      ..writeByte(12)
      ..write(obj.flowitProcess)
      ..writeByte(13)
      ..write(obj.flowitTemplate)
      ..writeByte(14)
      ..write(obj.flowitReversalTask)
      ..writeByte(15)
      ..write(obj.flowitValidator)
      ..writeByte(16)
      ..write(obj.flowitRequirement)
      ..writeByte(17)
      ..write(obj.flowitContext)
      ..writeByte(18)
      ..write(obj.flowitAutomate)
      ..writeByte(19)
      ..write(obj.flowitKanban)
      ..writeByte(20)
      ..write(obj.flowitKanbanColumn)
      ..writeByte(21)
      ..write(obj.flowitAsFlow);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlowitItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FlowitItemImpl _$$FlowitItemImplFromJson(Map<String, dynamic> json) =>
    _$FlowitItemImpl(
      uid: json['uid'] as String,
      summary: json['summary'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      lastModified: DateTime.parse(json['lastModified'] as String),
      created: DateTime.parse(json['created'] as String),
      due: json['due'] == null ? null : DateTime.parse(json['due'] as String),
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      organizer: json['organizer'] as String?,
      attendees: (json['attendees'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      percentComplete: (json['percentComplete'] as num?)?.toInt() ?? 0,
      flowitType: json['flowitType'] as String,
      flowitProcess: json['flowitProcess'] as String?,
      flowitTemplate: json['flowitTemplate'] as String?,
      flowitReversalTask: json['flowitReversalTask'] as String?,
      flowitValidator: json['flowitValidator'] as String? ?? '{}',
      flowitRequirement: json['flowitRequirement'] as String? ?? '{}',
      flowitContext: json['flowitContext'] as String? ?? '{}',
      flowitAutomate: json['flowitAutomate'] as String? ?? '{}',
      flowitKanban: json['flowitKanban'] as String? ?? '[]',
      flowitKanbanColumn: json['flowitKanbanColumn'] as String? ?? '[]',
      flowitAsFlow: json['flowitAsFlow'] as bool? ?? false,
    );

Map<String, dynamic> _$$FlowitItemImplToJson(_$FlowitItemImpl instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'summary': instance.summary,
      'description': instance.description,
      'status': instance.status,
      'lastModified': instance.lastModified.toIso8601String(),
      'created': instance.created.toIso8601String(),
      'due': instance.due?.toIso8601String(),
      'categories': instance.categories,
      'organizer': instance.organizer,
      'attendees': instance.attendees,
      'percentComplete': instance.percentComplete,
      'flowitType': instance.flowitType,
      'flowitProcess': instance.flowitProcess,
      'flowitTemplate': instance.flowitTemplate,
      'flowitReversalTask': instance.flowitReversalTask,
      'flowitValidator': instance.flowitValidator,
      'flowitRequirement': instance.flowitRequirement,
      'flowitContext': instance.flowitContext,
      'flowitAutomate': instance.flowitAutomate,
      'flowitKanban': instance.flowitKanban,
      'flowitKanbanColumn': instance.flowitKanbanColumn,
      'flowitAsFlow': instance.flowitAsFlow,
    };
