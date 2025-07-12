import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import '../../../../../../data/repositories/file_repository.dart';
import '../../../../../../data/models/cached_file.dart';
import '../../../../../core/logger.dart';

class ValidatorFileWidget extends StatefulWidget {
  final Map<String, dynamic> validator;
  final String accountId;
  final Future<String> Function()? jwtProvider;
  final void Function(Map<String, dynamic>) onValidatorChanged;
  const ValidatorFileWidget({super.key, required this.validator, required this.accountId, this.jwtProvider, required this.onValidatorChanged});

  @override
  State<ValidatorFileWidget> createState() => _ValidatorFileWidgetState();
}

class _ValidatorFileWidgetState extends State<ValidatorFileWidget> {
  bool _uploading = false;
  bool _downloading = false;

  Future<String> _buildObjectKey(String fileName) async {
    // Reuse the same logic that was used during upload to reconstruct the key.
    String prefix = widget.accountId;
    if (widget.jwtProvider != null) {
      try {
        final jwt = await widget.jwtProvider!();
        if (jwt.contains('.')) {
          final payloadPart = jwt.split('.')[1];
          final decoded = json.decode(utf8.decode(base64Url.decode(base64.normalize(payloadPart))));
          prefix = decoded['sub'] ?? prefix;
        }
      } catch (_) {
        // keep default prefix
      }
    }
    return '$prefix/${widget.validator['id']}/$fileName';
  }

  Future<void> _selectAndUpload() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;
    final file = res.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _uploading = true);
    try {
      final repo = await FileRepository.forAccount(widget.accountId, widget.jwtProvider);

      // Build object key using the JWT "sub" (user id) as first path segment, as required by bucket policy
      String prefix = widget.accountId;
      if (widget.jwtProvider != null) {
        try {
          final jwt = await widget.jwtProvider!();
          if (jwt.contains('.')) {
            final payloadPart = jwt.split('.')[1];
            final decoded = json.decode(utf8.decode(base64Url.decode(base64.normalize(payloadPart))));
            prefix = decoded['sub'] ?? prefix;
          }
        } catch (_) {
          // fallback to accountId if decoding fails
        }
      }

      final key = '$prefix/${widget.validator['id']}/${file.name}';
      final up = await repo.uploadPrivate(key: key, data: Uint8List.fromList(bytes), localPath: file.name);
      up.when(
        success: (_) {
          final newVal = Map<String, dynamic>.from(widget.validator);
          newVal['fileName'] = file.name;
          newVal['mime'] = file.extension ?? '';
          newVal['size'] = bytes.length;
          widget.onValidatorChanged(newVal);
        },
        failure: (f) {
          AppLogger.error('Upload failed', f.message, null);
        },
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _downloadAndOpen() async {
    if (_downloading) return;
    final fileName = widget.validator['fileName'] as String?;
    if (fileName == null || fileName.isEmpty) return;

    setState(() => _downloading = true);
    try {
      final repo = await FileRepository.forAccount(widget.accountId, widget.jwtProvider);
      final key = await _buildObjectKey(fileName);

      // Check cache first
      CachedFile? cached = repo.getCached(key);
      String? path = cached?.localPath;

      if (path == null || !(await File(path).exists())) {
        final tmpDir = await getTemporaryDirectory();
        final localPath = '${tmpDir.path}/$fileName';

        final dl = await repo.download(
          bucket: 'towdow-private',
          key: key,
          writeFile: (Uint8List bytes) async {
            final file = File(localPath);
            await file.writeAsBytes(bytes, flush: true);
            return file.path;
          },
        );

        await dl.when(
          success: (p) async {
            path = p;
            AppLogger.info('Downloaded file saved at $p');
          },
          failure: (f) async {
            AppLogger.error('Download failed', f.message, null);
          },
        );
      }

      if (path != null) {
        await OpenFile.open(path);
      } else {
        AppLogger.warning('File path is null – cannot open');
      }
    } catch (e, st) {
      AppLogger.error('Download/open failed', e, st);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = (widget.validator['fileName'] as String?)?.isNotEmpty ?? false;
    if (!hasFile) {
      return ElevatedButton.icon(
        onPressed: _uploading ? null : _selectAndUpload,
        icon: const Icon(Icons.attach_file),
        label: _uploading ? const Text('Uploading...') : const Text('Upload file'),
      );
    }
    return ListTile(
      leading: const Icon(Icons.insert_drive_file),
      title: Text(widget.validator['fileName'] ?? 'file'),
      subtitle: Text('${(widget.validator['size'] ?? 0) / 1024} KB'),
      trailing: IconButton(
        icon: _downloading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.download),
        onPressed: _downloading ? null : _downloadAndOpen,
      ),
    );
  }
} 