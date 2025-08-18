// Project notes quick panel (drop-up) to list recent notes (journals) and create a new one
// Shown in column 1 of project detail screen when toggled

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/journal.dart';
// repo accessed via provider only, no direct symbol here
import '../../../data/providers/providers_viewmodels.dart';
import '../../../data/providers/providers_repositories.dart';

class ProjectNotesQuickPanel extends ConsumerWidget {
  final String projectPath;
  final void Function(Journal) onOpenNote;
  final VoidCallback onCreateNew;

  const ProjectNotesQuickPanel({
    super.key,
    required this.projectPath,
    required this.onOpenNote,
    required this.onCreateNew,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use projectNotesViewModelProvider only to get the stream

    // Floating card with lateral margins, matching task toolbar design language
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        elevation: 16,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.24),
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 360, minHeight: 120, minWidth: 280),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: StreamBuilder<List<Journal>>(
            stream: ref.read(projectNotesViewModelProvider(projectPath).notifier).watchProjectNotes(),
            builder: (context, snapshot) {
            final all = snapshot.data ?? const <Journal>[];
            final journals = all
                .where((j) => j.projectPath == projectPath)
                .toList()
              ..sort((a, b) => b.lastModified.compareTo(a.lastModified));

            final tiles = <Widget>[];
            DateTime? lastHeaderDate;
            for (final j in journals) {
              final d = DateTime(j.lastModified.year, j.lastModified.month, j.lastModified.day);
              if (lastHeaderDate == null || d.compareTo(lastHeaderDate) != 0) {
                lastHeaderDate = d;
                tiles.add(Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                  child: Text(
                    _formatDate(d),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ));
              }
              tiles.add(_NoteRow(
                journal: j,
                onTap: () => onOpenNote(j),
              ));
            }

            if (tiles.isEmpty) {
              tiles.add(Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'No notes yet',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ));
            }

            tiles.add(const SizedBox(height: 8));
            tiles.add(
              Center(
                child: SizedBox(
                  height: 56, // match toolbar height
                  child: TextButton.icon(
                    onPressed: onCreateNew,
                    icon: const Icon(Icons.note_add_rounded),
                    label: const Text('New note'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ),
            );

                return ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: tiles,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _NoteRow extends StatelessWidget {
  final Journal journal;
  final VoidCallback onTap;
  const _NoteRow({required this.journal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(
        journal.summary.isEmpty ? '(untitled)' : journal.summary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      onTap: onTap,
      leading: const Icon(Icons.sticky_note_2_outlined, size: 18),
      minLeadingWidth: 16,
      horizontalTitleGap: 8,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 16),
        color: Theme.of(context).colorScheme.error,
        tooltip: 'Delete note',
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete note'),
              content: const Text('Are you sure you want to delete this note?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
              ],
            ),
          );
          if (confirmed == true) {
            // Obtain provider container and delete
            final container = ProviderScope.containerOf(context);
            final repo = container.read(journalRepositoryProvider);
            await repo.delete(journal.uid);
          }
        },
      ),
    );
  }
}


