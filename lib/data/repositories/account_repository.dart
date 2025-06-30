// Account Repository for managing CalDAV account configurations
// Handles account storage, retrieval, and connection status

import '../models/caldav_account.dart';
import '../services/local_storage_service.dart';
import '../../core/result.dart';
import '../../core/logger.dart';

abstract class AccountRepository {
  Future<Result<List<CaldavAccount>>> getAll();
  Future<Result<CaldavAccount?>> getActiveAccount();
  Future<Result<void>> save(CaldavAccount account);
  Future<Result<void>> delete(String accountId);
  Future<Result<void>> setActiveAccount(String accountId);
  Future<Result<bool>> hasActiveAccount();
}

class LocalAccountRepository implements AccountRepository {
  final LocalStorageService _storageService;

  LocalAccountRepository(this._storageService);

  @override
  Future<Result<List<CaldavAccount>>> getAll() async {
    // AppLogger.debug('LocalAccountRepository: Getting all accounts');
    
    try {
      final result = await _storageService.getAll<CaldavAccount>(LocalStorageService.accountsBoxName);
      return result.when(
        success: (accounts) {
          // AppLogger.info('LocalAccountRepository: Found ${accounts.length} accounts');
          return Result.success(accounts);
        },
        failure: (failure) {
          AppLogger.error('LocalAccountRepository: Failed to get accounts', failure.message);
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('LocalAccountRepository: Exception getting accounts', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to get accounts: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<CaldavAccount?>> getActiveAccount() async {
    // AppLogger.debug('LocalAccountRepository: Getting active account');
    
    try {
      final result = await getAll();
      return result.when(
        success: (accounts) {
          final activeAccount = accounts.where((a) => a.isActive).firstOrNull;
          if (activeAccount != null) {
            // AppLogger.info('LocalAccountRepository: Active account: ${activeAccount.serverUrl}');
                  // AppLogger.info('LocalAccountRepository: Account found with ID: ${activeAccount.id}');
      // AppLogger.info('LocalAccountRepository: Server: ${activeAccount.serverUrl}');
            return Result.success(activeAccount);
                     } else {
             AppLogger.warning('LocalAccountRepository: No active account found');
             return Result.failure(const Failure(message: 'No active account found'));
           }
        },
                 failure: (failure) {
           AppLogger.error('LocalAccountRepository: Failed to get active account: ${failure.message}');
           return Result.failure(failure);
         },
      );
    } catch (e, stackTrace) {
      AppLogger.error('LocalAccountRepository: Exception getting active account', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to get active account: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<void>> save(CaldavAccount account) async {
    // AppLogger.info('LocalAccountRepository: Saving account: ${account.serverUrl}');
    
    try {
      final result = await _storageService.put<CaldavAccount>(
        LocalStorageService.accountsBoxName, 
        account.id, 
        account
      );
      return result.when(
        success: (_) {
          // AppLogger.info('LocalAccountRepository: Account saved successfully');
          return Result.success(null);
        },
        failure: (failure) {
          AppLogger.error('LocalAccountRepository: Failed to save account', failure.message);
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('LocalAccountRepository: Exception saving account', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to save account: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<void>> delete(String accountId) async {
    // AppLogger.info('LocalAccountRepository: Deleting account: $accountId');
    
    try {
      final result = await _storageService.delete(LocalStorageService.accountsBoxName, accountId);
      return result.when(
        success: (_) {
          // AppLogger.info('LocalAccountRepository: Account deleted successfully');
          return Result.success(null);
        },
        failure: (failure) {
          AppLogger.error('LocalAccountRepository: Failed to delete account', failure.message);
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('LocalAccountRepository: Exception deleting account', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to delete account: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<void>> setActiveAccount(String accountId) async {
    // AppLogger.info('LocalAccountRepository: Setting active account: $accountId');
    
    try {
      // Get all accounts
      final allAccountsResult = await getAll();
      return allAccountsResult.when(
        success: (accounts) async {
          // Deactivate all accounts first
          for (final account in accounts) {
            final deactivatedAccount = account.copyWith(isActive: false);
            await _storageService.put<CaldavAccount>(
              LocalStorageService.accountsBoxName,
              deactivatedAccount.id,
              deactivatedAccount
            );
          }
          
          // Activate the specified account
          final targetAccount = accounts.where((a) => a.id == accountId).firstOrNull;
          if (targetAccount != null) {
            final activatedAccount = targetAccount.copyWith(isActive: true);
            final saveResult = await _storageService.put<CaldavAccount>(
              LocalStorageService.accountsBoxName,
              activatedAccount.id,
              activatedAccount
            );
            return saveResult.when(
              success: (_) {
                // AppLogger.info('LocalAccountRepository: Account activated successfully');
                return Result.success(null);
              },
              failure: (failure) => Result.failure(failure),
            );
          } else {
            return Result.failure(Failure(message: 'Account not found: $accountId'));
          }
        },
        failure: (failure) => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('LocalAccountRepository: Exception setting active account', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to set active account: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<bool>> hasActiveAccount() async {
    // AppLogger.debug('LocalAccountRepository: Checking for active account');
    
    try {
      final result = await getActiveAccount();
      return result.when(
        success: (account) {
          final hasActive = account != null;
          // AppLogger.info('LocalAccountRepository: Has active account: $hasActive');
          return Result.success(hasActive);
        },
        failure: (failure) {
          AppLogger.warning('LocalAccountRepository: Failed to check active account, assuming false');
          return Result.success(false);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('LocalAccountRepository: Exception checking active account', e, stackTrace);
      return Result.success(false);
    }
  }
} 
