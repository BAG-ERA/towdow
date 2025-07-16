import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/data/services/caldav_service.dart';
import 'package:towdow_app/data/services/capability_discovery_service.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/services/local_storage_service.dart';
import 'package:towdow_app/data/services/user_sync_service.dart';
import 'package:towdow_app/presentation/viewmodels/calendar_selection_viewmodel.dart';

import 'calendar_selection_viewmodel_test.mocks.dart';

@GenerateMocks([
  CalDAVService,
  CapabilityDiscoveryService,
  AccountRepository,
  CalendarRepository,
  LocalStorageService,
  UserSyncService,
])
void main() {
  group('CalendarSelectionViewModel Tests', () {
    late CalendarSelectionViewModel viewModel;
    late MockCalDAVService mockCalDAVService;
    late MockCapabilityDiscoveryService mockDiscoveryService;
    late MockAccountRepository mockAccountRepository;
    late MockCalendarRepository mockCalendarRepository;
    late MockLocalStorageService mockLocalStorageService;
    late MockUserSyncService mockUserSyncService;
    late CaldavAccount testAccount;
    late TaskCalendar testCalendar;

    setUp(() {
      mockCalDAVService = MockCalDAVService();
      mockDiscoveryService = MockCapabilityDiscoveryService();
      mockAccountRepository = MockAccountRepository();
      mockCalendarRepository = MockCalendarRepository();
      mockLocalStorageService = MockLocalStorageService();
      mockUserSyncService = MockUserSyncService();

      testAccount = CaldavAccount(
        id: 'test-account',
        providerType: 'towdow_cloud',
        serverUrl: 'https://test.example.com',
        username: 'testuser',
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
      );

      testCalendar = TaskCalendarFactory.createNew(
        path: '/calendars/test-project/',
        displayName: 'Test Project',
        description: 'Test project description',
      );

      viewModel = CalendarSelectionViewModel(
        account: testAccount,
        caldavService: mockCalDAVService,
        discoveryService: mockDiscoveryService,
        accountRepository: mockAccountRepository,
        calendarRepository: mockCalendarRepository,
        localStorageService: mockLocalStorageService,
        userSyncService: mockUserSyncService,
      );
    });

    group('Initialization', () {
      test('should initialize with empty state', () {
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.error, null);
        expect(viewModel.state.availableCalendars, isEmpty);
        expect(viewModel.state.selectedCalendars, isEmpty);
        expect(viewModel.state.account, null);
      });
    });

    group('Calendar Selection', () {
      test('should toggle calendar selection', () {
        // Arrange
        final calendar = TaskCalendarFactory.createNew(
          path: '/calendars/test/',
          displayName: 'Test Calendar',
        );

        viewModel.state = viewModel.state.copyWith(
          availableCalendars: [calendar],
        );

        // Act - select calendar
        viewModel.toggleCalendarSelection(calendar);

        // Assert
        expect(viewModel.state.selectedCalendars.length, 1);
        expect(viewModel.state.selectedCalendars.first, calendar);

        // Act - deselect calendar
        viewModel.toggleCalendarSelection(calendar);

        // Assert
        expect(viewModel.state.selectedCalendars, isEmpty);
      });

      test('should select all calendars', () {
        // Arrange
        final calendars = [
          TaskCalendarFactory.createNew(
            path: '/calendars/project1/',
            displayName: 'Project 1',
          ),
          TaskCalendarFactory.createNew(
            path: '/calendars/project2/',
            displayName: 'Project 2',
          ),
        ];

        viewModel.state = viewModel.state.copyWith(
          availableCalendars: calendars,
        );

        // Act
        viewModel.selectAllCalendars();

        // Assert
        expect(viewModel.state.selectedCalendars.length, 2);
        expect(viewModel.state.selectedCalendars, calendars);
      });

      test('should deselect all calendars', () {
        // Arrange
        final calendars = [
          TaskCalendarFactory.createNew(
            path: '/calendars/project1/',
            displayName: 'Project 1',
          ),
        ];

        viewModel.state = viewModel.state.copyWith(
          availableCalendars: calendars,
          selectedCalendars: calendars,
        );

        // Act
        viewModel.deselectAllCalendars();

        // Assert
        expect(viewModel.state.selectedCalendars, isEmpty);
      });
    });

    group('Error Handling', () {
      test('should clear error', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          error: 'Test error',
        );

        // Act
        viewModel.clearError();

        // Assert
        expect(viewModel.state.error, null);
      });
    });
  });
} 