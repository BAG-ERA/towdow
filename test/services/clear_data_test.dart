// Test for clearAllData functionality
// Verifies that all storage boxes are properly cleared including offline files and file upload queue

import 'package:flutter_test/flutter_test.dart';
import 'package:towdow_app/data/services/storage/local_storage_service.dart';
import 'package:towdow_app/core/result.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

// Import all the models that need adapters
import 'package:towdow_app/data/models/attendee.dart';
import 'package:towdow_app/data/models/automated_task.dart';
import 'package:towdow_app/data/models/validator.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/data/models/user_preferences.dart';
import 'package:towdow_app/data/models/external_calendar.dart';
import 'package:towdow_app/data/models/external_caldav_account.dart';
import 'package:towdow_app/data/models/calendar_event.dart';
import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/data/models/task.dart';
import 'package:towdow_app/data/models/offline_file.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  final String testPath;
  FakePathProviderPlatform(this.testPath);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return testPath;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Clear All Data Tests', () {
    late LocalStorageService storageService;
    late Directory tempDir;

    setUpAll(() async {
      // Create a temporary directory for testing
      tempDir = await Directory.systemTemp.createTemp('towdow_clear_test_');
      
      // Mock path_provider to return the temp directory
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
      
      // Initialize Hive with the temporary directory
      Hive.init(tempDir.path);
      
      // Register Hive adapters for all models
      Hive.registerAdapter(TaskAdapter());
      Hive.registerAdapter(AutomatedTaskAdapter());
      Hive.registerAdapter(CaldavAccountAdapter());
      Hive.registerAdapter(FormQuestionAdapter());
      Hive.registerAdapter(FormQuestionTypeAdapter());
      Hive.registerAdapter(TaskCalendarAdapter());
      Hive.registerAdapter(AttendeeAdapter());
      Hive.registerAdapter(UserPreferencesAdapter());
      Hive.registerAdapter(ExternalCalendarAdapter());
      Hive.registerAdapter(ExternalCaldavAccountAdapter());
      Hive.registerAdapter(CalendarEventAdapter());
      Hive.registerAdapter(OfflineFileAdapter());
      Hive.registerAdapter(OfflineFileStatusAdapter());
      Hive.registerAdapter(ExternalCalendarAuthTypeAdapter());
    });

    setUp(() async {
      storageService = LocalStorageService();
      await storageService.initialize();
    });

    tearDown(() async {
      await storageService.close();
    });

    tearDownAll(() async {
      // Close all Hive boxes first to release file handles
      await Hive.close();
      
      // Wait a bit for file handles to be fully released
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('clearAllData should clear all storage boxes including offline files and file upload queue', () async {
      // Add some test data to all boxes
      final now = DateTime.now();
      final testAccount = CaldavAccount(
        id: 'test-account',
        providerType: 'test',
        serverUrl: 'https://test.com',
        username: 'testuser',
        createdAt: now,
        lastSyncAt: now,
        isActive: true,
      );

      final testTask = Task(
        uid: 'test-task',
        summary: 'Test Task',
        description: 'Test Description',
        status: 'NEEDS-ACTION',
        lastModified: now,
        created: now,
        dtstamp: now,
        projectPath: 'test-project',
      );

      final testOfflineFile = OfflineFile(
        id: 'test-file',
        taskUid: 'test-task',
        aesKey: 'test-aes-key-12345678901234567890123456789012',
        fileName: 'test.txt',
        localPath: '/test/path',
        fileSize: 1024,
        contentType: 'text/plain',
        createdAt: now,
        status: OfflineFileStatus.local,
        validatorId: 'test-validator',
      );

      // Add data to various boxes
      await storageService.put(LocalStorageService.accountsBoxName, testAccount.id, testAccount);
      await storageService.put(LocalStorageService.tasksBoxName, testTask.uid, testTask);
      await storageService.put(LocalStorageService.offlineFilesBoxName, testOfflineFile.id, testOfflineFile);
      await storageService.put(LocalStorageService.fileUploadQueueBoxName, 'test-queue-item', {'test': 'data'});

      // Verify data was added
      final accountsResult = await storageService.getAll<CaldavAccount>(LocalStorageService.accountsBoxName);
      final tasksResult = await storageService.getAll<Task>(LocalStorageService.tasksBoxName);
      final offlineFilesResult = await storageService.getAll<OfflineFile>(LocalStorageService.offlineFilesBoxName);
      final uploadQueueResult = await storageService.getAll(LocalStorageService.fileUploadQueueBoxName);

      expect(accountsResult.when(success: (accounts) => accounts.length, failure: (_) => 0), 1);
      expect(tasksResult.when(success: (tasks) => tasks.length, failure: (_) => 0), 1);
      expect(offlineFilesResult.when(success: (files) => files.length, failure: (_) => 0), 1);
      expect(uploadQueueResult.when(success: (items) => items.length, failure: (_) => 0), 1);

      // Clear all data
      final clearResult = await storageService.clearAllData();
      expect(clearResult.when(success: (_) => true, failure: (_) => false), true);

      // Verify all boxes are empty
      final accountsAfterClear = await storageService.getAll<CaldavAccount>(LocalStorageService.accountsBoxName);
      final tasksAfterClear = await storageService.getAll<Task>(LocalStorageService.tasksBoxName);
      final offlineFilesAfterClear = await storageService.getAll<OfflineFile>(LocalStorageService.offlineFilesBoxName);
      final uploadQueueAfterClear = await storageService.getAll(LocalStorageService.fileUploadQueueBoxName);

      expect(accountsAfterClear.when(success: (accounts) => accounts.length, failure: (_) => 0), 0);
      expect(tasksAfterClear.when(success: (tasks) => tasks.length, failure: (_) => 0), 0);
      expect(offlineFilesAfterClear.when(success: (files) => files.length, failure: (_) => 0), 0);
      expect(uploadQueueAfterClear.when(success: (items) => items.length, failure: (_) => 0), 0);
    });

    test('clearAllData should clear external calendar boxes', () async {
      // Add test data to external calendar boxes
      final now = DateTime.now();
      final testExternalAccount = ExternalCaldavAccount(
        id: 'test-external-account',
        displayName: 'Test External User',
        serverUrl: 'https://external.com',
        username: 'externaluser',
        createdAt: now,
        isActive: true,
      );

      final testExternalCalendar = ExternalCalendar(
        accountId: 'test-external-account',
        path: '/test/external',
        displayName: 'Test External Calendar',
        uid: 'test-external-calendar',
        created: now,
        lastModified: now,
        isEnabled: true,
      );

      await storageService.put(LocalStorageService.externalAccountsBoxName, testExternalAccount.id, testExternalAccount);
      await storageService.put(LocalStorageService.externalCalendarsBoxName, testExternalCalendar.path, testExternalCalendar);

      // Verify data was added
      final externalAccountsResult = await storageService.getAll<ExternalCaldavAccount>(LocalStorageService.externalAccountsBoxName);
      final externalCalendarsResult = await storageService.getAll<ExternalCalendar>(LocalStorageService.externalCalendarsBoxName);

      expect(externalAccountsResult.when(success: (accounts) => accounts.length, failure: (_) => 0), 1);
      expect(externalCalendarsResult.when(success: (calendars) => calendars.length, failure: (_) => 0), 1);

      // Clear all data
      final clearResult = await storageService.clearAllData();
      expect(clearResult.when(success: (_) => true, failure: (_) => false), true);

      // Verify external calendar boxes are empty
      final externalAccountsAfterClear = await storageService.getAll<ExternalCaldavAccount>(LocalStorageService.externalAccountsBoxName);
      final externalCalendarsAfterClear = await storageService.getAll<ExternalCalendar>(LocalStorageService.externalCalendarsBoxName);

      expect(externalAccountsAfterClear.when(success: (accounts) => accounts.length, failure: (_) => 0), 0);
      expect(externalCalendarsAfterClear.when(success: (calendars) => calendars.length, failure: (_) => 0), 0);
    });
  });
} 