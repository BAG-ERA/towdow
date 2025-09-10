// External account repository interface and local implementation
// Follows repository pattern for external CalDAV account data access
// External accounts are read-only CalDAV connections for calendar integration

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/external_caldav_account.dart';
import '../services/storage/local_storage_service.dart';

// Abstract repository interface
abstract class ExternalAccountRepository {
  Future<Result<List<ExternalCaldavAccount>>> getAll();
  Future<Result<ExternalCaldavAccount?>> getById(String id);
  Future<Result<void>> save(ExternalCaldavAccount account);
  Future<Result<void>> delete(String id);
  Stream<List<ExternalCaldavAccount>> watchAccounts();
  Future<Result<List<ExternalCaldavAccount>>> getActiveAccounts();
  Future<Result<ExternalCaldavAccount?>> getByServerAndUsername(String serverUrl, String username);
  Future<Result<void>> updateSyncStatus(String id, {
    DateTime? lastSyncAt,
    DateTime? lastSuccessfulSync,
    String? lastSyncError,
    int? syncErrorCount,
    int? totalCalendars,
    int? activeCalendars,
    int? totalEvents,
    DateTime? lastEventSync,
  });
  Future<Result<void>> updateAuthInfo(String id, {
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiry,
  });
  Future<Result<void>> setActive(String id, bool active);
  Future<Result<List<ExternalCaldavAccount>>> getAccountsWithErrors();
  Future<Result<List<ExternalCaldavAccount>>> getAccountsNeedingRefresh();
  
  // Etag methods for S3 sync tracking
  Future<Result<String?>> getEtag(String id);
  Future<Result<void>> setEtag(String id, String? etag);
  
  // Global file etag methods for external credentials file sync tracking
  Future<Result<String?>> getCredentialsFileEtag();
  Future<Result<void>> setCredentialsFileEtag(String? etag);
}

// Local implementation using Hive
class LocalExternalAccountRepository implements ExternalAccountRepository {
  final LocalStorageService _storageService;
  static const String _boxName = 'external_accounts';

  LocalExternalAccountRepository(this._storageService);

  @override
  Future<Result<List<ExternalCaldavAccount>>> getAll() async {
    final result = await _storageService.getAll<ExternalCaldavAccount>(_boxName);
    return result.when(
      success: (accounts) {
        AppLogger.info('LocalExternalAccountRepository: Found ${accounts.length} external accounts');
        return Result.success(accounts);
      },
      failure: (failure) {
        AppLogger.error('LocalExternalAccountRepository: Failed to get external accounts: ${failure.message}');
        return Result.failure(failure);
      },
    );
  }

  @override
  Future<Result<ExternalCaldavAccount?>> getById(String id) async {
    return await _storageService.get<ExternalCaldavAccount>(_boxName, id);
  }

