// User preferences queue service for handling user preference updates
// Implements queue-based upload system similar to CalDAV sync

import 'dart:async';
import 'package:hive_ce/hive.dart';
import '../../../core/result.dart';
import '../../../core/logger.dart';
import '../../models/user_preferences.dart';
import '../../repositories/user_repository.dart';
import '../storage/local_storage_service.dart';
import 'user_sync_service.dart';

part 'user_preferences_queue_service.g.dart';

@HiveType(typeId: 40)
enum UserPreferencesOperation {
  @HiveField(0)
  upload,
}

@HiveType(typeId: 41)
class UserPreferencesQueueItem extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final UserPreferencesOperation operation;
  
  @HiveField(2)
  final UserPreferences data;
  
  @HiveField(3)
  final DateTime createdAt;
  
  @HiveField(4)
  final int retryCount;

    // Next time this item can be attempted (exponential backoff gate)
    @HiveField(5)
    final DateTime? nextAttemptAt;

  UserPreferencesQueueItem({
    required this.id,
    required this.operation,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.nextAttemptAt,
  });

  UserPreferencesQueueItem copyWith({
    int? retryCount,
    DateTime? nextAttemptAt,
  }) {
    return UserPreferencesQueueItem(
      id: id,
      operation: operation,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    );
  }
}

class UserPreferencesQueueService {
  // ignore: unused_field
  final UserRepository _userRepository;
  final UserSyncService _userSyncService;
  final LocalStorageService _localStorage;
  
  static const String _queueBoxName = 'user_preferences_queue';
  static const String _queueKey = 'queue_items';
  static const int _maxRetries = 3;

  UserPreferencesQueueService({
    required UserRepository userRepository,
    required UserSyncService userSyncService,
    required LocalStorageService localStorage,
  }) : _userRepository = userRepository,
       _userSyncService = userSyncService,
       _localStorage = localStorage;

