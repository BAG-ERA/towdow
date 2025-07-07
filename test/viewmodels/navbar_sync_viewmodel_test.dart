/// Tests unitaires pour NavbarSyncViewModel
/// Teste la logique métier de gestion de l'état de synchronisation global

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:towdow_app/presentation/viewmodels/navbar_sync_viewmodel.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/services/sync_service.dart';
import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/core/result.dart';

// Generate mocks
@GenerateMocks([AccountRepository, SyncService])
import 'navbar_sync_viewmodel_test.mocks.dart';

void main() {
  group('NavbarSyncViewModel', () {
    late NavbarSyncViewModel viewModel;
    late MockAccountRepository mockAccountRepository;
    late MockSyncService mockSyncService;

    setUp(() {
      mockAccountRepository = MockAccountRepository();
      mockSyncService = MockSyncService();

      // Setup default mock behaviors
      when(() => mockSyncService.statusStream).thenAnswer(
        (_) => Stream.value(SyncStatus.idle),
      );
      when(() => mockSyncService.isBackgroundSyncRunning).thenReturn(false);
      when(() => mockSyncService.isBackgroundSyncing).thenReturn(false);
      when(() => mockSyncService.lastSyncTime).thenReturn(null);
      when(() => mockSyncService.status).thenReturn(SyncStatus.idle);

      viewModel = NavbarSyncViewModel(
        mockAccountRepository,
        mockSyncService,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('initial state should be default', () {
      expect(viewModel.state.isConnected, false);
      expect(viewModel.state.isBackgroundSyncRunning, false);
      expect(viewModel.state.isBackgroundSyncing, false);
      expect(viewModel.state.isFullSyncing, false);
      expect(viewModel.state.syncStatus, SyncStatus.idle);
      expect(viewModel.state.error, null);
      expect(viewModel.state.currentAccount, null);
      expect(viewModel.state.lastSyncTime, null);
      expect(viewModel.state.syncedCalendarsCount, 0);
    });

    group('initialize', () {
      test('should load account successfully', () async {
        // Arrange
        final testAccount = CaldavAccount(
          id: 'test-id',
          providerType: 'test',
          serverUrl: 'https://test.com',
          username: 'test@example.com',
          createdAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
        );

        when(() => mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.success(testAccount));

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.state.account, testAccount);
        expect(viewModel.state.isConnected, true);
      });

      test('should handle no active account', () async {
        // Arrange
        when(() => mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.success(null));

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.state.account, null);
        expect(viewModel.state.isConnected, false);
      });

      test('should handle account loading failure', () async {
        // Arrange
        when(() => mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.failure(
                Failure(exception: Exception('Test error'), message: 'Test error')));

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.state.isConnected, false);
        expect(viewModel.state.error, contains('Account error'));
      });
    });

    group('triggerSync', () {
      test('should trigger sync successfully', () async {
        // Arrange
        when(() => mockSyncService.syncNow())
            .thenAnswer((_) async => Result.success(SyncResult(
              tasksUpdated: 5,
              calendarsUpdated: 2,
              conflicts: [],
            )));

        // Act
        await viewModel.triggerSync();

        // Assert
        verify(() => mockSyncService.syncNow()).called(1);
        expect(viewModel.state.error, null);
      });

      test('should handle sync failure', () async {
        // Arrange
        when(() => mockSyncService.syncNow())
            .thenAnswer((_) async => Result.failure(
                Failure(exception: Exception('Sync error'), message: 'Sync failed')));

        // Act
        await viewModel.triggerSync();

        // Assert
        expect(viewModel.state.error, contains('Sync failed'));
      });
    });

    group('startBackgroundSync', () {
      test('should start background sync successfully', () async {
        // Arrange
        when(() => mockSyncService.initialize())
            .thenAnswer((_) async {});

        // Act
        await viewModel.startBackgroundSync();

        // Assert
        verify(() => mockSyncService.initialize()).called(1);
      });

      test('should handle start failure', () async {
        // Arrange
        when(() => mockSyncService.initialize())
            .thenThrow(Exception('Start error'));

        // Act
        await viewModel.startBackgroundSync();

        // Assert
        expect(viewModel.state.error, contains('Failed to start sync'));
      });
    });

    group('stopBackgroundSync', () {
      test('should stop background sync', () {
        // Arrange
        when(() => mockSyncService.stopPeriodicSync()).thenReturn(null);

        // Act
        viewModel.stopBackgroundSync();

        // Assert
        verify(() => mockSyncService.stopPeriodicSync()).called(1);
      });
    });

    group('refresh', () {
      test('should refresh account and sync status', () async {
        // Arrange
        final testAccount = CaldavAccount(
          id: 'test-id',
          providerType: 'test',
          serverUrl: 'https://test.com',
          username: 'test@example.com',
          createdAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
        );

        when(() => mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.success(testAccount));

        // Act
        await viewModel.refresh();

        // Assert
        expect(viewModel.state.account, testAccount);
        expect(viewModel.state.isConnected, true);
      });
    });

    group('clearError', () {
      test('should clear error state', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(error: 'Test error');

        // Act
        viewModel.clearError();

        // Assert
        expect(viewModel.state.error, null);
      });
    });

    group('state computed properties', () {
      test('isSyncing should return true when background syncing', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(isBackgroundSyncing: true);

        // Act & Assert
        expect(viewModel.state.isSyncing, true);
      });

      test('isSyncing should return true when full syncing', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(isFullSyncing: true);

        // Act & Assert
        expect(viewModel.state.isSyncing, true);
      });

      test('isSyncing should return true when sync status is syncing', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(syncStatus: SyncStatus.syncing);

        // Act & Assert
        expect(viewModel.state.isSyncing, true);
      });

      test('isSyncing should return false when not syncing', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isBackgroundSyncing: false,
          isFullSyncing: false,
          syncStatus: SyncStatus.idle,
        );

        // Act & Assert
        expect(viewModel.state.isSyncing, false);
      });

      test('indicatorStatus should return offline when not connected', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(isConnected: false);

        // Act & Assert
        expect(viewModel.state.indicatorStatus, SyncIndicatorStatus.offline);
      });

      test('indicatorStatus should return error when error exists', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          error: 'Test error',
        );

        // Act & Assert
        expect(viewModel.state.indicatorStatus, SyncIndicatorStatus.error);
      });

      test('indicatorStatus should return syncing when syncing', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          isBackgroundSyncing: true,
        );

        // Act & Assert
        expect(viewModel.state.indicatorStatus, SyncIndicatorStatus.syncing);
      });

      test('indicatorStatus should return idle when connected and not syncing', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          isBackgroundSyncing: false,
          isFullSyncing: false,
          syncStatus: SyncStatus.idle,
          error: null,
        );

        // Act & Assert
        expect(viewModel.state.indicatorStatus, SyncIndicatorStatus.idle);
      });
    });

    group('statusText', () {
      test('should return "Offline" when not connected', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(isConnected: false);

        // Act & Assert
        expect(viewModel.state.statusText, 'Offline');
      });

      test('should return "Sync Error" when error exists', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          error: 'Test error',
        );

        // Act & Assert
        expect(viewModel.state.statusText, 'Sync Error');
      });

      test('should return "Syncing..." when background syncing', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          isBackgroundSyncing: true,
        );

        // Act & Assert
        expect(viewModel.state.statusText, 'Syncing...');
      });

      test('should return "Full Sync..." when full syncing', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          isFullSyncing: true,
        );

        // Act & Assert
        expect(viewModel.state.statusText, 'Full Sync...');
      });

      test('should return "Just synced" when last sync was very recent', () {
        // Arrange
        final recentTime = DateTime.now().subtract(Duration(seconds: 30));
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          lastSyncTime: recentTime,
        );

        // Act & Assert
        expect(viewModel.state.statusText, 'Just synced');
      });

      test('should return time ago when last sync was some time ago', () {
        // Arrange
        final pastTime = DateTime.now().subtract(Duration(minutes: 5));
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          lastSyncTime: pastTime,
        );

        // Act & Assert
        expect(viewModel.state.statusText, '5m ago');
      });

      test('should return "Ready" when no last sync time', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          lastSyncTime: null,
        );

        // Act & Assert
        expect(viewModel.state.statusText, 'Ready');
      });
    });

    group('getters', () {
      test('hasValidAccount should return true when account exists and connected', () {
        // Arrange
        final testAccount = CaldavAccount(
          id: 'test-id',
          providerType: 'test',
          serverUrl: 'https://test.com',
          username: 'test@example.com',
          createdAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
        );

        viewModel.state = viewModel.state.copyWith(
          account: testAccount,
          isConnected: true,
        );

        // Act & Assert
        expect(viewModel.hasValidAccount, true);
      });

      test('hasValidAccount should return false when no account', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          account: null,
          isConnected: true,
        );

        // Act & Assert
        expect(viewModel.hasValidAccount, false);
      });

      test('accountDisplayName should return username when no first/last name', () {
        // Arrange
        final testAccount = CaldavAccount(
          id: 'test-id',
          providerType: 'test',
          serverUrl: 'https://test.com',
          username: 'testuser',
          createdAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
        );

        viewModel.state = viewModel.state.copyWith(account: testAccount);

        // Act & Assert
        expect(viewModel.accountDisplayName, 'testuser');
      });

      test('accountDisplayName should return full name when available', () {
        // Arrange
        final testAccount = CaldavAccount(
          id: 'test-id',
          providerType: 'test',
          serverUrl: 'https://test.com',
          username: 'testuser',
          firstName: 'John',
          lastName: 'Doe',
          createdAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
        );

        viewModel.state = viewModel.state.copyWith(account: testAccount);

        // Act & Assert
        expect(viewModel.accountDisplayName, 'John Doe');
      });

      test('accountDisplayName should return email when no full name', () {
        // Arrange
        final testAccount = CaldavAccount(
          id: 'test-id',
          providerType: 'test',
          serverUrl: 'https://test.com',
          username: 'testuser',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
        );

        viewModel.state = viewModel.state.copyWith(account: testAccount);

        // Act & Assert
        expect(viewModel.accountDisplayName, 'test@example.com');
      });

      test('serverUrl should return empty string when no account', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(account: null);

        // Act & Assert
        expect(viewModel.serverUrl, '');
      });

      test('serverUrl should return account server URL', () {
        // Arrange
        final testAccount = CaldavAccount(
          id: 'test-id',
          providerType: 'test',
          serverUrl: 'https://test.com',
          username: 'testuser',
          createdAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
        );

        viewModel.state = viewModel.state.copyWith(account: testAccount);

        // Act & Assert
        expect(viewModel.serverUrl, 'https://test.com');
      });
    });
  });
} 