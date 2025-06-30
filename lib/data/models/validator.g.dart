// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'validator.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FormQuestionAdapter extends TypeAdapter<FormQuestion> {
  @override
  final int typeId = 7;

  @override
  FormQuestion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FormQuestion(
      questionId: fields[0] as String,
      questionType: fields[1] as FormQuestionType,
      questionText: fields[2] as String,
      mandatory: fields[3] as bool,
      questionOptions: (fields[4] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, FormQuestion obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.questionId)
      ..writeByte(1)
      ..write(obj.questionType)
      ..writeByte(2)
      ..write(obj.questionText)
      ..writeByte(3)
      ..write(obj.mandatory)
      ..writeByte(4)
      ..write(obj.questionOptions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormQuestionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FormQuestionTypeAdapter extends TypeAdapter<FormQuestionType> {
  @override
  final int typeId = 8;

  @override
  FormQuestionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FormQuestionType.select;
      case 1:
        return FormQuestionType.freefield;
      case 2:
        return FormQuestionType.multiselect;
      default:
        return FormQuestionType.select;
    }
  }

  @override
  void write(BinaryWriter writer, FormQuestionType obj) {
    switch (obj) {
      case FormQuestionType.select:
        writer.writeByte(0);
        break;
      case FormQuestionType.freefield:
        writer.writeByte(1);
        break;
      case FormQuestionType.multiselect:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormQuestionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FormQuestionImpl _$$FormQuestionImplFromJson(Map<String, dynamic> json) =>
    _$FormQuestionImpl(
      questionId: json['questionId'] as String,
      questionType:
          $enumDecode(_$FormQuestionTypeEnumMap, json['questionType']),
      questionText: json['questionText'] as String,
      mandatory: json['mandatory'] as bool,
      questionOptions: (json['questionOptions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$FormQuestionImplToJson(_$FormQuestionImpl instance) =>
    <String, dynamic>{
      'questionId': instance.questionId,
      'questionType': _$FormQuestionTypeEnumMap[instance.questionType]!,
      'questionText': instance.questionText,
      'mandatory': instance.mandatory,
      'questionOptions': instance.questionOptions,
    };

const _$FormQuestionTypeEnumMap = {
  FormQuestionType.select: 'select',
  FormQuestionType.freefield: 'freefield',
  FormQuestionType.multiselect: 'multiselect',
};
