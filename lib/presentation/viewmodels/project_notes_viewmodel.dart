// ViewModel for listing and creating project notes (journals)

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/journal.dart';
import '../../data/repositories/journal_repository.dart';

class ProjectNotesState {
  final String projectPath;
  const ProjectNotesState(this.projectPath);
}

class ProjectNotesViewModel extends StateNotifier<ProjectNotesState> {
  final JournalRepository _journalRepository;

  ProjectNotesViewModel({required String projectPath, required JournalRepository journalRepository})
      : _journalRepository = journalRepository,
        super(ProjectNotesState(projectPath));

  Stream<List<Journal>> watchProjectNotes() {
    return _journalRepository.watchJournals().map((all) {
      final filtered = all.where((j) => j.projectPath == state.projectPath).toList()
        ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
      return filtered;
    });
  }

  Future<Journal> createNewNote({String summary = 'Note', String description = ''}) async {
    final j = Journal.createNew(
      summary: summary,
      description: description,
      projectPath: state.projectPath,
    );
    await _journalRepository.save(j);
    return j;
  }
}


