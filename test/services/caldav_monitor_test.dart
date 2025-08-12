// Unit tests for CalDAVMonitor
// Tests the change monitoring functionality and dynamic interval adjustment

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:towdow_app/core/result.dart';
import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/repositories/category_repository.dart';
import 'package:towdow_app/data/repositories/user_repository.dart';
import 'package:towdow_app/data/repositories/external_account_repository.dart';
import 'package:towdow_app/data/repositories/external_calendar_repository.dart';
import 'package:towdow_app/data/services/sync/sync_orchestrator_service.dart';
import 'package:towdow_app/data/services/sync/sync_service.dart';
import 'package:towdow_app/data/services/sync/connection_monitor_service.dart';
import 'package:towdow_app/data/services/user/user_sync_service.dart';
import 'package:towdow_app/data/services/user/user_preferences_queue_service.dart';
import 'package:towdow_app/data/services/webdav_client.dart';

import 'caldav_monitor_test.mocks.dart';

@GenerateMocks([
  AccountRepository,
  CalendarRepository,
  CategoryRepository,
  UserRepository,
  ExternalAccountRepository,
  ExternalCalendarRepository,
  ConnectionMonitorService,
  SyncService,
  UserSyncService,
  UserPreferencesQueueService,
  WebDAVClient,
])
void main() {
  group('CalDAVMonitor', () {
    late CalDAVMonitor monitor;
    late MockAccountRepository mockAccountRepository;
    late MockCalendarRepository mockCalendarRepository;
    late MockCategoryRepository mockCategoryRepository;
    late MockUserRepository mockUserRepository;
    late MockExternalAccountRepository mockExternalAccountRepository;
    // Intentionally omitted: MockExternalCalendarRepository isn't required by CalDAVMonitor constructor
    late MockConnectionMonitorService mockConnectionMonitorService;
    late MockSyncService mockSyncService;
    late MockUserSyncService mockUserSyncService;
    late MockUserPreferencesQueueService mockUserPreferencesQueueService;

    setUp(() {
      mockAccountRepository = MockAccountRepository();
      mockCalendarRepository = MockCalendarRepository();
      mockCategoryRepository = MockCategoryRepository();
      mockUserRepository = MockUserRepository();
      mockExternalAccountRepository = MockExternalAccountRepository();
      // No need to initialize MockExternalCalendarRepository for these tests
      mockConnectionMonitorService = MockConnectionMonitorService();
      mockSyncService = MockSyncService();
      mockUserSyncService = MockUserSyncService();
      mockUserPreferencesQueueService = MockUserPreferencesQueueService();

      monitor = CalDAVMonitor(
        accountRepository: mockAccountRepository,
        calendarRepository: mockCalendarRepository,
        categoryRepository: mockCategoryRepository,
        userRepository: mockUserRepository,
        externalAccountRepository: mockExternalAccountRepository,
        connectionMonitorService: mockConnectionMonitorService,
        syncService: mockSyncService,
        userSyncService: mockUserSyncService,
        userPreferencesQueueService: mockUserPreferencesQueueService,
      );

      // Default stubs to avoid hitting real services during monitor loops
      when(mockUserPreferencesQueueService.processQueue())
          .thenAnswer((_) async => const Result.success(null));
      when(mockUserRepository.getEtag())
          .thenAnswer((_) async => const Result.success(null));
      when(mockExternalAccountRepository.getCredentialsFileEtag())
          .thenAnswer((_) async => const Result.success(null));
      when(mockUserSyncService.downloadUserData())
          .thenAnswer((_) async => const Result.success(false));
      when(mockUserSyncService.uploadUserData())
          .thenAnswer((_) async => const Result.success(null));
    });

    tearDown(() {
      monitor.dispose();
    });

    group('Initialization', () {
      test('should initialize with correct default interval', () {
        expect(monitor.currentInterval, const Duration(seconds: 10));
        expect(monitor.isMonitoring, false);
      });

      test('should start monitoring successfully', () async {
        // Arrange
        when(mockConnectionMonitorService.currentStatus).thenReturn(ConnectionStatus.connected);
        when(mockAccountRepository.getActiveAccount()).thenAnswer(
          (_) async => Result.success(null),
        );

        // Act
        final result = await monitor.start();

        // Assert
        result.when(
          success: (_) => expect(monitor.isMonitoring, true),
          failure: (failure) => fail('Should not fail: ${failure.message}'),
        );
      });

      test('should not start if already monitoring', () async {
        // Arrange
        when(mockConnectionMonitorService.currentStatus).thenReturn(ConnectionStatus.connected);
        when(mockAccountRepository.getActiveAccount()).thenAnswer(
          (_) async => Result.success(null),
        );

        // Act
        await monitor.start();
        final result = await monitor.start();

        // Assert
        result.when(
          success: (_) => expect(monitor.isMonitoring, true),
          failure: (failure) => fail('Should not fail: ${failure.message}'),
        );
      });

      test('should stop monitoring', () {
        // Act
        monitor.stop();

        // Assert
        expect(monitor.isMonitoring, false);
      });
    });

    group('Connection Monitoring', () {
      test('should skip monitoring when no internet connection', () async {
        // Arrange
        when(mockConnectionMonitorService.currentStatus).thenReturn(ConnectionStatus.disconnected);

        // Act
        await monitor.start();

        // Assert
        verifyNever(mockAccountRepository.getActiveAccount());
      });

      test('should skip monitoring when no active account', () async {
        // Arrange
        when(mockConnectionMonitorService.currentStatus).thenReturn(ConnectionStatus.connected);
        when(mockAccountRepository.getActiveAccount()).thenAnswer(
          (_) async => Result.success(null),
        );

        // Act
        await monitor.start();

        // Assert
        verifyNever(mockCalendarRepository.getProjectCalendars());
      });
    });

    group('Queue Processing', () {
      test('should process queued operations when connected', () async {
        // Arrange
        when(mockConnectionMonitorService.currentStatus).thenReturn(ConnectionStatus.connected);
        when(mockAccountRepository.getActiveAccount()).thenAnswer(
          (_) async => Result.success(CaldavAccount(
            id: 'test-account',
            providerType: 'test',
            serverUrl: 'https://test.com',
            username: 'test',
            createdAt: DateTime(2024, 1, 1),
            lastSyncAt: DateTime(2024, 1, 1),
          )),
        );
        when(mockCalendarRepository.getProjectCalendars()).thenAnswer(
          (_) async => Result.success([]),
        );
        when(mockSyncService.processQueueOnly()).thenAnswer(
          (_) async => Result.success(SyncResult(
            success: true,
            syncedItems: 2,
            failedItems: 0,
            errors: [],
            syncTime: DateTime(2024, 1, 1),
          )),
        );

        // Act
        await monitor.start();

        // Assert
        verify(mockSyncService.processQueueOnly()).called(1);
      });

      test('should handle queue processing failure gracefully', () async {
        // Arrange
        when(mockConnectionMonitorService.currentStatus).thenReturn(ConnectionStatus.connected);
        when(mockAccountRepository.getActiveAccount()).thenAnswer(
          (_) async => Result.success(CaldavAccount(
            id: 'test-account',
            providerType: 'test',
            serverUrl: 'https://test.com',
            username: 'test',
            createdAt: DateTime(2024, 1, 1),
            lastSyncAt: DateTime(2024, 1, 1),
          )),
        );
        when(mockCalendarRepository.getProjectCalendars()).thenAnswer(
          (_) async => Result.success([]),
        );
        when(mockSyncService.processQueueOnly()).thenAnswer(
          (_) async => Result.failure(Failure(
            message: 'Queue processing failed',
            exception: Exception('Test error'),
          )),
        );

        // Act
        await monitor.start();

        // Assert
        verify(mockSyncService.processQueueOnly()).called(1);
      });
    });

    group('Dynamic Interval Adjustment', () {
      test('should decrease interval when changes are detected', () async {
        // Arrange
        when(mockConnectionMonitorService.currentStatus).thenReturn(ConnectionStatus.connected);
        when(mockAccountRepository.getActiveAccount()).thenAnswer(
          (_) async => Result.success(CaldavAccount(
            id: 'test-account',
            providerType: 'test',
            serverUrl: 'https://test.com',
            username: 'test',
            createdAt: DateTime(2024, 1, 1),
            lastSyncAt: DateTime(2024, 1, 1),
          )),
        );
        when(mockCalendarRepository.getProjectCalendars()).thenAnswer(
          (_) async => Result.success([]),
        );
        when(mockSyncService.processQueueOnly()).thenAnswer(
          (_) async => Result.success(SyncResult(
            success: true,
            syncedItems: 1, // Changes detected
            failedItems: 0,
            errors: [],
            syncTime: DateTime(2024, 1, 1),
          )),
        );

        // Act
        await monitor.start();
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(monitor.currentInterval.inSeconds, 5); // Should be decreased from 10 to 5
      });

      test('should increase interval when no changes are detected', () async {
        // Arrange
        when(mockConnectionMonitorService.currentStatus).thenReturn(ConnectionStatus.connected);
        when(mockAccountRepository.getActiveAccount()).thenAnswer(
          (_) async => Result.success(CaldavAccount(
            id: 'test-account',
            providerType: 'test',
            serverUrl: 'https://test.com',
            username: 'test',
            createdAt: DateTime(2024, 1, 1),
            lastSyncAt: DateTime(2024, 1, 1),
          )),
        );
        when(mockCalendarRepository.getProjectCalendars()).thenAnswer(
          (_) async => Result.success([]),
        );
        when(mockSyncService.processQueueOnly()).thenAnswer(
          (_) async => Result.success(SyncResult(
            success: true,
            syncedItems: 0, // No changes detected
            failedItems: 0,
            errors: [],
            syncTime: DateTime(2024, 1, 1),
          )),
        );

        // Act
        await monitor.start();
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(monitor.currentInterval.inSeconds, 15); // Should be increased from 10 to 15
      });

      test('should respect minimum interval limit', () async {
        // Arrange - start with 4 seconds
        monitor = CalDAVMonitor(
          accountRepository: mockAccountRepository,
          calendarRepository: mockCalendarRepository,
          categoryRepository: mockCategoryRepository,
          userRepository: mockUserRepository,
          externalAccountRepository: mockExternalAccountRepository,
          connectionMonitorService: mockConnectionMonitorService,
          syncService: mockSyncService,
          userSyncService: mockUserSyncService,
          userPreferencesQueueService: mockUserPreferencesQueueService,
        );

        when(mockConnectionMonitorService.currentStatus).thenReturn(ConnectionStatus.connected);
        when(mockAccountRepository.getActiveAccount()).thenAnswer(
          (_) async => Result.success(CaldavAccount(
            id: 'test-account',
            providerType: 'test',
            serverUrl: 'https://test.com',
            username: 'test',
            createdAt: DateTime(2024, 1, 1),
            lastSyncAt: DateTime(2024, 1, 1),
          )),
        );
        when(mockCalendarRepository.getProjectCalendars()).thenAnswer(
          (_) async => Result.success([]),
        );
        when(mockSyncService.processQueueOnly()).thenAnswer(
          (_) async => Result.success(SyncResult(
            success: true,
            syncedItems: 1, // Changes detected
            failedItems: 0,
            errors: [],
            syncTime: DateTime(2024, 1, 1),
          )),
        );

        // Act - trigger multiple decreases
        await monitor.start();
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - should not go below 2 seconds
        expect(monitor.currentInterval.inSeconds, greaterThanOrEqualTo(2));
      });

      test('should respect maximum interval limit', () async {
        // Arrange
        when(mockConnectionMonitorService.currentStatus).thenReturn(ConnectionStatus.connected);
        when(mockAccountRepository.getActiveAccount()).thenAnswer(
          (_) async => Result.success(CaldavAccount(
            id: 'test-account',
            providerType: 'test',
            serverUrl: 'https://test.com',
            username: 'test',
            createdAt: DateTime(2024, 1, 1),
            lastSyncAt: DateTime(2024, 1, 1),
          )),
        );
        when(mockCalendarRepository.getProjectCalendars()).thenAnswer(
          (_) async => Result.success([]),
        );
        when(mockSyncService.processQueueOnly()).thenAnswer(
          (_) async => Result.success(SyncResult(
            success: true,
            syncedItems: 0, // No changes detected
            failedItems: 0,
            errors: [],
            syncTime: DateTime(2024, 1, 1),
          )),
        );

        // Act - trigger multiple increases
        await monitor.start();
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - should not go above 40 seconds
        expect(monitor.currentInterval.inSeconds, lessThanOrEqualTo(40));
      });
    });

    group('Error Handling', () {
      test('should handle account repository failure gracefully', () async {
        // Arrange
        when(mockConnectionMonitorService.currentStatus).thenReturn(ConnectionStatus.connected);
        when(mockAccountRepository.getActiveAccount()).thenAnswer(
          (_) async => Result.failure(Failure(
            message: 'Account repository error',
            exception: Exception('Test error'),
          )),
        );

        // Act
        await monitor.start();

        // Assert
        expect(monitor.isMonitoring, true); // Should continue monitoring
      });

      test('should handle calendar repository failure gracefully', () async {
        // Arrange
        when(mockConnectionMonitorService.currentStatus).thenReturn(ConnectionStatus.connected);
        when(mockAccountRepository.getActiveAccount()).thenAnswer(
          (_) async => Result.success(CaldavAccount(
            id: 'test-account',
            providerType: 'test',
            serverUrl: 'https://test.com',
            username: 'test',
            createdAt: DateTime(2024, 1, 1),
            lastSyncAt: DateTime(2024, 1, 1),
          )),
        );
        when(mockCalendarRepository.getProjectCalendars()).thenAnswer(
          (_) async => Result.failure(Failure(
            message: 'Calendar repository error',
            exception: Exception('Test error'),
          )),
        );

        // Act
        await monitor.start();

        // Assert
        expect(monitor.isMonitoring, true); // Should continue monitoring
      });

      test('should handle sync service failure gracefully', () async {
        // Arrange
        when(mockConnectionMonitorService.currentStatus).thenReturn(ConnectionStatus.connected);
        when(mockAccountRepository.getActiveAccount()).thenAnswer(
          (_) async => Result.success(CaldavAccount(
            id: 'test-account',
            providerType: 'test',
            serverUrl: 'https://test.com',
            username: 'test',
            createdAt: DateTime(2024, 1, 1),
            lastSyncAt: DateTime(2024, 1, 1),
          )),
        );
        when(mockCalendarRepository.getProjectCalendars()).thenAnswer(
          (_) async => Result.success([]),
        );
        when(mockSyncService.processQueueOnly()).thenAnswer(
          (_) async => Result.failure(Failure(
            message: 'Sync service error',
            exception: Exception('Test error'),
          )),
        );

        // Act
        await monitor.start();

        // Assert
        expect(monitor.isMonitoring, true); // Should continue monitoring
      });
    });

    group('Resource Management', () {
      test('should dispose resources correctly', () {
        // Act
        monitor.dispose();

        // Assert
        expect(monitor.isMonitoring, false);
      });

      test('should stop monitoring when disposed', () {
        // Arrange
        monitor.start();

        // Act
        monitor.dispose();

        // Assert
        expect(monitor.isMonitoring, false);
      });
    });
  });
} 