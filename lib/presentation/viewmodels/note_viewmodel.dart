// ViewModel for a single note (journal) editing

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/journal.dart';
import '../../data/repositories/journal_repository.dart';

class NoteState {
  final Journal journal;
  final bool saving;
  const NoteState({required this.journal, this.saving = false});

  NoteState copyWith({Journal? journal, bool? saving}) =>
      NoteState(journal: journal ?? this.journal, saving: saving ?? this.saving);
}

class NoteViewModel extends StateNotifier<NoteState> {
  final JournalRepository _journalRepository;
  NoteViewModel(Journal journal, this._journalRepository) : super(NoteState(journal: journal));

  Future<void> updateSummary(String value) async {
    state = state.copyWith(journal: state.journal.copyWith(summary: value, lastModified: DateTime.now()));
  }

  Future<void> updateDescription(String value) async {
    state = state.copyWith(journal: state.journal.copyWith(description: value, lastModified: DateTime.now()));
  }

  Future<void> save() async {
    state = state.copyWith(saving: true);
    await _journalRepository.save(state.journal);
    state = state.copyWith(saving: false);
  }
}


