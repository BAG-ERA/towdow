import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/caldav_account.dart';
import '../../../data/providers/providers.dart';
import '../../../data/services/auth_token_provider.dart';
import '../../../data/repositories/file_repository.dart';
import '../../../core/logger.dart';

class S3DebugScreen extends ConsumerStatefulWidget {
  const S3DebugScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<S3DebugScreen> createState() => _S3DebugScreenState();
}

class _S3DebugScreenState extends ConsumerState<S3DebugScreen> {
  final List<String> _log = [];
  bool _busy = false;

  void _append(String msg) {
    setState(() => _log.insert(0, msg));
    AppLogger.info(msg);
  }

  Future<CaldavAccount?> _getActiveAccount() async {
    final result = await ref.read(activeAccountProvider.future);
    return result;
  }

  Future<void> _listBuckets() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final acc = await _getActiveAccount();
      if (acc == null) {
        _append('No active account');
        return;
      }
      
      _append('Request: listBuckets()');
      final repo = await FileRepository.forAccount(acc.id, () => AuthTokenProvider.getValidToken(acc));
      final result = await repo.storageService.listBuckets();
      
      result.when(
        success: (buckets) {
          _append('Response: ${buckets.join(', ')}');
        },
        failure: (f) {
          _append('Error: ${f.message}');
        },
      );
    } catch (e) {
      _append('Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _uploadPrivate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final acc = await _getActiveAccount();
      if (acc == null) {
        _append('No active account');
        return;
      }
      final repo = await FileRepository.forAccount(acc.id, () => AuthTokenProvider.getValidToken(acc));
      final data = Uint8List.fromList(utf8.encode('Debug upload ${DateTime.now()}'));
      final key = 'debug_upload.txt';
      final result = await repo.uploadPrivate(key: key, data: data, localPath: 'debug_upload.txt');
      result.when(
        success: (_) => _append('Uploaded to private: $key'),
        failure: (f) => _append('Upload failed: ${f.message}'),
      );
    } catch (e) {
      _append('Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _uploadToSub() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final acc = await _getActiveAccount();
      if (acc == null) {
        _append('No active account');
        return;
      }
      final repo = await FileRepository.forAccount(acc.id, () => AuthTokenProvider.getValidToken(acc));
      final data = Uint8List.fromList(utf8.encode('Sub upload ${DateTime.now()}'));
      final key = 'manual_sub_upload.txt';
      final result = await repo.uploadPrivate(key: key, data: data, localPath: 'manual_sub_upload.txt');
      result.when(
        success: (_) => _append('Uploaded (sub path): $key'),
        failure: (f) => _append('Upload failed: ${f.message}'),
      );
    } catch (e) {
      _append('Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _showJwtClaims() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final acc = await _getActiveAccount();
      if (acc == null) {
        _append('No active account');
        return;
      }
      
      final repo = await FileRepository.forAccount(acc.id, () => AuthTokenProvider.getValidToken(acc));
      final result = await repo.storageService.getJwtClaims();
      
      result.when(
        success: (claims) {
          final subClaim = claims['sub'] as String?;
          
          _append('=== JWT Claims ===');
          _append('sub: ${subClaim ?? "null"}');
          _append('exp: ${claims['exp']}');
          _append('iat: ${claims['iat']}');
          _append('iss: ${claims['iss']}');
          _append('aud: ${claims['aud']}');
          _append('preferred_username: ${claims['preferred_username']}');
          _append('email: ${claims['email']}');
          _append('==================');
        },
        failure: (f) {
          _append('Error getting JWT claims: ${f.message}');
        },
      );
    } catch (e) {
      _append('Error showing JWT claims: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _listObjects() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final acc = await _getActiveAccount();
      if (acc == null) {
        _append('No active account');
        return;
      }
      
      final repo = await FileRepository.forAccount(acc.id, () => AuthTokenProvider.getValidToken(acc));
      
      // List objects from private bucket
      _append('Request: list objects from private bucket');
      final privateResult = await repo.storageService.list(
        bucket: 'towdow-private',
        prefix: '',
      );
      
      privateResult.when(
        success: (objects) {
          _append('Private bucket objects (${objects.length}):');
          for (final obj in objects) {
            _append('  - ${obj.key} (${obj.size} bytes, modified: ${obj.lastModified})');
          }
        },
        failure: (f) {
          _append('Error listing private bucket: ${f.message}');
        },
      );
      
      // List objects from shared bucket
      _append('Request: list objects from shared bucket');
      final sharedResult = await repo.storageService.list(
        bucket: 'towdow-shared',
        prefix: '',
      );
      
      sharedResult.when(
        success: (objects) {
          _append('Shared bucket objects (${objects.length}):');
          for (final obj in objects) {
            _append('  - ${obj.key} (${obj.size} bytes, modified: ${obj.lastModified})');
          }
        },
        failure: (f) {
          _append('Error listing shared bucket: ${f.message}');
        },
      );
    } catch (e) {
      _append('Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('S3 Debug')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              children: [
                ElevatedButton(onPressed: _listBuckets, child: const Text('List Buckets')),
                ElevatedButton(onPressed: _listObjects, child: const Text('List Objects')),
                ElevatedButton(onPressed: _uploadToSub, child: const Text('Upload to sub')),
                ElevatedButton(onPressed: _uploadPrivate, child: const Text('Upload private')),
                ElevatedButton(onPressed: _showJwtClaims, child: const Text('Show JWT Claims')),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _log.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(_log[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 