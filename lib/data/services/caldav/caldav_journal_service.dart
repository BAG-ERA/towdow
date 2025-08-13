// CalDavJournalService: CRUD on VJOURNAL

import '../../../core/logger.dart';
import '../../../core/result.dart';
import '../../models/caldav_account.dart';
import '../../models/journal.dart';
import '../parsers/vjournal_parser.dart';
import '../webdav_client.dart';

class CalDavJournalService {
  final CaldavAccount account;
  final WebDAVClient _client;

  CalDavJournalService({required this.account, WebDAVClient? client})
      : _client = client ?? WebDAVClient.fromAccount(account);

  Future<Result<String>> createJournal(Journal journal, String calendarPath) async {
    try {
      final vjournal = VJournalParser.serializeJournal(journal);
      final normalized = calendarPath.endsWith('/') ? calendarPath : '$calendarPath/';
      final journalUrl = '$normalized${journal.uid}.ics';
      final put = await _client.put(journalUrl, vjournal);
      return put.when(
        success: (r) async {
          if (r.statusCode == 201 || r.statusCode == 204) return Result.success(journalUrl);
          return Result.failure(Failure(message: 'HTTP ${r.statusCode}'));
        },
        failure: (f) async => Result.failure(f),
      );
    } catch (e, st) {
      AppLogger.error('CalDavJournalService: createJournal failed', e, st);
      return Result.failure(Failure(message: 'createJournal: $e'));
    }
  }

  Future<Result<void>> updateJournal(Journal journal, String journalUrl, {String? etag}) async {
    try {
      final vjournal = VJournalParser.serializeJournal(journal);
      final put = await _client.put(journalUrl, vjournal, etag: etag);
      return put.when(
        success: (r) async {
          if (r.statusCode == 200 || r.statusCode == 204 || r.statusCode == 201) {
            return const Result.success(null);
          }
          return Result.failure(Failure(message: 'HTTP ${r.statusCode}'));
        },
        failure: (f) async => Result.failure(f),
      );
    } catch (e, st) {
      AppLogger.error('CalDavJournalService: updateJournal failed', e, st);
      return Result.failure(Failure(message: 'updateJournal: $e'));
    }
  }

  Future<Result<void>> deleteJournal(String journalUrl, {String? etag}) async {
    try {
      final del = await _client.delete(journalUrl, etag: etag);
      return del.when(
        success: (r) async {
          if (r.statusCode == 204 || r.statusCode == 200) return const Result.success(null);
          return Result.failure(Failure(message: 'HTTP ${r.statusCode}'));
        },
        failure: (f) async => Result.failure(f),
      );
    } catch (e, st) {
      AppLogger.error('CalDavJournalService: deleteJournal failed', e, st);
      return Result.failure(Failure(message: 'deleteJournal: $e'));
    }
  }

  Future<Result<List<Journal>>> fetchJournals(String calendarPath) async {
    try {
      final reportQuery = '''<?xml version="1.0" encoding="utf-8" ?>
<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:prop>
    <D:getetag />
    <C:calendar-data />
  </D:prop>
  <C:filter>
    <C:comp-filter name="VCALENDAR">
      <C:comp-filter name="VJOURNAL" />
    </C:comp-filter>
  </C:filter>
</C:calendar-query>''';
      final res = await _client.report(calendarPath, reportQuery);
      return res.when(
        success: (r) async {
          if (r.statusCode == 207) {
            final journals = VJournalParser.parseJournalsFromResponse(r.body);
            return Result.success(journals);
          }
          return Result.failure(Failure(message: 'HTTP ${r.statusCode}'));
        },
        failure: (f) async => Result.failure(f),
      );
    } catch (e, st) {
      AppLogger.error('CalDavJournalService: fetchJournals failed', e, st);
      return Result.failure(Failure(message: 'fetchJournals: $e'));
    }
  }
}


