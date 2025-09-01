// Requirement model for project-level requirement catalog
// Represents a requirement with id, name and attendeeEmails (kept empty in DRAFT)

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

part 'requirement.freezed.dart';
part 'requirement.g.dart';

@HiveType(typeId: 51)
@freezed
class Requirement with _$Requirement {
  const factory Requirement({
    @HiveField(0) required String id,
    @HiveField(1) required String name,
    @HiveField(2) @Default(<String>[]) List<String> attendeeEmails,
  }) = _Requirement;

  factory Requirement.fromJson(Map<String, dynamic> json) => _$RequirementFromJson(json);
}


