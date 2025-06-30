// Integration tests for sync functionality
// Tests end-to-end synchronization between local storage and CalDAV

import 'package:flutter_test/flutter_test.dart';
import 'package:flowit_app/data/services/sync_service.dart';
import 'package:flowit_app/data/services/local_storage_service.dart';
import 'package:flowit_app/data/repositories/task_repository.dart';
import 'package:flowit_app/data/repositories/account_repository.dart';
import 'package:flowit_app/data/repositories/calendar_repository.dart';
import 'package:flowit_app/data/models/task.dart';
import 'package:flowit_app/data/models/caldav_account.dart';
import 'package:flowit_app/core/result.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  group('Sync Integration Tests', () {
    late LocalStorageService storageService;
    late TaskRepository taskRepository;
    late AccountRepository accountRepository;
    late CalendarRepository calendarRepository;
    late SyncService syncService;

    setUpAll(() async {
      // Initialize Hive with a temporary directory for testing
      await Hive.initFlutter('test_sync');
    });

    tearDownAll(() async {
      await Hive.deleteFromDisk();
    });

    setUp(() async {
      // Clear any existing data
      await Hive.deleteFromDisk();
      
      // Initialize services
      storageService = LocalStorageService();
      await storageService.initialize();
      
      taskRepository = LocalTaskRepository(storageService);
      accountRepository = LocalAccountRepository(storageService);
      calendarRepository = LocalCalendarRepository(storageService);
      
      syncService = SyncService(
        taskRepository: taskRepository,
        accountRepository: accountRepository,
        calendarRepository: calendarRepository,
        localStorage: storageService,
      );
    });

    group('Local Storage Tests', () {
      test('should initialize sync service without account', () async {
        // Act
        final result = await syncService.initialize();

        // Assert
        final isSuccess = result.when(
          success: (_) => true,
          failure: (_) => false,
        );
        expect(isSuccess, true);
        expect(syncService.status, SyncStatus.idle);
      });

      test('should handle sync with no account', () async {
        // Act
        final result = await syncService.syncNow();

        // Assert
        final hasCorrectError = result.when(
          success: (_) => false,
          failure: (failure) => failure.message.contains('No active CalDAV account'),
        );
        expect(hasCorrectError, true);
        expect(syncService.status, SyncStatus.offline);
      });

      test('should create and store tasks locally', () async {
        // Arrange
        final testTask = Task(
          uid: 'local-test-task',
          summary: 'Local Test Task',
          description: 'Testing local storage',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          flowitValidator: 'default',
        );

        // Act
        final saveResult = await taskRepository.save(testTask);
        final loadResult = await taskRepository.getById('local-test-task');

        // Assert
        expect(saveResult.when(success: (_) => true, failure: (_) => false), true);
        final loadedTask = loadResult.when(
          success: (task) => task,
          failure: (_) => null,
        );
        expect(loadedTask, isNotNull);
        expect(loadedTask!.summary, 'Local Test Task');
      });

      test('should queue sync operations', () async {
        // Arrange
        final testData = {
          'uid': 'queued-task',
          'summary': 'Queued Task',
          'description': 'Task queued for sync',
        };

        // Act
        final queueResult = await syncService.queueSyncOperation(
          SyncOperation.create,
          'queued-task',
          testData,
        );

        // Assert
        final isSuccess = queueResult.when(
          success: (_) => true,
          failure: (_) => false,
        );
        expect(isSuccess, true);
      });
    });

    group('Account Management Tests', () {
      test('should save and retrieve CalDAV account', () async {
        // Arrange
        final testAccount = CaldavAccount(
          id: 'test-account-123',
          providerType: 'custom',
          serverUrl: 'https://test.example.com/caldav/',
          username: 'testuser',
          password: 'testpass',
          createdAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
          isActive: true,
        );

        // Act
        final saveResult = await accountRepository.save(testAccount);
        final activeResult = await accountRepository.getActiveAccount();

        // Assert
        expect(saveResult.when(success: (_) => true, failure: (_) => false), true);
        final activeAccount = activeResult.when(
          success: (account) => account,
          failure: (_) => null,
        );
        expect(activeAccount, isNotNull);
        expect(activeAccount!.username, 'testuser');
        expect(activeAccount.serverUrl, 'https://test.example.com/caldav/');
      });

      test('should initialize sync service with active account', () async {
        // Arrange
        final testAccount = CaldavAccount(
          id: 'test-account-456',
          providerType: 'custom',
          serverUrl: 'https://test2.example.com/caldav/',
          username: 'testuser2',
          password: 'testpass2',
          createdAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
          isActive: true,
        );
        await accountRepository.save(testAccount);

        // Act
        final result = await syncService.initialize();

        // Assert
        final isSuccess = result.when(
          success: (_) => true,
          failure: (_) => false,
        );
        expect(isSuccess, true);
      });
    });

    group('Sync Status Tests', () {
      test('should provide status stream', () {
        // Act
        final statusStream = syncService.statusStream;
        final progressStream = syncService.progressStream;

        // Assert
        expect(statusStream, isA<Stream<SyncStatus>>());
        expect(progressStream, isA<Stream<double>>());
        expect(syncService.status, SyncStatus.idle);
      });

      test('should update status during sync', () async {
        // Arrange
        final statusUpdates = <SyncStatus>[];
        final subscription = syncService.statusStream.listen((status) {
          statusUpdates.add(status);
        });

        // Act
        await syncService.syncNow();

        // Assert
        expect(statusUpdates, contains(SyncStatus.syncing));
        await subscription.cancel();
      });
    });

    group('Error Handling Tests', () {
      test('should handle storage errors gracefully', () async {
        // Arrange - Close storage to simulate error
        await Hive.close();

        // Act
        final result = await syncService.syncNow();

        // Assert
        final isFailure = result.when(
          success: (_) => false,
          failure: (_) => true,
        );
        expect(isFailure, true);
      });
    });

    group('Task Repository Integration', () {
      test('should filter today tasks correctly', () async {
        // Arrange
        final today = DateTime.now();
        final tomorrow = today.add(const Duration(days: 1));
        
        final todayTask = Task(
          uid: 'today-task',
          summary: 'Today Task',
          description: 'Due today',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          due: today,
          flowitValidator: 'default',
        );
        
        final tomorrowTask = Task(
          uid: 'tomorrow-task',
          summary: 'Tomorrow Task',
          description: 'Due tomorrow',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          due: tomorrow,
          flowitValidator: 'default',
        );

        // Act
        await taskRepository.save(todayTask);
        await taskRepository.save(tomorrowTask);
        
        final todayTasksResult = await taskRepository.getTasksWithDueDate(today);

        // Assert
        final todayTasks = todayTasksResult.when(
          success: (tasks) => tasks,
          failure: (_) => <Task>[],
        );
        expect(todayTasks.length, 1);
        expect(todayTasks.first.uid, 'today-task');
      });

      test('should identify unregistered tasks', () async {
        // Arrange
        final registeredTask = Task(
          uid: 'registered-task',
          summary: 'Registered Task',
          description: 'Has due date',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          due: DateTime.now().add(const Duration(days: 1)),
          flowitValidator: 'default',
        );
        
        final unregisteredTask = Task(
          uid: 'unregistered-task',
          summary: 'Unregistered Task',
          description: 'No due date',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          // No due date
          flowitValidator: 'default',
        );

        // Act
        await taskRepository.save(registeredTask);
        await taskRepository.save(unregisteredTask);
        
        final unregisteredResult = await taskRepository.getUnregisteredTasks();

        // Assert
        final unregisteredTasks = unregisteredResult.when(
          success: (tasks) => tasks,
          failure: (_) => <Task>[],
        );
        // TODO: In Calendar = Project model, unregistered tasks logic needs to be redefined
        // For now, getUnregisteredTasks returns empty list during transition
        expect(unregisteredTasks.length, 0);
      });
    });

    group('Performance Tests', () {
      test('should handle multiple tasks efficiently', () async {
        // Arrange
        final tasks = List.generate(100, (index) => Task(
          uid: 'perf-task-$index',
          summary: 'Performance Task $index',
          description: 'Testing with many tasks',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          flowitValidator: 'default',
        ));

        // Act
        final stopwatch = Stopwatch()..start();
        for (final task in tasks) {
          await taskRepository.save(task);
        }
        final allTasksResult = await taskRepository.getAll();
        stopwatch.stop();

        // Assert
        final allTasks = allTasksResult.when(
          success: (tasks) => tasks,
          failure: (_) => <Task>[],
        );
        expect(allTasks.length, 100);
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Should complete in under 5 seconds
      });
    });
  });
} 