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
      when(mockSyncService.statusStream).thenAnswer(
        (_) => Stream.value(SyncStatus.idle),
      );
      when(mockSyncService.isBackgroundSyncRunning).thenReturn(false);
      when(mockSyncService.isBackgroundSyncing).thenReturn(false);
      when(mockSyncService.lastSyncTime).thenReturn(null);
      when(mockSyncService.status).thenReturn(SyncStatus.idle);

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
      expect(viewModel.state.account, null);
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

        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.success(testAccount));

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.state.account, testAccount);
        expect(viewModel.state.isConnected, true);
      });

      test('should handle no active account', () async {
        // Arrange
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.success(null));

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.state.account, null);
        expect(viewModel.state.isConnected, false);
      });

      test('should handle account loading failure', () async {
        // Arrange
        when(mockAccountRepository.getActiveAccount())
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
        when(mockSyncService.syncNow())
            .thenAnswer((_) async => Result.success(SyncResult(
              success: true,
              syncedItems: 5,
              failedItems: 0,
              errors: [],
              syncTime: DateTime.now(),
            )));

        // Act
        await viewModel.triggerSync();

        // Assert
        verify(mockSyncService.syncNow()).called(1);
        expect(viewModel.state.error, null);
      });

      test('should handle sync failure', () async {
        // Arrange
        when(mockSyncService.syncNow())
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
        when(mockSyncService.initialize())
            .thenAnswer((_) async => Result.success(null));

        // Act
        await viewModel.startBackgroundSync();

        // Assert
        verify(mockSyncService.initialize()).called(1);
      });

      test('should handle start failure', () async {
        // Arrange
        when(mockSyncService.initialize())
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
        when(mockSyncService.stopPeriodicSync()).thenReturn(null);

        // Act
        viewModel.stopBackgroundSync();

        // Assert
        verify(mockSyncService.stopPeriodicSync()).called(1);
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

        when(mockAccountRepository.getActiveAccount())
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
    });

    group('indicator status', () {
      test('should return offline when not connected', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(isConnected: false);

        // Act & Assert
        expect(viewModel.state.indicatorStatus, SyncIndicatorStatus.offline);
      });

      test('should return error when error exists', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          error: 'Test error',
        );

        // Act & Assert
        expect(viewModel.state.indicatorStatus, SyncIndicatorStatus.error);
      });

      test('should return syncing when syncing', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          isBackgroundSyncing: true,
        );

        // Act & Assert
        expect(viewModel.state.indicatorStatus, SyncIndicatorStatus.syncing);
      });

      test('should return idle when connected and not syncing', () {
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

    group('status text', () {
      test('should return offline when not connected', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(isConnected: false);

        // Act & Assert
        expect(viewModel.state.statusText, 'Offline');
      });

      test('should return sync error when error exists', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          error: 'Test error',
        );

        // Act & Assert
        expect(viewModel.state.statusText, 'Sync Error');
      });

      test('should return syncing when background syncing', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          isBackgroundSyncing: true,
        );

        // Act & Assert
        expect(viewModel.state.statusText, 'Syncing...');
      });

      test('should return full sync when full syncing', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          isFullSyncing: true,
        );

        // Act & Assert
        expect(viewModel.state.statusText, 'Full Sync...');
      });

      test('should return syncing when sync status is syncing', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          syncStatus: SyncStatus.syncing,
        );

        // Act & Assert
        expect(viewModel.state.statusText, 'Syncing...');
      });

      test('should return just synced when last sync was less than 1 minute ago', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          lastSyncTime: DateTime.now().subtract(const Duration(seconds: 30)),
        );

        // Act & Assert
        expect(viewModel.state.statusText, 'Just synced');
      });

      test('should return minutes ago when last sync was less than 1 hour ago', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          lastSyncTime: DateTime.now().subtract(const Duration(minutes: 30)),
        );

        // Act & Assert
        expect(viewModel.state.statusText, '30m ago');
      });

      test('should return hours ago when last sync was less than 1 day ago', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          lastSyncTime: DateTime.now().subtract(const Duration(hours: 5)),
        );

        // Act & Assert
        expect(viewModel.state.statusText, '5h ago');
      });

      test('should return days ago when last sync was more than 1 day ago', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          lastSyncTime: DateTime.now().subtract(const Duration(days: 3)),
        );

        // Act & Assert
        expect(viewModel.state.statusText, '3d ago');
      });

      test('should return ready when connected and no last sync time', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          isConnected: true,
          lastSyncTime: null,
        );

        // Act & Assert
        expect(viewModel.state.statusText, 'Ready');
      });
    });
  });
} 