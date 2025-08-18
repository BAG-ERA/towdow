import 'package:flutter_test/flutter_test.dart';
import '../../../lib/data/services/parsers/vjournal_parser.dart';
import '../../../lib/data/models/journal.dart';

void main() {
  group('VJournalParser', () {
    test('serialize and parse roundtrip', () {
      final journal = Journal.createNew(
        summary: 'Project note',
        description: 'Line 1\nLine 2',
        categoryIds: ['notes','project'],
        projectPath: '/calendars/user/project-uid/',
      );
      final ics = VJournalParser.serializeJournal(journal);
      expect(ics.contains('BEGIN:VJOURNAL'), true);
      expect(ics.contains('SUMMARY:'), true);
      final parsed = VJournalParser.parseVJOURNALFromCalendarData(ics);
      expect(parsed, isNotNull);
      expect(parsed!.summary, journal.summary);
      expect(parsed.description, journal.description);
      expect(parsed.categoryIds, journal.categoryIds);
    });

    test('attachments are serialized with FlowIt extensions', () {
      final journal = Journal.createNew(
        summary: 'With attachment',
      ).copyWith(
        attachments: '[{"uri":"file-token-1","filename":"doc.pdf","fmttype":"application/pdf","size":1234,"aesKey":"k","attachType":"file"}]',
      );
      final ics = VJournalParser.serializeJournal(journal);
      expect(ics.contains('ATTACH;'), true);
      expect(ics.contains('FILENAME=doc.pdf'), true);
      expect(ics.contains('X-FLOWIT-AESKEY=k'), true);
    });
  });
}


