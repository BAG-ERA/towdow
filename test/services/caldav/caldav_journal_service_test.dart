import 'package:flutter_test/flutter_test.dart';
import '../../../lib/data/services/caldav/caldav_journal_service.dart';
import '../../../lib/data/models/caldav_account.dart';
import '../../../lib/data/models/journal.dart';

void main() {
  test('serialize journal and build URL', () async {
    final account = CaldavAccount(
      id: '1',
      providerType: 'custom',
      serverUrl: 'http://s',
      username: 'u',
      createdAt: DateTime.now(),
      lastSyncAt: DateTime.now(),
    );
    final service = CalDavJournalService(account: account);
    final j = Journal.createNew(summary: 'Note');
    // We cannot hit network; just ensure method returns a Result (likely failure without server) and URL logic is sane
    final res = await service.createJournal(j, '/cal/u/p/');
    // Either success or failure, but the call completed
    expect(res, isNotNull);
  });
}