  @override
  Future<Result<void>> save(ExternalCaldavAccount account) async {
    // Save account
    final res = await _storageService.put(_boxName, account.id, account);
    // Mark local modification: clear global credentials file ETag to force next upload
    await _storageService.put<String?>(_boxName, 'credentials_file_etag', null);
    // Enqueue an external credentials upload so it gets pushed promptly
    final queueItem = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'op': 'upload',
      'createdAt': DateTime.now().toIso8601String(),
      'retry': 0,
      'next': null,
    };
    // Read current queue, append, and save back
    final queueRes = await _storageService.get<List<dynamic>>(LocalStorageService.externalAccountQueueBoxName, 'queue_items');
    final currentQueue = queueRes.when(
      success: (raw) {
        final list = <Map<String, dynamic>>[];
        if (raw != null) {
          for (final e in raw) {
            if (e is Map) {
              final map = <String, dynamic>{};
              e.forEach((k, v) => map[k.toString()] = v);
              list.add(map);
            }
          }
        }
        return list;
      },
      failure: (_) => <Map<String, dynamic>>[],
    );
    currentQueue.add(queueItem);
    await _storageService.put<List<Map<String, dynamic>>>(LocalStorageService.externalAccountQueueBoxName, 'queue_items', currentQueue);
    return res;
  }

  @override
  Future<Result<void>> delete(String id) async {
    final res = await _storageService.delete(_boxName, id);
    // Mark local modification: clear global credentials file ETag to force next upload
    await _storageService.put<String?>(_boxName, 'credentials_file_etag', null);
    // Enqueue an external credentials upload so it gets pushed promptly
    final queueItem = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'op': 'upload',
      'createdAt': DateTime.now().toIso8601String(),
      'retry': 0,
      'next': null,
    };
    // Read current queue, append, and save back
    final queueRes = await _storageService.get<List<dynamic>>(LocalStorageService.externalAccountQueueBoxName, 'queue_items');
    final currentQueue = queueRes.when(
      success: (raw) {
        final list = <Map<String, dynamic>>[];
        if (raw != null) {
          for (final e in raw) {
            if (e is Map) {
              final map = <String, dynamic>{};
              e.forEach((k, v) => map[k.toString()] = v);
              list.add(map);
            }
          }
        }
        return list;
      },
      failure: (_) => <Map<String, dynamic>>[],
    );
    currentQueue.add(queueItem);
    await _storageService.put<List<Map<String, dynamic>>>(LocalStorageService.externalAccountQueueBoxName, 'queue_items', currentQueue);
    return res;
  }

  @override
  Stream<List<ExternalCaldavAccount>> watchAccounts() async* {
    // Emit initial value
    final result = await getAll();
    yield result.when(
      success: (accounts) => accounts,
      failure: (_) => <ExternalCaldavAccount>[],
    );
    
    // Then listen to changes
    yield* _storageService.getStream(_boxName)
        .asyncMap((_) async {
          final result = await getAll();
          return result.when(
            success: (accounts) => accounts,
            failure: (_) => <ExternalCaldavAccount>[],
          );
        });
  }

  @override
  Future<Result<List<ExternalCaldavAccount>>> getActiveAccounts() async {
    final result = await getAll();
    return result.when(
      success: (accounts) {
        final activeAccounts = accounts.where((a) => a.isActive).toList();
        AppLogger.info('LocalExternalAccountRepository: Found ${activeAccounts.length} active external accounts');
        return Result.success(activeAccounts);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<ExternalCaldavAccount?>> getByServerAndUsername(String serverUrl, String username) async {
    final result = await getAll();
    return result.when(
      success: (accounts) {
        final account = accounts.where((a) => 
            a.serverUrl == serverUrl && a.username == username).firstOrNull;
        return Result.success(account);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> updateSyncStatus(String id, {
    DateTime? lastSyncAt,
    DateTime? lastSuccessfulSync,
    String? lastSyncError,
    int? syncErrorCount,
    int? totalCalendars,
    int? activeCalendars,
    int? totalEvents,
    DateTime? lastEventSync,
  }) async {
    final getResult = await getById(id);
    return getResult.when(
      success: (account) async {
        if (account != null) {
          final updatedAccount = account.withSyncUpdate(
            lastSyncAt: lastSyncAt,
            lastSuccessfulSync: lastSuccessfulSync,
            lastSyncError: lastSyncError,
            syncErrorCount: syncErrorCount,
            totalCalendars: totalCalendars,
            activeCalendars: activeCalendars,
            totalEvents: totalEvents,
            lastEventSync: lastEventSync,
          );
          return await save(updatedAccount);
        } else {
          return Result.failure(Failure(
            message: 'Account not found: $id',
            exception: Exception('Account not found'),
          ));
        }
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> updateAuthInfo(String id, {
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiry,
  }) async {
    final getResult = await getById(id);
    return getResult.when(
      success: (account) async {
        if (account != null) {
          final updatedAccount = account.withAuthRefresh(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenExpiry: tokenExpiry,
          );
          return await save(updatedAccount);
        } else {
          return Result.failure(Failure(
            message: 'Account not found: $id',
            exception: Exception('Account not found'),
          ));
        }
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> setActive(String id, bool active) async {
    final getResult = await getById(id);
    return getResult.when(
      success: (account) async {
        if (account != null) {
          final updatedAccount = account.withActive(active);
          return await save(updatedAccount);
        } else {
          return Result.failure(Failure(
            message: 'Account not found: $id',
            exception: Exception('Account not found'),
          ));
        }
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<ExternalCaldavAccount>>> getAccountsWithErrors() async {
    final result = await getActiveAccounts();
    return result.when(
      success: (accounts) {
        final errorAccounts = accounts.where((a) => a.hasSyncErrors).toList();
        AppLogger.info('LocalExternalAccountRepository: Found ${errorAccounts.length} accounts with sync errors');
        return Result.success(errorAccounts);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<ExternalCaldavAccount>>> getAccountsNeedingRefresh() async {
    final result = await getActiveAccounts();
    return result.when(
      success: (accounts) {
        final needingRefreshAccounts = accounts.where((a) => a.needsAuthRefresh).toList();
        AppLogger.info('LocalExternalAccountRepository: Found ${needingRefreshAccounts.length} accounts needing auth refresh');
        return Result.success(needingRefreshAccounts);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<String?>> getEtag(String id) async {
    final getResult = await getById(id);
    return getResult.when(
      success: (account) => Result.success(account?.etag),
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> setEtag(String id, String? etag) async {
    final getResult = await getById(id);
    return getResult.when(
      success: (account) async {
        if (account != null) {
          final updatedAccount = account.withEtag(etag);
          return await save(updatedAccount);
        } else {
          return Result.failure(Failure(
            message: 'Account not found: $id',
            exception: Exception('Account not found'),
          ));
        }
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<String?>> getCredentialsFileEtag() async {
    return await _storageService.get<String>(_boxName, 'credentials_file_etag');
  }

  @override
  Future<Result<void>> setCredentialsFileEtag(String? etag) async {
    return await _storageService.put(_boxName, 'credentials_file_etag', etag);
  }
}

// Extension for external account repository operations
extension ExternalAccountRepositoryExtensions on ExternalAccountRepository {
  /// Get accounts that are ready for sync (active and not in error state)
  Future<Result<List<ExternalCaldavAccount>>> getAccountsReadyForSync() async {
    final result = await getActiveAccounts();
    return result.when(
      success: (accounts) {
        final readyAccounts = accounts.where((account) {
          // Account is ready if it's active, supports VEVENT, and doesn't need auth refresh
          return account.isActive && 
                 account.supportsVEvent && 
                 !account.needsAuthRefresh &&
                 account.syncErrorCount < 5; // Don't sync accounts with too many errors
        }).toList();
        
        return Result.success(readyAccounts);
      },
      failure: (failure) => Result.failure(failure),
    );
  }
  
  /// Get accounts that need sync (ready for sync and haven't synced recently)
  Future<Result<List<ExternalCaldavAccount>>> getAccountsNeedingSync({Duration? maxAge}) async {
    final result = await getAccountsReadyForSync();
    return result.when(
      success: (accounts) {
        final now = DateTime.now();
        final maxSyncAge = maxAge ?? Duration(seconds: accounts.isNotEmpty ? accounts.first.syncIntervalSeconds : 300);
        
        final needingSyncAccounts = accounts.where((account) {
          // Include accounts that have never synced or haven't synced recently
          if (account.lastSyncAt == null) return true;
          
          final timeSinceSync = now.difference(account.lastSyncAt!);
          return timeSinceSync.inSeconds > account.syncIntervalSeconds;
        }).toList();
        
        return Result.success(needingSyncAccounts);
      },
      failure: (failure) => Result.failure(failure),
    );
  }
  
  /// Check if an account already exists for the given server and username
  Future<Result<bool>> accountExists(String serverUrl, String username) async {
    final result = await getByServerAndUsername(serverUrl, username);
    return result.when(
      success: (account) => Result.success(account != null),
      failure: (failure) => Result.failure(failure),
    );
  }
  
  /// Record sync error for an account
  Future<Result<void>> recordSyncError(String id, String error) async {
    final getResult = await getById(id);
    return getResult.when(
      success: (account) async {
        if (account != null) {
          final updatedAccount = account.withError(error);
          return await save(updatedAccount);
        } else {
          return Result.failure(Failure(
            message: 'Account not found: $id',
            exception: Exception('Account not found'),
          ));
        }
      },
      failure: (failure) => Result.failure(failure),
    );
  }
  
  /// Record successful sync for an account
  Future<Result<void>> recordSuccessfulSync(String id, {
    int? totalCalendars,
    int? activeCalendars, 
    int? totalEvents,
  }) async {
    return await updateSyncStatus(
      id,
      lastSyncAt: DateTime.now(),
      lastSuccessfulSync: DateTime.now(),
      lastSyncError: null, // Clear error on successful sync
      syncErrorCount: 0, // Reset error count
      totalCalendars: totalCalendars,
      activeCalendars: activeCalendars,
      totalEvents: totalEvents,
      lastEventSync: DateTime.now(),
    );
  }
} 