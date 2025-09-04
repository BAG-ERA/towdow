// Journal model for project notes (VJOURNAL)
// Represents a note entry synchronized via CalDAV VJOURNAL

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

import 'attendee.dart';

part 'journal.freezed.dart';
part 'journal.g.dart';

@HiveType(typeId: 23)
@freezed
abstract class Journal with _$Journal {
  const factory Journal({
    @HiveField(0) required String uid,
    @HiveField(1) required String summary,
    @HiveField(2) required String description,
    @HiveField(3) required DateTime lastModified,
    @HiveField(4) required DateTime created,
    @HiveField(5) required DateTime dtstamp,
    @HiveField(6) String? organizer,
    @HiveField(7) @Default(<String>[]) List<String> categoryIds,
    @HiveField(8) String? projectPath,
    @HiveField(9) @Default('[]') String attachments,
    @HiveField(10) @Default('[]') String mediaAttachments,
    @HiveField(11) @Default(<Attendee>[]) List<Attendee> attendees,
  }) = _Journal;

  factory Journal.fromJson(Map<String, dynamic> json) => _$JournalFromJson(json);

  static Journal createNew({
    required String summary,
    String description = '',
    List<String> categoryIds = const [],
    String? projectPath,
    String? organizer,
    List<Attendee> attendees = const [],
    String attachments = '[]',
    String mediaAttachments = '[]',
  }) {
    final now = DateTime.now();
    final uid = 'journal-${now.millisecondsSinceEpoch}-${(summary.hashCode % 10000).abs()}';
    return Journal(
      uid: uid,
      summary: summary,
      description: description,
      lastModified: now,
      created: now,
      dtstamp: now,
      organizer: organizer,
      categoryIds: categoryIds,
      projectPath: projectPath,
      attachments: attachments,
      mediaAttachments: mediaAttachments,
      attendees: attendees,
    );
  }
}

