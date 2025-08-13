// Project note view widget (full-height in column 1)
// Styled similarly to the task widget but uses a blur overlay instead of a dark overlay

import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/journal.dart';
import '../../../data/providers/providers_viewmodels.dart';
import '../../widgets/utils/editable_title.dart';
import '../../widgets/utils/enhanced_text_field.dart';
import '../../../data/providers/providers_services_core.dart';
import '../../../data/providers/providers.dart';

class ProjectNoteView extends ConsumerStatefulWidget {
  final Journal journal;
  final VoidCallback? onSaved;
  const ProjectNoteView({super.key, required this.journal, this.onSaved});

  @override
  ConsumerState<ProjectNoteView> createState() => _ProjectNoteViewState();
}

class _ProjectNoteViewState extends ConsumerState<ProjectNoteView> {
  late TextEditingController _summary;
  late TextEditingController _desc;
  late FocusNode _descFocus;
  bool _isEditingDesc = false;

  @override
  void initState() {
    super.initState();
    _summary = TextEditingController(text: widget.journal.summary);
    _desc = TextEditingController(text: widget.journal.description);
    _descFocus = FocusNode();
  }

  @override
  void dispose() {
    // Final autosave on dispose to ensure no changes are lost
    try {
      final noteVm = ref.read(noteViewModelProvider(widget.journal).notifier);
      noteVm.updateSummary(_summary.text.trim());
      noteVm.updateDescription(_desc.text);
      // Fire-and-forget save
      noteVm.save();
    } catch (_) {}
    _autosaveTimer?.cancel();
    _summary.dispose();
    _desc.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteState = ref.watch(noteViewModelProvider(widget.journal));
    final noteVm = ref.read(noteViewModelProvider(widget.journal).notifier);
    return Stack(
      children: [
        // Blur overlay instead of dark overlay
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.25),
              ),
            ),
          ),
        ),
        // Floating card: width 90%, bottom-anchored, height fits content up to 80% of column height, white background
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.width >= 800 ? 0 : 72,
            ),
            child: FractionallySizedBox(
            widthFactor: 0.9,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxH = MediaQuery.of(context).size.height * 0.8;
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxH,
                  ),
                  child: Material(
                    elevation: 16,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.black.withOpacity(0.24),
                    color: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            EditableTitle(
                              title: _summary.text,
                              onTitleUpdated: (v) {
                                _summary.text = v;
                                noteVm.updateSummary(v);
                                _scheduleAutosave(noteVm, immediate: true);
                              },
                              isInAppBar: false,
                              hintText: 'Note title',
                              showActionButtons: false,
                            ),
                            const SizedBox(height: 12),
                            _buildDescriptionSection(context, noteVm),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                               child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: noteState.saving
                                    ? Row(
                                        key: const ValueKey('saving'),
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          SizedBox(
                                            height: 14,
                                            width: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                          SizedBox(width: 8),
                                          Text('Saving…'),
                                        ],
                                      )
                                    : Row(
                                        key: const ValueKey('saved'),
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.check_circle, size: 16, color: Colors.green),
                                          SizedBox(width: 6),
                                          Text('Saved'),
                                        ],
                                      ),
                               ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        ),
      ],
    );
  }

  // Legacy _save removed; ViewModel handles persistence

  Timer? _autosaveTimer;
  void _scheduleAutosave(dynamic noteVm, {bool immediate = false}) {
    _autosaveTimer?.cancel();
    if (immediate) {
      noteVm.save();
      return;
    }
    _autosaveTimer = Timer(const Duration(milliseconds: 900), () {
      noteVm.save();
    });
  }

  Widget _buildDescriptionSection(BuildContext context, dynamic noteVm) {
    final fileFeaturesEnabled = ref.watch(fileFeaturesEnabledProvider);
    final hasDescription = _desc.text.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(
          color: _isEditingDesc
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EnhancedTextField(
            controller: _desc,
            focusNode: _descFocus,
            maxLines: null,
            readOnly: !_isEditingDesc,
            hintText: hasDescription ? null : 'Add a note…',
            style: TextStyle(
              fontSize: 13,
              color: hasDescription
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              fontStyle: hasDescription ? FontStyle.normal : FontStyle.italic,
              height: 1.3,
            ),
            onTap: () {
              setState(() {
                _isEditingDesc = true;
              });
              _descFocus.requestFocus();
            },
            onChanged: (v) {
              noteVm.updateDescription(v);
              _scheduleAutosave(noteVm);
            },
            onSubmitted: (_) => _scheduleAutosave(noteVm, immediate: true),
          ),
          if (_isEditingDesc && fileFeaturesEnabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _pickAndAttachFile,
                  icon: const Icon(Icons.attach_file, size: 16),
                  tooltip: 'Attach file',
                  style: IconButton.styleFrom(minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
                ),
                IconButton(
                  onPressed: _pickAndAttachMedia,
                  icon: const Icon(Icons.perm_media, size: 16),
                  tooltip: 'Attach media',
                  style: IconButton.styleFrom(minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() { _isEditingDesc = false; });
                  },
                  child: const Text('Done'),
                ),
              ],
            )
          ],

          // Attachments list (files + media) below description
          const SizedBox(height: 8),
          _buildAttachmentsList(context),
        ],
      ),
    );
  }

  Future<void> _pickAndAttachFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final fileName = file.name;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        try {
          bytes = await File(file.path!).readAsBytes();
        } catch (_) {}
      }
      if (bytes == null) return;
      final ok = await ref.read(journalFileAttachmentViewModelProvider(widget.journal.uid).notifier)
          .uploadFile(
        journalUid: widget.journal.uid,
        fileName: fileName,
        fileData: bytes,
        contentType: _guessContentType(fileName),
      );
      if (ok && mounted) {
        // Keep editing; autosave already queued via repo save
      }
    } catch (_) {}
  }

  Future<void> _pickAndAttachMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg','jpeg','png','gif','bmp','webp','svg','tiff','tif','mp4','avi','mov','wmv','flv','webm','mkv','3gp','m4v'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final fileName = file.name;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        try {
          bytes = await File(file.path!).readAsBytes();
        } catch (_) {}
      }
      if (bytes == null) return;
      final ok = await ref.read(journalMediaAttachmentViewModelProvider(widget.journal.uid).notifier)
          .uploadMediaFile(
        journalUid: widget.journal.uid,
        fileName: fileName,
        fileData: bytes,
        contentType: _guessContentType(fileName),
      );
      if (ok && mounted) {}
    } catch (_) {}
  }

  String _guessContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls': return 'application/vnd.ms-excel';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt': return 'text/plain';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'gif': return 'image/gif';
      case 'bmp': return 'image/bmp';
      case 'webp': return 'image/webp';
      case 'svg': return 'image/svg+xml';
      case 'tiff': case 'tif': return 'image/tiff';
      case 'mp4': return 'video/mp4';
      case 'avi': return 'video/x-msvideo';
      case 'mov': return 'video/quicktime';
      case 'wmv': return 'video/x-ms-wmv';
      case 'flv': return 'video/x-flv';
      case 'webm': return 'video/webm';
      case 'mkv': return 'video/x-matroska';
      case '3gp': return 'video/3gpp';
      case 'm4v': return 'video/x-m4v';
      default: return 'application/octet-stream';
    }
  }

  Widget _buildAttachmentsList(BuildContext context) {
    final journalAsync = ref.watch(noteViewModelProvider(widget.journal));
    final j = journalAsync.journal;
    final files = _decodeList(j.attachments);
    final media = _decodeList(j.mediaAttachments);
    final combined = [
      ...files.map((m) => {...m, 'kind': 'file'}),
      ...media.map((m) => {...m, 'kind': 'media'}),
    ];
    if (combined.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attachments', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        ...combined.map((att) => _AttachmentRow(
              uid: j.uid,
              data: att,
            )),
      ],
    );
  }

  List<Map<String, dynamic>> _decodeList(String jsonList) {
    try {
      if (jsonList.isEmpty || jsonList == '[]') return [];
      final decoded = jsonDecode(jsonList);
      if (decoded is List) {
        return decoded.map<Map<String, dynamic>>((a) => a is Map<String, dynamic> ? a : <String, dynamic>{}).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

}

class _AttachmentRow extends ConsumerWidget {
  final String uid;
  final Map<String, dynamic> data;
  const _AttachmentRow({required this.uid, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileName = (data['filename'] ?? data['name'] ?? '').toString();
    final status = (data['status'] ?? '').toString();
    final kind = (data['kind'] ?? '').toString();
    // final s3Key = (data['s3Key'] ?? '').toString();
    // final fileId = (data['uri'] ?? '').toString();
    // final aesKey = (data['aesKey'] ?? '').toString();

    IconData icon;
    if (kind == 'media') {
      icon = Icons.perm_media;
    } else {
      icon = Icons.attach_file;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName.isEmpty ? '(attachment)' : fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (status == 'local')
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.download, size: 16),
              tooltip: 'Download',
              onPressed: () async {
                // For now, just no-op or future wiring to download for journals
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download coming soon for notes')),
                );
              },
            ),
        ],
      ),
    );
  }
}


