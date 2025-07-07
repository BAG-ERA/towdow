/// Tests basiques pour les ViewModels
/// Vérifie que tous les ViewModels se compilent et fonctionnent correctement

import 'package:flutter_test/flutter_test.dart';
import 'package:towdow_app/presentation/viewmodels/caldav_settings_viewmodel.dart';
import 'package:towdow_app/presentation/viewmodels/navbar_sync_viewmodel.dart';
import 'package:towdow_app/presentation/viewmodels/project_list_viewmodel.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/repositories/task_repository.dart';
import 'package:towdow_app/data/services/sync_service.dart';
import 'package:towdow_app/data/services/local_storage_service.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/core/result.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([
  MockSpec<LocalStorageService>(),
  MockSpec<AccountRepository>(),
  MockSpec<CalendarRepository>(),
  MockSpec<TaskRepository>(),
  MockSpec<SyncService>(),
])
import 'viewmodel_basic_test.mocks.dart';

void main() {
  group('ViewModel Basic Tests', () {
    late MockAccountRepository mockAccountRepository;
    late MockCalendarRepository mockCalendarRepository;
    late MockTaskRepository mockTaskRepository;
    late MockSyncService mockSyncService;

    setUp(() {
      mockAccountRepository = MockAccountRepository();
      mockCalendarRepository = MockCalendarRepository();
      mockTaskRepository = MockTaskRepository();
      mockSyncService = MockSyncService();
    });

    group('CaldavSettingsViewModel', () {
      test('should create and initialize correctly', () {
        final viewModel = CaldavSettingsViewModel(
          mockAccountRepository,
          mockCalendarRepository,
        );

        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.isDiscovering, false);
        expect(viewModel.state.error, null);
        expect(viewModel.state.currentAccount, null);
        expect(viewModel.state.availableCalendars, isEmpty);
        expect(viewModel.state.selectedCalendars, isEmpty);

        viewModel.dispose();
      });

      test('should clear error state', () {
        final viewModel = CaldavSettingsViewModel(
          mockAccountRepository,
          mockCalendarRepository,
        );

        // Set error state
        viewModel.state = viewModel.state.copyWith(error: 'Test error');
        expect(viewModel.state.error, 'Test error');

        // Clear error
        viewModel.clearError();
        expect(viewModel.state.error, null);

        viewModel.dispose();
      });

      test('should check if calendar is selected', () {
        final viewModel = CaldavSettingsViewModel(
          mockAccountRepository,
          mockCalendarRepository,
        );

        final testCalendar = TaskCalendarFactory.createNew(
          path: '/test/calendar1',
          displayName: 'Test Calendar',
        ).copyWith(uid: 'cal1');

        // Initially not selected
        expect(viewModel.isCalendarSelected(testCalendar), false);

        // Add to selected calendars
        viewModel.state = viewModel.state.copyWith(
          selectedCalendars: [testCalendar],
        );

        // Now selected
        expect(viewModel.isCalendarSelected(testCalendar), true);

        viewModel.dispose();
      });

      test('should count selected calendars correctly', () {
        final viewModel = CaldavSettingsViewModel(
          mockAccountRepository,
          mockCalendarRepository,
        );

        expect(viewModel.selectedCalendarCount, 0);

        final calendars = List.generate(3, (index) => 
          TaskCalendarFactory.createNew(
            path: '/test/calendar$index',
            displayName: 'Test Calendar $index',
          ).copyWith(uid: 'cal$index')
        );

        viewModel.state = viewModel.state.copyWith(selectedCalendars: calendars);
        expect(viewModel.selectedCalendarCount, 3);

        viewModel.dispose();
      });
    });

    group('NavbarSyncViewModel', () {
      test('should create and initialize correctly', () {
        // Setup sync service mock
        when(mockSyncService.statusStream).thenAnswer(
          (_) => Stream.value(SyncStatus.idle),
        );
        when(mockSyncService.isBackgroundSyncRunning).thenReturn(false);
        when(mockSyncService.isBackgroundSyncing).thenReturn(false);
        when(mockSyncService.lastSyncTime).thenReturn(null);
        when(mockSyncService.status).thenReturn(SyncStatus.idle);

        final viewModel = NavbarSyncViewModel(
          mockAccountRepository,
          mockSyncService,
        );

        expect(viewModel.state.isConnected, false);
        expect(viewModel.state.isBackgroundSyncRunning, false);
        expect(viewModel.state.isBackgroundSyncing, false);
        expect(viewModel.state.isFullSyncing, false);
        expect(viewModel.state.syncStatus, SyncStatus.idle);
        expect(viewModel.state.error, null);

        viewModel.dispose();
      });

      test('should clear error state', () {
        when(mockSyncService.statusStream).thenAnswer(
          (_) => Stream.value(SyncStatus.idle),
        );
        when(mockSyncService.isBackgroundSyncRunning).thenReturn(false);
        when(mockSyncService.isBackgroundSyncing).thenReturn(false);
        when(mockSyncService.lastSyncTime).thenReturn(null);
        when(mockSyncService.status).thenReturn(SyncStatus.idle);

        final viewModel = NavbarSyncViewModel(
          mockAccountRepository,
          mockSyncService,
        );

        // Set error state
        viewModel.state = viewModel.state.copyWith(error: 'Test error');
        expect(viewModel.state.error, 'Test error');

        // Clear error
        viewModel.clearError();
        expect(viewModel.state.error, null);

        viewModel.dispose();
      });

      test('should detect syncing state correctly', () {
        when(mockSyncService.statusStream).thenAnswer(
          (_) => Stream.value(SyncStatus.idle),
        );
        when(mockSyncService.isBackgroundSyncRunning).thenReturn(false);
        when(mockSyncService.isBackgroundSyncing).thenReturn(false);
        when(mockSyncService.lastSyncTime).thenReturn(null);
        when(mockSyncService.status).thenReturn(SyncStatus.idle);

        final viewModel = NavbarSyncViewModel(
          mockAccountRepository,
          mockSyncService,
        );

        // Not syncing initially
        expect(viewModel.state.isSyncing, false);

        // Background syncing
        viewModel.state = viewModel.state.copyWith(isBackgroundSyncing: true);
        expect(viewModel.state.isSyncing, true);

        // Full syncing
        viewModel.state = viewModel.state.copyWith(
          isBackgroundSyncing: false,
          isFullSyncing: true,
        );
        expect(viewModel.state.isSyncing, true);

        // Sync status syncing
        viewModel.state = viewModel.state.copyWith(
          isFullSyncing: false,
          syncStatus: SyncStatus.syncing,
        );
        expect(viewModel.state.isSyncing, true);

        viewModel.dispose();
      });

      test('should return correct account display name', () {
        when(mockSyncService.statusStream).thenAnswer(
          (_) => Stream.value(SyncStatus.idle),
        );
        when(mockSyncService.isBackgroundSyncRunning).thenReturn(false);
        when(mockSyncService.isBackgroundSyncing).thenReturn(false);
        when(mockSyncService.lastSyncTime).thenReturn(null);
        when(mockSyncService.status).thenReturn(SyncStatus.idle);

        final viewModel = NavbarSyncViewModel(
          mockAccountRepository,
          mockSyncService,
        );

        // No account
        expect(viewModel.accountDisplayName, 'No Account');

        // With full name
        final accountWithFullName = CaldavAccount(
          id: 'test-id',
          providerType: 'test',
          serverUrl: 'https://test.com',
          username: 'testuser',
          firstName: 'John',
          lastName: 'Doe',
          createdAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
        );

        viewModel.state = viewModel.state.copyWith(account: accountWithFullName);
        expect(viewModel.accountDisplayName, 'John Doe');

        // With email only
        final accountWithEmail = CaldavAccount(
          id: 'test-id',
          providerType: 'test',
          serverUrl: 'https://test.com',
          username: 'testuser',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
        );

        viewModel.state = viewModel.state.copyWith(account: accountWithEmail);
        expect(viewModel.accountDisplayName, 'test@example.com');

        // Username only
        final accountUsernameOnly = CaldavAccount(
          id: 'test-id',
          providerType: 'test',
          serverUrl: 'https://test.com',
          username: 'testuser',
          createdAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
        );

        viewModel.state = viewModel.state.copyWith(account: accountUsernameOnly);
        expect(viewModel.accountDisplayName, 'testuser');

        viewModel.dispose();
      });
    });

    group('ProjectListViewModel', () {
      test('should create and initialize correctly', () {
        final viewModel = ProjectListViewModel(
          mockCalendarRepository,
          mockTaskRepository,
          mockSyncService,
        );

        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.isRefreshing, false);
        expect(viewModel.state.error, null);
        expect(viewModel.state.projects, isEmpty);
        expect(viewModel.state.filter, ProjectFilter.all);
        expect(viewModel.state.sortBy, ProjectSort.name);
        expect(viewModel.state.searchQuery, '');
        expect(viewModel.state.totalProjects, 0);
        expect(viewModel.state.completedProjects, 0);
        expect(viewModel.state.activeProjects, 0);

        viewModel.dispose();
      });

      test('should update search and filters correctly', () {
        final viewModel = ProjectListViewModel(
          mockCalendarRepository,
          mockTaskRepository,
          mockSyncService,
        );

        // Set search query
        viewModel.setSearchQuery('test query');
        expect(viewModel.state.searchQuery, 'test query');

        // Set filter
        viewModel.setFilter(ProjectFilter.completed);
        expect(viewModel.state.filter, ProjectFilter.completed);

        // Set sort
        viewModel.setSortBy(ProjectSort.progress);
        expect(viewModel.state.sortBy, ProjectSort.progress);

        // Clear filters
        viewModel.clearFilters();
        expect(viewModel.state.searchQuery, '');
        expect(viewModel.state.filter, ProjectFilter.all);

        viewModel.dispose();
      });

      test('should return correct filter and sort display names', () {
        final viewModel = ProjectListViewModel(
          mockCalendarRepository,
          mockTaskRepository,
          mockSyncService,
        );

        expect(viewModel.getFilterDisplayName(ProjectFilter.all), 'All Projects');
        expect(viewModel.getFilterDisplayName(ProjectFilter.active), 'Active');
        expect(viewModel.getFilterDisplayName(ProjectFilter.completed), 'Completed');

        expect(viewModel.getSortDisplayName(ProjectSort.name), 'Name');
        expect(viewModel.getSortDisplayName(ProjectSort.progress), 'Progress');
        expect(viewModel.getSortDisplayName(ProjectSort.created), 'Created');

        viewModel.dispose();
      });

      test('should clear error state', () {
        final viewModel = ProjectListViewModel(
          mockCalendarRepository,
          mockTaskRepository,
          mockSyncService,
        );

        // Set error state
        viewModel.state = viewModel.state.copyWith(error: 'Test error');
        expect(viewModel.state.error, 'Test error');

        // Clear error
        viewModel.clearError();
        expect(viewModel.state.error, null);

        viewModel.dispose();
      });
    });
  });
} 