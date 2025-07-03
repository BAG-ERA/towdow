// Local storage service using Hive for offline-first data persistence
// Provides generic CRUD operations for all FlowIt models

import 'package:hive_flutter/hive_flutter.dart';
import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/caldav_account.dart';

class LocalStorageService {
  static const String tasksBoxName = 'tasks';
  static const String projectsBoxName = 'projects'; // DEPRECATED - kept for migration
  static const String calendarsBoxName = 'calendars'; // Replaces projects
  static const String automatedTasksBoxName = 'automated_tasks';
  static const String accountsBoxName = 'accounts';
  static const String syncQueueBoxName = 'sync_queue';
  static const String domainsBoxName = 'domains'; // For storing domain names
  static const String statusesBoxName = 'statuses'; // For storing status names
  static const String userPreferencesBoxName = 'user_preferences'; // For storing user preferences

  // Box references
  late Box _tasksBox;
  late Box _projectsBox; // DEPRECATED - kept for migration
  late Box _calendarsBox; // New calendar box
  late Box _automatedTasksBox;
  late Box _accountsBox;
  late Box _syncQueueBox;
  late Box _domainsBox;
  late Box _statusesBox;
  late Box _userPreferencesBox;

  // Initialize all Hive boxes
  Future<Result<void>> initialize() async {
    try {
      // AppLogger.info('LocalStorageService: Initializing Hive boxes');
      
      // Try to open boxes, but handle corrupted data gracefully
      await _initializeBoxSafely(tasksBoxName, 'tasks');
      await _initializeBoxSafely(projectsBoxName, 'projects'); 
      await _initializeBoxSafely(calendarsBoxName, 'calendars');
      await _initializeBoxSafely(automatedTasksBoxName, 'automated_tasks');
      await _initializeBoxSafely(accountsBoxName, 'accounts');
      await _initializeBoxSafely(syncQueueBoxName, 'sync_queue');
      await _initializeBoxSafely(domainsBoxName, 'domains');
      await _initializeBoxSafely(statusesBoxName, 'statuses');
      await _initializeBoxSafely(userPreferencesBoxName, 'user_preferences');

      // Assign the boxes after successful initialization
      _tasksBox = Hive.box(tasksBoxName);
      _projectsBox = Hive.box(projectsBoxName);
      _calendarsBox = Hive.box(calendarsBoxName);
      _automatedTasksBox = Hive.box(automatedTasksBoxName);
      _accountsBox = Hive.box(accountsBoxName);
      _syncQueueBox = Hive.box(syncQueueBoxName);
      _domainsBox = Hive.box(domainsBoxName);
      _statusesBox = Hive.box(statusesBoxName);
      _userPreferencesBox = Hive.box(userPreferencesBoxName);

      // AppLogger.info('LocalStorageService: All boxes initialized successfully');
      return const Result.success(null);
    } catch (e, stackTrace) {
      AppLogger.error('LocalStorageService: Failed to initialize boxes', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to initialize local storage',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  // Initialize a single box safely, handling corrupted data
  Future<void> _initializeBoxSafely(String boxName, String description) async {
    try {
      // AppLogger.debug('LocalStorageService: Opening $description box');
      await Hive.openBox(boxName);
              // AppLogger.debug('LocalStorageService: Successfully opened $description box');
    } catch (e, _) {
      AppLogger.warning('LocalStorageService: $description box corrupted, attempting to recover', e);
      
      // If the box is corrupted, try to close any existing box first, then delete
      try {
        // Try to close the box if it exists
        if (Hive.isBoxOpen(boxName)) {
          // AppLogger.debug('LocalStorageService: Closing existing $description box');
          await Hive.box(boxName).close();
        }
        
        // Wait a bit for file handles to be released
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Now try to delete the corrupted box
        await Hive.deleteBoxFromDisk(boxName);
        // AppLogger.info('LocalStorageService: Deleted corrupted $description box');
        
        // Create a new clean box
        await Hive.openBox(boxName);
        // AppLogger.info('LocalStorageService: Successfully created new $description box');
      } catch (recoveryError, recoveryStack) {
        AppLogger.error('LocalStorageService: Failed to recover $description box', recoveryError, recoveryStack);
        
        // If we still can't delete the file, it might be locked by another process
        // In this case, we'll ask the user to restart the application
        if (recoveryError.toString().contains('errno = 32') || 
            recoveryError.toString().contains('utilisé par un autre processus')) {
          throw Exception(
            'Données locales corrompues détectées pour $description. '
            'Veuillez fermer complètement l\'application et la redémarrer. '
            'Si le problème persiste, supprimez manuellement les ${_getBoxPathMessage(boxName)}'
          );
        }
        rethrow;
      }
    }
  }

  // Helper method to get a generic path message for a Hive box file
  String _getBoxPathMessage(String boxName) {
    return 'fichiers Hive locaux ($boxName.hive dans le dossier Documents)';
  }

  // Generic get all items from a box
  Future<Result<List<T>>> getAll<T>(String boxName) async {
    try {
      // AppLogger.debug('LocalStorageService: Getting all items from $boxName');
      
      final box = _getBox(boxName);
      
      // Safe casting to handle corrupted data
      final items = <T>[];
      for (final value in box.values) {
        try {
          if (value is T) {
            items.add(value);
          } else if (value is Map && T == Map<String, dynamic>) {
            // Handle Map<dynamic, dynamic> to Map<String, dynamic> conversion
            final convertedMap = <String, dynamic>{};
            (value as Map).forEach((key, val) {
              convertedMap[key.toString()] = val;
            });
            items.add(convertedMap as T);
          } else {
            AppLogger.warning('LocalStorageService: Skipping invalid item in $boxName: ${value.runtimeType}');
          }
        } catch (e) {
          AppLogger.warning('LocalStorageService: Failed to cast item in $boxName', e);
        }
      }
      
              // AppLogger.debug('LocalStorageService: Found ${items.length} items in $boxName');
      return Result.success(items);
    } catch (e, stackTrace) {
      AppLogger.error('LocalStorageService: Failed to get all from $boxName', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to get all items from $boxName',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  // Generic put item in a box
  Future<Result<void>> put<T>(String boxName, String key, T item) async {
    try {
      // AppLogger.debug('LocalStorageService: Putting item with key $key in $boxName');
      
      final box = _getBox(boxName);
      await box.put(key, item);
      
              // AppLogger.debug('LocalStorageService: Successfully put item $key in $boxName');
      return const Result.success(null);
    } catch (e, stackTrace) {
      AppLogger.error('LocalStorageService: Failed to put item $key in $boxName', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to put item in $boxName',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  // Generic get item by key
  Future<Result<T?>> get<T>(String boxName, String key) async {
    try {
      // AppLogger.debug('LocalStorageService: Getting item with key $key from $boxName');
      
      final box = _getBox(boxName);
      final item = box.get(key) as T?;
      
              // AppLogger.debug('LocalStorageService: ${item != null ? 'Found' : 'Not found'} item $key in $boxName');
      return Result.success(item);
    } catch (e, stackTrace) {
      AppLogger.error('LocalStorageService: Failed to get item $key from $boxName', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to get item from $boxName',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  // Generic delete item by key
  Future<Result<void>> delete(String boxName, String key) async {
    try {
      // AppLogger.debug('LocalStorageService: Deleting item with key $key from $boxName');
      
      final box = _getBox(boxName);
      await box.delete(key);
      
              // AppLogger.debug('LocalStorageService: Successfully deleted item $key from $boxName');
      return const Result.success(null);
    } catch (e, stackTrace) {
      AppLogger.error('LocalStorageService: Failed to delete item $key from $boxName', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to delete item from $boxName',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  // Get reactive stream for a box
  Stream<BoxEvent> getStream(String boxName) {
    final box = _getBox(boxName);
    return box.watch();
  }

  // Clear all data from a box
  Future<Result<void>> clear(String boxName) async {
    try {
      AppLogger.warning('LocalStorageService: Clearing all data from $boxName');
      
      final box = _getBox(boxName);
      await box.clear();
      
      // AppLogger.info('LocalStorageService: Successfully cleared $boxName');
      return const Result.success(null);
    } catch (e, stackTrace) {
      AppLogger.error('LocalStorageService: Failed to clear $boxName', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to clear $boxName',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  // Fix corrupted data in boxes (development helper)
  Future<Result<void>> fixCorruptedData() async {
    try {
      AppLogger.warning('LocalStorageService: Fixing corrupted data in all boxes');
      
      // Clear tasks box that has corrupted Map data
      await clear(tasksBoxName);
      await clear(projectsBoxName);
      await clear(automatedTasksBoxName);
      
      // AppLogger.info('LocalStorageService: Successfully fixed corrupted data');
      return const Result.success(null);
    } catch (e, stackTrace) {
      AppLogger.error('LocalStorageService: Failed to fix corrupted data', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to fix corrupted data',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  // Clear ALL data from ALL boxes (complete reset)
  Future<Result<void>> clearAllData() async {
    try {
      AppLogger.warning('LocalStorageService: Clearing ALL data from ALL boxes');
      
      await clear(tasksBoxName);
      await clear(projectsBoxName);
      await clear(calendarsBoxName);
      await clear(automatedTasksBoxName);
      await clear(accountsBoxName);
      await clear(syncQueueBoxName);
      await clear(domainsBoxName);
      await clear(statusesBoxName);
      
      // AppLogger.info('LocalStorageService: Successfully cleared ALL data');
      return const Result.success(null);
    } catch (e, stackTrace) {
      AppLogger.error('LocalStorageService: Failed to clear all data', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to clear all data',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  // Emergency reset - close all boxes and delete them from disk
  Future<Result<void>> emergencyReset() async {
    try {
      AppLogger.warning('LocalStorageService: Performing emergency reset');
      
      final boxNames = [
        tasksBoxName,
        projectsBoxName,
        calendarsBoxName,
        automatedTasksBoxName,
        accountsBoxName,
        syncQueueBoxName,
        domainsBoxName,
        statusesBoxName,
      ];
      
      // Close all boxes first
      for (final boxName in boxNames) {
        try {
          if (Hive.isBoxOpen(boxName)) {
            // AppLogger.debug('LocalStorageService: Closing $boxName for emergency reset');
            await Hive.box(boxName).close();
          }
        } catch (e) {
          AppLogger.warning('LocalStorageService: Failed to close $boxName during emergency reset', e);
        }
      }
      
      // Wait for handles to be released
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Delete all boxes from disk
      for (final boxName in boxNames) {
        try {
          // AppLogger.debug('LocalStorageService: Deleting $boxName from disk');
          await Hive.deleteBoxFromDisk(boxName);
          // AppLogger.info('LocalStorageService: Successfully deleted $boxName');
        } catch (e) {
          AppLogger.warning('LocalStorageService: Failed to delete $boxName during emergency reset', e);
          // Continue with other boxes even if one fails
        }
      }
      
      // AppLogger.info('LocalStorageService: Emergency reset completed');
      return const Result.success(null);
    } catch (e, stackTrace) {
      AppLogger.error('LocalStorageService: Emergency reset failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'Emergency reset failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  // Helper method to get the correct box
  Box _getBox(String boxName) {
    switch (boxName) {
      case tasksBoxName:
        return _tasksBox;
      case projectsBoxName:
        return _projectsBox;
      case calendarsBoxName:
        return _calendarsBox;
      case automatedTasksBoxName:
        return _automatedTasksBox;
      case accountsBoxName:
        return _accountsBox;
      case syncQueueBoxName:
        return _syncQueueBox;
      case domainsBoxName:
        return _domainsBox;
      case statusesBoxName:
        return _statusesBox;
      case userPreferencesBoxName:
        return _userPreferencesBox;
      default:
        throw ArgumentError('Unknown box name: $boxName');
    }
  }

  // Close all boxes
  Future<void> close() async {
    // AppLogger.info('LocalStorageService: Closing all boxes');
    await Future.wait([
      _tasksBox.close(),
      _projectsBox.close(),
      _calendarsBox.close(),
      _automatedTasksBox.close(),
      _accountsBox.close(),
      _syncQueueBox.close(),
      _domainsBox.close(),
      _statusesBox.close(),
      _userPreferencesBox.close(),
    ]);
  }

  // Debug method to inspect all box contents
  Future<void> debugAllBoxes() async {
    // AppLogger.info('=== DEBUG: LocalStorageService Contents ===');
    
    // Debug raw box keys first
    try {
      // AppLogger.info('DEBUG: Raw box keys:');
      // AppLogger.info('  - Accounts box keys: ${_accountsBox.keys.toList()}');
      // AppLogger.info('  - Projects box keys: ${_projectsBox.keys.toList()}');
      // AppLogger.info('  - Tasks box keys: ${_tasksBox.keys.toList()}');
      // AppLogger.info('  - Sync queue box keys: ${_syncQueueBox.keys.toList()}');
      // AppLogger.info('  - Automated tasks box keys: ${_automatedTasksBox.keys.toList()}');
    } catch (e, stackTrace) {
      AppLogger.error('DEBUG: Exception getting raw keys', e, stackTrace);
    }
    
    // Debug accounts using direct Hive access
    try {
      if (_accountsBox.keys.isNotEmpty) {
        // AppLogger.info('DEBUG: Accounts in box:');
        for (final key in _accountsBox.keys) {
          try {
            final rawAccount = _accountsBox.get(key);
            // AppLogger.info('DEBUG: Account $key type: ${rawAccount.runtimeType}');
            
            // If it's a CaldavAccount, access its properties directly
            if (rawAccount is CaldavAccount) {
              // AppLogger.info('DEBUG: Account details:');
              // AppLogger.info('  - ID: ${rawAccount.id}');
              // AppLogger.info('  - Provider: ${rawAccount.providerType}');
              // AppLogger.info('  - Server: ${rawAccount.serverUrl}');
              // AppLogger.info('  - Username: ${rawAccount.username}');
              // AppLogger.info('  - Is Active: ${rawAccount.isActive}');
              // AppLogger.info('  - Provider Type: ${rawAccount.providerType}');
              // AppLogger.info('  - Is Active: ${rawAccount.isActive}');
              // AppLogger.info('  - Last Sync: ${rawAccount.lastSyncAt}');
            } else {
              // AppLogger.info('DEBUG: Raw account toString: ${rawAccount.toString()}');
            }
          } catch (e) {
            AppLogger.error('DEBUG: Error reading raw account $key: $e');
          }
        }
      } else {
        // AppLogger.info('DEBUG: No accounts in storage');
      }
    } catch (e, stackTrace) {
      AppLogger.error('DEBUG: Exception getting accounts', e, stackTrace);
    }

    // Debug projects using direct Hive access
    try {
      if (_projectsBox.keys.isNotEmpty) {
        // AppLogger.info('DEBUG: Projects in box:');
        for (final key in _projectsBox.keys) {
          try {
            final rawProject = _projectsBox.get(key);
            // AppLogger.info('DEBUG: Project $key type: ${rawProject.runtimeType}');
            // AppLogger.info('DEBUG: Project $key: ${rawProject.toString()}');
          } catch (e) {
            AppLogger.error('DEBUG: Error reading project $key: $e');
          }
        }
      } else {
        // AppLogger.info('DEBUG: No projects in storage');
      }
    } catch (e, stackTrace) {
      AppLogger.error('DEBUG: Exception getting projects', e, stackTrace);
    }

    // Debug tasks using direct Hive access
    try {
      if (_tasksBox.keys.isNotEmpty) {
        // AppLogger.info('DEBUG: Tasks in box:');
        for (final key in _tasksBox.keys) {
          try {
            final rawTask = _tasksBox.get(key);
            // AppLogger.info('DEBUG: Task $key type: ${rawTask.runtimeType}');
            // AppLogger.info('DEBUG: Task $key: ${rawTask.toString()}');
          } catch (e) {
            AppLogger.error('DEBUG: Error reading task $key: $e');
          }
        }
      } else {
        // AppLogger.info('DEBUG: No tasks in storage');
      }
    } catch (e, stackTrace) {
      AppLogger.error('DEBUG: Exception getting tasks', e, stackTrace);
    }

    // AppLogger.info('=== END DEBUG ===');
  }

  // Domain-specific methods
  
  /// Get all domains
  Future<Result<List<String>>> getAllDomains() async {
    AppLogger.info('LocalStorageService: Getting all domains');
    return await getAll<String>(domainsBoxName);
  }

  /// Add a domain
  Future<Result<void>> addDomain(String domain) async {
    AppLogger.info('LocalStorageService: Adding domain: $domain');
    return await put<String>(domainsBoxName, domain.toLowerCase(), domain);
  }

  /// Remove a domain
  Future<Result<void>> removeDomain(String domain) async {
    AppLogger.info('LocalStorageService: Removing domain: $domain');
    return await delete(domainsBoxName, domain.toLowerCase());
  }

  /// Check if domain exists
  Future<Result<bool>> domainExists(String domain) async {
    final result = await get<String>(domainsBoxName, domain.toLowerCase());
    return result.when(
      success: (domainValue) => Result.success(domainValue != null),
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Rename a domain
  Future<Result<void>> renameDomain(String oldDomain, String newDomain) async {
    AppLogger.info('LocalStorageService: Renaming domain from "$oldDomain" to "$newDomain"');
    
    // Remove old domain
    final removeResult = await removeDomain(oldDomain);
    if (removeResult is Error<void>) {
      return removeResult;
    }
    
    // Add new domain
    return await addDomain(newDomain);
  }

  // Status-specific methods
  
  /// Get all statuses
  Future<Result<List<String>>> getAllStatuses() async {
    AppLogger.info('LocalStorageService: Getting all statuses');
    return await getAll<String>(statusesBoxName);
  }

  /// Add a status
  Future<Result<void>> addStatus(String status) async {
    AppLogger.info('LocalStorageService: Adding status: $status');
    return await put<String>(statusesBoxName, status.toLowerCase(), status);
  }

  /// Remove a status
  Future<Result<void>> removeStatus(String status) async {
    AppLogger.info('LocalStorageService: Removing status: $status');
    return await delete(statusesBoxName, status.toLowerCase());
  }

  /// Check if status exists
  Future<Result<bool>> statusExists(String status) async {
    final result = await get<String>(statusesBoxName, status.toLowerCase());
    return result.when(
      success: (statusValue) => Result.success(statusValue != null),
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Rename a status
  Future<Result<void>> renameStatus(String oldStatus, String newStatus) async {
    AppLogger.info('LocalStorageService: Renaming status from "$oldStatus" to "$newStatus"');
    
    // Remove old status
    final removeResult = await removeStatus(oldStatus);
    if (removeResult is Error<void>) {
      return removeResult;
    }
    
    // Add new status
    return await addStatus(newStatus);
  }
} 
