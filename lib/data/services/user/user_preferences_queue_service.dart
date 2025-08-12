// User preferences queue service for handling user preference updates
// Implements queue-based upload system similar to CalDAV sync

import 'dart:async';
import 'package:hive/hive.dart';
import '../../../core/result.dart';
import '../../../core/logger.dart';
import '../../models/user_preferences.dart';
import '../../repositories/user_repository.dart';
import '../storage/local_storage_service.dart';
import 'user_sync_service.dart';

part '../user/user_preferences_queue_service.g.dart';

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

  UserPreferencesQueueItem({
    required this.id,
    required this.operation,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  UserPreferencesQueueItem copyWith({
    int? retryCount,
  }) {
    return UserPreferencesQueueItem(
      id: id,
      operation: operation,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

class UserPreferencesQueueService {
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

      final processedItems = <UserPreferencesQueueItem>[];
      final failedItems = <UserPreferencesQueueItem>[];

      for (final item in queue) {
        final result = await _processQueueItem(item);
        
        final isSuccess = result.when(
          success: (_) => true,
          failure: (_) => false,
        );
        
        if (isSuccess) {
          processedItems.add(item);
        } else {
          if (item.retryCount >= _maxRetries) {
            AppLogger.warning('UserPreferencesQueueService: Item ${item.id} exceeded max retries, marking as failed');
            failedItems.add(item);
          } else {
            // Increment retry count and keep in queue
            final updatedItem = item.copyWith(retryCount: item.retryCount + 1);
            processedItems.add(updatedItem);
          }
        }
      }

      // Remove processed items from queue
      queue.removeWhere((item) => processedItems.contains(item));
      
      // Save updated queue
      await _localStorage.put(_queueBoxName, _queueKey, queue);

      AppLogger.info('UserPreferencesQueueService: Processed ${processedItems.length} items, ${failedItems.length} failed');
      return const Result.success(null);
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
      final result = await _localStorage.get<List<UserPreferencesQueueItem>>(_queueBoxName, _queueKey);
      return result.when(
        success: (queue) => queue ?? [],
        failure: (_) => [],
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