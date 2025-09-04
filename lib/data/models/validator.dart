// Validator models for task completion validation
// Supports default and form-based validators per specs

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

part 'validator.freezed.dart';
part 'validator.g.dart';

@HiveType(typeId: 7)
@freezed
abstract class FormQuestion with _$FormQuestion {
  const factory FormQuestion({
    @HiveField(0) required String questionId,
    @HiveField(1) required FormQuestionType questionType,
    @HiveField(2) required String questionText,
    @HiveField(3) required bool mandatory,
    @HiveField(4) @Default([]) List<String> questionOptions,
  }) = _FormQuestion;

  factory FormQuestion.fromJson(Map<String, dynamic> json) => _$FormQuestionFromJson(json);
}

@HiveType(typeId: 8)
enum FormQuestionType {
  @HiveField(0)
  select,
  @HiveField(1)
  freefield,
  @HiveField(2)
  multiselect,
} 