  /// Add user preferences update to queue
  Future<Result<void>> queueUserPreferencesUpdate(UserPreferences preferences) async {
    try {
      AppLogger.debug('UserPreferencesQueueService: Queuing user preferences update');
      
      final queueItem = UserPreferencesQueueItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        operation: UserPreferencesOperation.upload,
        data: preferences,
        createdAt: DateTime.now(),
      );

      final currentQueue = await _getQueue();
      currentQueue.add(queueItem);
      
      final result = await _localStorage.put(
        _queueBoxName,
        _queueKey,
        currentQueue,
      );

      return result.when(
        success: (_) {
          AppLogger.debug('UserPreferencesQueueService: Successfully queued user preferences update');
          return const Result.success(null);
        },
        failure: (failure) => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('UserPreferencesQueueService: Failed to queue user preferences update', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to queue user preferences update: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Process all queued user preferences operations
  Future<Result<void>> processQueue() async {
    try {
      AppLogger.debug('UserPreferencesQueueService: Processing user preferences queue');
      
      final queue = await _getQueue();
      if (queue.isEmpty) {
        AppLogger.debug('UserPreferencesQueueService: Queue is empty, nothing to process');
        return const Result.failure(Failure(
          message: 'Queue is empty, nothing to process'
        ));
      }

      final now = DateTime.now();
      final updatedItemsById = <String, UserPreferencesQueueItem>{};
      final successfulIds = <String>{};
      final failedIds = <String>{};

      for (final item in queue) {
        // Respect backoff gate
        if (item.nextAttemptAt != null && now.isBefore(item.nextAttemptAt!)) {
          continue; // leave untouched in queue
        }

        final result = await _processQueueItem(item);
        final isSuccess = result.when(success: (_) => true, failure: (_) => false);

        if (isSuccess) {
          successfulIds.add(item.id);
        } else {
          if (item.retryCount >= _maxRetries) {
            AppLogger.warning('UserPreferencesQueueService: Item ${item.id} exceeded max retries, dropping');
            failedIds.add(item.id);
          } else {
            // Exponential backoff with jitter: base 2s, 2^retryCount, capped at 16s, ±20%
            final base = const Duration(seconds: 2);
            final exponent = (1 << item.retryCount).clamp(1, 8); // 1,2,4,8 with cap helper
            Duration rawDelay = Duration(seconds: base.inSeconds * exponent);
            if (rawDelay.inSeconds > 16) rawDelay = const Duration(seconds: 16);
            final jitterFactor = 0.8 + (DateTime.now().microsecondsSinceEpoch % 401) / 1000.0; // ~0.8..1.201
            final jittered = Duration(milliseconds: (rawDelay.inMilliseconds * jitterFactor).round());
            final updatedItem = item.copyWith(
              retryCount: item.retryCount + 1,
              nextAttemptAt: now.add(jittered < const Duration(seconds: 2) ? const Duration(seconds: 2) : jittered),
            );
            updatedItemsById[item.id] = updatedItem;
          }
        }
      }

      // Rebuild queue with updates, removing successes and exceeded failures
      final updatedQueue = <UserPreferencesQueueItem>[];
      for (final original in queue) {
        if (successfulIds.contains(original.id)) {
          continue; // drop successes
        }
        if (failedIds.contains(original.id)) {
          continue; // drop exceeded
        }
        final updated = updatedItemsById[original.id];
        updatedQueue.add(updated ?? original);
      }

      await _localStorage.put(_queueBoxName, _queueKey, updatedQueue);

      AppLogger.info('UserPreferencesQueueService: Processed ${successfulIds.length} items, ${failedIds.length} dropped, queue size now ${updatedQueue.length}');

      // Only report success ("changes") when something actually happened
      if (successfulIds.isNotEmpty || failedIds.isNotEmpty) {
        return const Result.success(null);
      }

      // No item was processed this cycle (e.g., all were gated by backoff) → report no-op
      return const Result.failure(Failure(message: 'No user preferences queue items processed'));
    } catch (e, stackTrace) {
      AppLogger.error('UserPreferencesQueueService: Failed to process queue', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to process user preferences queue: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Process a single queue item
  Future<Result<void>> _processQueueItem(UserPreferencesQueueItem item) async {
    try {
      AppLogger.debug('UserPreferencesQueueService: Processing item ${item.id} (retry ${item.retryCount})');
      
      switch (item.operation) {
        case UserPreferencesOperation.upload:
          final result = await _userSyncService.uploadUserData();
          return result.when(
            success: (_) {
              AppLogger.debug('UserPreferencesQueueService: Successfully processed upload item ${item.id}');
              return const Result.success(null);
            },
            failure: (failure) {
              AppLogger.warning('UserPreferencesQueueService: Failed to process upload item ${item.id}: ${failure.message}');
              return Result.failure(failure);
            },
          );
      }
    } catch (e, stackTrace) {
      AppLogger.error('UserPreferencesQueueService: Error processing item ${item.id}', e, stackTrace);
      return Result.failure(Failure(
        message: 'Error processing queue item: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get current queue from storage
  Future<List<UserPreferencesQueueItem>> _getQueue() async {
    try {
      // Use dynamic to avoid generic cast issues from Hive returning List<dynamic>
      final result = await _localStorage.get<dynamic>(_queueBoxName, _queueKey);
      return result.when(
        success: (raw) {
          if (raw == null) return <UserPreferencesQueueItem>[];
          if (raw is List<UserPreferencesQueueItem>) return raw;
          if (raw is List) {
            // Defensive conversion from List<dynamic> -> List<UserPreferencesQueueItem>
            final items = <UserPreferencesQueueItem>[];
            for (final e in raw) {
              if (e is UserPreferencesQueueItem) {
                items.add(e);
              } else {
                // Unknown element type; log once and skip
                AppLogger.warning('UserPreferencesQueueService: Unexpected element type in queue list: ${e.runtimeType}');
              }
            }
            return items;
          }
          // Unexpected type stored under the key; log and return empty
          AppLogger.warning('UserPreferencesQueueService: Unexpected stored type for queue: ${raw.runtimeType}');
          return <UserPreferencesQueueItem>[];
        },
        failure: (_) => <UserPreferencesQueueItem>[],
      );
    } catch (e) {
      AppLogger.warning('UserPreferencesQueueService: Failed to get queue, returning empty list: $e');
      return [];
    }
  }

  /// Clear the queue (useful for testing or reset)
  Future<Result<void>> clearQueue() async {
    try {
      final result = await _localStorage.put(_queueBoxName, _queueKey, <UserPreferencesQueueItem>[]);
      return result.when(
        success: (_) {
          AppLogger.debug('UserPreferencesQueueService: Queue cleared');
          return const Result.success(null);
        },
        failure: (failure) => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('UserPreferencesQueueService: Failed to clear queue', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to clear queue: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }
} 