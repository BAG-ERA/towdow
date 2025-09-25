// Journal file attachment list component
// Displays file attachments for a journal and handles file operations

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/logger.dart';
import '../../../core/result.dart';
import '../../../data/models/journal.dart';
import '../../../data/models/attachment.dart';
import '../../../data/providers/providers.dart';
import '../../../l10n/app_localizations.dart';

class JournalFileAttachmentList extends ConsumerStatefulWidget {
  final Journal journal;
  final Function(Journal)? onJournalUpdated;

  const JournalFileAttachmentList({
    super.key,
    required this.journal,
    this.onJournalUpdated,
  });

  @override
  ConsumerState<JournalFileAttachmentList> createState() => _JournalFileAttachmentListState();
}

class _JournalFileAttachmentListState extends ConsumerState<JournalFileAttachmentList> {
  @override
  Widget build(BuildContext context) {
    // Watch the reactive journal data from the repository
    final journalAsync = ref.watch(journalProvider(widget.journal.uid));
    
    // Get the current journal from the reactive data
    final currentJournal = journalAsync.when(
      data: (journal) => journal ?? widget.journal,
      loading: () => widget.journal,
      error: (error, stack) => widget.journal,
    );

    // Watch the unified attachment view model state
    final attachmentState = ref.watch(unifiedAttachmentViewModelProvider);

    // Parse attachments from the current journal using the unified viewmodel
    final attachments = ref.read(unifiedAttachmentViewModelProvider.notifier).parseAttachments(currentJournal.attachments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.attach_file,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context)!.files,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            if (attachmentState.isUploading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            IconButton(
              onPressed: _uploadFile,
              icon: const Icon(Icons.add, size: 16),
              tooltip: AppLocalizations.of(context)!.addFile,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
          ],
        ),
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...attachments.map((attachment) => _buildAttachmentItem(attachment)),
        ],
      ],
    );
  }

  Widget _buildAttachmentItem(Attachment attachment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.attach_file,
            size: 16,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.filename,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (attachment.size != null)
                  Text(
                    _formatFileSize(attachment.size!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _downloadFile(attachment),
            icon: const Icon(Icons.download, size: 16),
            tooltip: AppLocalizations.of(context)!.downloadFile,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileData = File(file.path!);
        final bytes = await fileData.readAsBytes();

        AppLogger.info('JournalFileAttachmentList: Starting file upload: ${file.name}');

        final success = await ref.read(unifiedAttachmentViewModelProvider.notifier).uploadJournalAttachment(
          journalUid: widget.journal.uid,
          fileName: file.name,
          fileData: bytes,
          contentType: _guessContentType(file.name),
          type: AttachmentType.file,
        );

        if (success && widget.onJournalUpdated != null) {
          // Refresh the journal data
          final updatedJournal = await ref.read(journalRepositoryProvider).getById(widget.journal.uid);
          updatedJournal.when(
            success: (journal) {
              if (journal != null) {
                widget.onJournalUpdated!(journal);
              }
            },
            failure: (failure) {
              AppLogger.error('JournalFileAttachmentList: Failed to refresh journal after upload', failure.exception);
            },
          );
        }
      }
    } catch (e) {
      AppLogger.error('JournalFileAttachmentList: File upload failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.failedToUploadFile}: $e')),
        );
      }
    }
  }

  Future<void> _downloadFile(Attachment attachment) async {
    try {
      AppLogger.info('JournalFileAttachmentList: Starting file download: ${attachment.filename}');

      final bytes = await ref.read(unifiedAttachmentViewModelProvider.notifier).downloadAttachment(
        fileId: attachment.uri,
        aesKey: attachment.aesKey,
        s3Key: attachment.s3Key,
      );

      if (bytes == null) {
        throw Exception('Download returned null');
      }

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: AppLocalizations.of(context)!.saveFile,
        fileName: attachment.filename,
        type: FileType.any,
      );

      if (savePath != null) {
        final saveFile = File(savePath);
        await saveFile.writeAsBytes(bytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.fileSavedSuccessfully)),
          );
        }
      }
    } catch (e) {
      AppLogger.error('JournalFileAttachmentList: File download failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.failedToDownloadFile}: $e')),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _guessContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls': return 'application/vnd.ms-excel';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt': return 'application/vnd.ms-powerpoint';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt': return 'text/plain';
      case 'rtf': return 'application/rtf';
      case 'zip': return 'application/zip';
      case 'rar': return 'application/x-rar-compressed';
      case '7z': return 'application/x-7z-compressed';
      case 'tar': return 'application/x-tar';
      case 'gz': return 'application/gzip';
      default: return 'application/octet-stream';
    }
  }
}
