// Task item description component
// Displays description, attendees, categories sections, and file attachments when task is expanded

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/logger.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import '../../../data/models/task.dart';
import 'chips/attendee_chip.dart';
import 'chips/category_chip.dart';
import '../utils/enhanced_text_field.dart';
import '../attachment/file_attachment_list.dart';
import '../attachment/media_attachment_list.dart';
import '../../../data/providers/providers.dart';

class TaskItemDescription extends ConsumerStatefulWidget {
  final Task task;
  final Function(Task)? onTaskUpdated;

  const TaskItemDescription({
    super.key,
    required this.task,
    this.onTaskUpdated,
  });

  @override
  ConsumerState<TaskItemDescription> createState() => _TaskItemDescriptionState();
}

class _TaskItemDescriptionState extends ConsumerState<TaskItemDescription> {
  bool _isEditing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.task.description);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TaskItemDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller text when task changes (e.g., when widget is reused for different task)
    if (oldWidget.task.uid != widget.task.uid) {
      _controller.text = widget.task.description;
      // Reset editing state when task changes
      if (_isEditing) {
        setState(() {
          _isEditing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileFeaturesEnabled = ref.watch(fileFeaturesEnabledProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description
        _buildCompactDescriptionSection(context),
        
        // File Attachments
        if (fileFeaturesEnabled)
          TaskFileAttachmentList(
            task: widget.task,
            onTaskUpdated: widget.onTaskUpdated,
          ),
        
        // Media Attachments
        if (fileFeaturesEnabled)
          TaskMediaAttachmentList(
            task: widget.task,
            onTaskUpdated: widget.onTaskUpdated,
          ),
        
        // Attendees
        if (widget.task.attendees.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildCompactAttendeesSection(context),
        ],
        
        // Categories
                  if (widget.task.categoryIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildCompactCategoriesSection(context),
        ],
      ],
    );
  }

  Widget _buildCompactDescriptionSection(BuildContext context) {
    final hasDescription = widget.task.description.isNotEmpty;
    final fileFeaturesEnabled = ref.watch(fileFeaturesEnabledProvider);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(
          color: _isEditing 
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description text field
          EnhancedTextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: null,
            readOnly: !_isEditing,
            hintText: hasDescription ? null : AppLocalizations.of(context)!.noDescriptionHint,
            style: TextStyle(
              fontSize: 13,
              color: hasDescription 
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              fontStyle: hasDescription ? FontStyle.normal : FontStyle.italic,
              height: 1.3,
            ),
            onTap: widget.onTaskUpdated != null ? _startEditing : null,
            onSubmitted: (_) => _saveDescription(),
          ),
          
          // Editing controls and file attachment button
          if (_isEditing) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (fileFeaturesEnabled) ...[
                  // File attachment button
                  IconButton(
                    onPressed: _triggerFileAttachment,
                    icon: const Icon(Icons.attach_file, size: 16),
                    tooltip: AppLocalizations.of(context)!.attachFile,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  // Media attachment button
                  IconButton(
                    onPressed: _triggerMediaAttachment,
                    icon: const Icon(Icons.perm_media, size: 16),
                    tooltip: AppLocalizations.of(context)!.attachMedia,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                      foregroundColor: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
                const Spacer(),
                // Cancel and Save buttons
                TextButton(
                  onPressed: _cancelEdit,
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveDescription,
                  child: Text(AppLocalizations.of(context)!.save),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _controller.text = widget.task.description;
    });
  }

  void _saveDescription() {
    if (widget.onTaskUpdated != null) {
      final updatedTask = widget.task.copyWith(
        description: _controller.text.trim(),
        lastModified: DateTime.now(),
      );
      widget.onTaskUpdated!(updatedTask);
    }
    
    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _triggerMediaAttachment() async {
    try {
      // Pick media file (restrict to image/video types for media attachments)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          // Image formats
          'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'tiff', 'tif',
          // Video formats (if desired)
          // 'mp4', 'avi', 'mov', 'wmv', 'flv', 'webm', 'mkv', '3gp', 'm4v',
        ],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final fileName = file.name;
      Uint8List? fileBytes = file.bytes;

      // Handle desktop file reading
      if (fileBytes == null && file.path != null) {
        try {
          final fileObj = File(file.path!);
          fileBytes = await fileObj.readAsBytes();
        } catch (e) {
          if (mounted) {
            AppLogger.error('Could not read media file: $e');
          }
          return;
        }
      }

      if (fileBytes == null) {
        if (mounted) {
          AppLogger.error('Could not read media file data');
        }
        return;
      }

      // Upload media file using TaskMediaAttachmentViewModel
      final success = await ref.read(taskMediaAttachmentViewModelProvider(widget.task.uid).notifier)
          .uploadMediaFile(
        taskUid: widget.task.uid,
        fileName: fileName,
        fileData: fileBytes,
        contentType: _getContentType(fileName),
      );

      if (mounted && success) {
        // Refresh the task to get the updated version with media attachment
        final taskRepository = ref.read(taskRepositoryProvider);
        final taskResult = await taskRepository.getById(widget.task.uid);
        
        await taskResult.when(
          success: (updatedTask) async {
            if (updatedTask != null && widget.onTaskUpdated != null) {
              widget.onTaskUpdated!(updatedTask);
            }
          },
          failure: (failure) async {
            // Task update failed, but file was uploaded
          },
        );
        
        if (mounted) {
        }
      }
    } catch (e) {
      if (mounted) {
        AppLogger.error('Error uploading media file: $e');
      }
    }
  }

  Future<void> _triggerFileAttachment() async {
    try {
      // Pick file using the same method as TaskFileAttachmentList
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final fileName = file.name;
      Uint8List? fileBytes = file.bytes;

      // Handle desktop file reading
      if (fileBytes == null && file.path != null) {
        try {
          final fileObj = File(file.path!);
          fileBytes = await fileObj.readAsBytes();
        } catch (e) {
          if (mounted) {
            AppLogger.error('Could not read file: $e');
          }
          return;
        }
      }

      if (fileBytes == null) {
        if (mounted) {
          AppLogger.error('Could not read file data');
        }
        return;
      }

      // Upload file using TaskFileAttachmentViewModel
      final success = await ref.read(taskFileAttachmentViewModelProvider(widget.task.uid).notifier)
          .uploadFile(
        taskUid: widget.task.uid,
        fileName: fileName,
        fileData: fileBytes,
        contentType: _getContentType(fileName),
      );

      if (mounted && success) {
        // Refresh the task to get the updated version with attachment
        final taskRepository = ref.read(taskRepositoryProvider);
        final taskResult = await taskRepository.getById(widget.task.uid);
        
        await taskResult.when(
          success: (updatedTask) async {
            if (updatedTask != null && widget.onTaskUpdated != null) {
              widget.onTaskUpdated!(updatedTask);
            }
          },
          failure: (failure) async {
            // Task update failed, but file was uploaded
          },
        );
        
        if (mounted) {
        }
      }
    } catch (e) {
      if (mounted) {
        AppLogger.error('Error uploading file: $e');
      }
    }
  }

  String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  Widget _buildCompactAttendeesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              widget.task.attendees.length == 1 ? Icons.person : Icons.group,
              size: 14,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 4),
            Text(
              widget.task.attendees.length == 1 ? 'Attendee' : 'Attendees',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 3,
          children: widget.task.attendees.map((attendee) {
            return AttendeeChip(attendee: attendee);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCompactCategoriesSection(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 3,
      children: widget.task.categoryIds.map((categoryId) {
        return CategoryChip(
          categoryId: categoryId,
          projectPath: widget.task.projectPath,
        );
      }).toList(),
    );
  }
} 