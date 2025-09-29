// External account queue service for handling external credentials updates
// Uses a simple list of Map<String, dynamic> to avoid Hive type adapters

import 'dart:async';
import '../../repositories/external_account_repository.dart';
import '../storage/local_storage_service.dart';
import '../../../core/result.dart';
import '../../../core/logger.dart';
import 'user_sync_service.dart';

class ExternalAccountQueueService {
  final ExternalAccountRepository _externalAccountRepository;
  final UserSyncService _userSyncService;
  final LocalStorageService _localStorage;

  static const String _queueBoxName = LocalStorageService.externalAccountQueueBoxName;
  static const String _queueKey = 'queue_items';
  static const int _maxRetries = 3;

  ExternalAccountQueueService({
    required ExternalAccountRepository externalAccountRepository,
    required UserSyncService userSyncService,
    required LocalStorageService localStorage,
  })  : _externalAccountRepository = externalAccountRepository,
        _userSyncService = userSyncService,
        _localStorage = localStorage;

  // Enqueue a credentials upload operation (no payload needed; we serialize from repositories)
  Future<Result<void>> queueUpload() async {
    try {
      AppLogger.debug('ExternalAccountQueueService: Queuing external credentials upload');
      final item = <String, dynamic>{
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'op': 'upload',
        'createdAt': DateTime.now().toIso8601String(),
        'retry': 0,
        'next': null,
      };
      final queue = await _getQueue();
      queue.add(item);
      final result = await _localStorage.put<List<Map<String, dynamic>>>(_queueBoxName, _queueKey, queue);
      return result.when(
        success: (_) => const Result.success(null),
        failure: (f) => Result.failure(f),
      );
    } catch (e, st) {
      AppLogger.error('ExternalAccountQueueService: Failed to queue upload', e, st);
      return Result.failure(Failure(message: 'Failed to queue upload: $e', exception: e is Exception ? e : Exception('$e'), stackTrace: st));
    }
  }

  Future<Result<void>> processQueue() async {
    try {
      AppLogger.debug('ExternalAccountQueueService: Processing queue');
      final queue = await _getQueue();
      if (queue.isEmpty) {
        return const Result.failure(Failure(message: 'Queue is empty, nothing to process'));
      }
      final now = DateTime.now();
      final updatedById = <String, Map<String, dynamic>>{};
      final successIds = <String>{};
      final dropIds = <String>{};

      for (final item in queue) {
        final nextIso = item['next'] as String?;
        if (nextIso != null && now.isBefore(DateTime.tryParse(nextIso) ?? now)) {
          continue;
        }
        final op = item['op'] as String?;
        if (op == 'upload') {
          final res = await _userSyncService.uploadExternalCredentialsOnly();
          final ok = res.when(success: (_) => true, failure: (_) => false);
          if (ok) {
            successIds.add(item['id'] as String);
          } else {
            final retry = (item['retry'] as int? ?? 0);
            if (retry >= _maxRetries) {
              dropIds.add(item['id'] as String);
            } else {
              final base = const Duration(seconds: 2);
              final exponent = (1 << retry).clamp(1, 8);
              var delay = Duration(seconds: base.inSeconds * exponent);
              if (delay.inSeconds > 16) delay = const Duration(seconds: 16);
              final jitterFactor = 0.8 + (DateTime.now().microsecondsSinceEpoch % 401) / 1000.0;
              final jittered = Duration(milliseconds: (delay.inMilliseconds * jitterFactor).round());
              final next = now.add(jittered < const Duration(seconds: 2) ? const Duration(seconds: 2) : jittered);
              final updated = Map<String, dynamic>.from(item);
              updated['retry'] = retry + 1;
              updated['next'] = next.toIso8601String();
              updatedById[item['id'] as String] = updated;
            }
          }
        } else {
          // Unknown op -> drop
          dropIds.add(item['id'] as String);
        }
      }

      final rebuilt = <Map<String, dynamic>>[];
      for (final original in queue) {
        final id = original['id'] as String?;
        if (id == null) continue;
        if (successIds.contains(id) || dropIds.contains(id)) continue;
        rebuilt.add(updatedById[id] ?? original);
      }
      await _localStorage.put<List<Map<String, dynamic>>>(_queueBoxName, _queueKey, rebuilt);
      if (successIds.isNotEmpty || dropIds.isNotEmpty) {
        return const Result.success(null);
      }
      return const Result.failure(Failure(message: 'No external account queue items processed'));
    } catch (e, st) {
      AppLogger.error('ExternalAccountQueueService: Failed to process queue', e, st);
      return Result.failure(Failure(message: 'Failed to process external account queue: $e', exception: e is Exception ? e : Exception('$e'), stackTrace: st));
    }
  }

  Future<List<Map<String, dynamic>>> _getQueue() async {
    try {
      final res = await _localStorage.get<List<dynamic>>(_queueBoxName, _queueKey);
      return res.when(
        success: (raw) {
          if (raw == null) return <Map<String, dynamic>>[];
          final out = <Map<String, dynamic>>[];
          for (final e in raw) {
            if (e is Map) {
              final map = <String, dynamic>{};
              e.forEach((k, v) => map[k.toString()] = v);
              out.add(map);
            }
          }
          return out;
        },
        failure: (_) => <Map<String, dynamic>>[],
      );
    } catch (e) {
      AppLogger.warning('ExternalAccountQueueService: Failed to get queue, returning empty list: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<Result<void>> clearQueue() async {
    try {
      return await _localStorage.put<List<Map<String, dynamic>>>(_queueBoxName, _queueKey, <Map<String, dynamic>>[]);
    } catch (e, st) {
      return Result.failure(Failure(message: 'Failed to clear external queue: $e', exception: e is Exception ? e : Exception('$e'), stackTrace: st));
    }
  }
}
