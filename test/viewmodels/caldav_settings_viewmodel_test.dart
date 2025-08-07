/// Tests unitaires pour CaldavSettingsViewModel
/// Teste la logique métier de configuration CalDAV et découverte des calendriers

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:towdow_app/presentation/viewmodels/caldav_settings_viewmodel.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/core/result.dart';

// Generate mocks
@GenerateMocks([AccountRepository, CalendarRepository])
import 'caldav_settings_viewmodel_test.mocks.dart';

void main() {
  group('CaldavSettingsViewModel', () {
    late CaldavSettingsViewModel viewModel;
    late MockAccountRepository mockAccountRepository;
    late MockCalendarRepository mockCalendarRepository;

    setUp(() {
      mockAccountRepository = MockAccountRepository();
      mockCalendarRepository = MockCalendarRepository();
      viewModel = CaldavSettingsViewModel(
        mockAccountRepository,
        mockCalendarRepository,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('initial state should be default', () {
      expect(viewModel.state.isLoading, false);
      expect(viewModel.state.isDiscovering, false);
      expect(viewModel.state.error, null);
      expect(viewModel.state.currentAccount, null);
      expect(viewModel.state.availableCalendars, isEmpty);
      expect(viewModel.state.selectedCalendars, isEmpty);
      expect(viewModel.state.serverCapabilities, isEmpty);
    });

    group('initialize', () {
      test('should load account and calendars successfully', () async {
        // Arrange
        final testAccount = CaldavAccount(
          id: 'test-id',
          providerType: 'test',
          serverUrl: 'https://test.com',
          username: 'testuser',
          createdAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
        );

        final testCalendars = [
          TaskCalendar(
            path: '/test/calendar1',
            displayName: 'Test Calendar 1',
            dtstamp: DateTime.now(),
            created: DateTime.now(),
            lastModified: DateTime.now(),
            status: 'NEEDS-ACTION',
          ),
        ];

        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.success(testAccount));
        when(mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => Result.success(testCalendars));

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.currentAccount, testAccount);
        expect(viewModel.state.selectedCalendars, testCalendars);
        expect(viewModel.state.error, null);
      });

      test('should handle account loading failure', () async {
        // Arrange
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.failure(
                Failure(exception: Exception('Test error'), message: 'Test error')));

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.error, contains('Failed to load account'));
      });

      test('should handle no active account', () async {
        // Arrange
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.success(null));

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.currentAccount, null);
        expect(viewModel.state.error, null);
      });
    });

    group('toggleCalendarSelection', () {
      test('should add calendar to selection when not selected', () async {
        // Arrange
        final testCalendar = TaskCalendar(
          path: '/test/calendar1',
          displayName: 'Test Calendar 1',
          dtstamp: DateTime.now(),
          created: DateTime.now(),
          lastModified: DateTime.now(),
          status: 'NEEDS-ACTION',
        );

        when(mockCalendarRepository.save(any))
            .thenAnswer((_) async => Result.success(null));

        // Act
        await viewModel.toggleCalendarSelection(testCalendar);

        // Assert
        expect(viewModel.state.selectedCalendars, contains(testCalendar));
        verify(mockCalendarRepository.save(testCalendar)).called(1);
      });

      test('should remove calendar from selection when already selected', () async {
        // Arrange
        final testCalendar = TaskCalendar(
          path: '/test/calendar1',
          displayName: 'Test Calendar 1',
          dtstamp: DateTime.now(),
          created: DateTime.now(),
          lastModified: DateTime.now(),
          status: 'NEEDS-ACTION',
        );

        // Setup initial state with selected calendar
        viewModel.state = viewModel.state.copyWith(
          selectedCalendars: [testCalendar],
        );

        when(mockCalendarRepository.unsyncCalendar(testCalendar.path))
            .thenAnswer((_) async => Result.success(null));

        // Act
        await viewModel.toggleCalendarSelection(testCalendar);

        // Assert
        expect(viewModel.state.selectedCalendars, isEmpty);
        verify(mockCalendarRepository.unsyncCalendar(testCalendar.path)).called(1);
      });

      test('should handle save failure', () async {
        // Arrange
        final testCalendar = TaskCalendar(
          path: '/test/calendar1',
          displayName: 'Test Calendar 1',
          dtstamp: DateTime.now(),
          created: DateTime.now(),
          lastModified: DateTime.now(),
          status: 'NEEDS-ACTION',
        );

        when(mockCalendarRepository.save(any))
            .thenAnswer((_) async => Result.failure(
                Failure(exception: Exception('Save error'), message: 'Save failed')));

        // Act
        await viewModel.toggleCalendarSelection(testCalendar);

        // Assert
        expect(viewModel.state.error, contains('Failed to add calendar'));
        expect(viewModel.state.selectedCalendars, isEmpty);
      });
    });

    group('createCalendar', () {
      test('should create calendar successfully', () async {
        // Arrange
        final testAccount = CaldavAccount(
          id: 'test-id',
          providerType: 'test',
          serverUrl: 'https://test.com',
          username: 'testuser',
          createdAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
        );

        viewModel.state = viewModel.state.copyWith(currentAccount: testAccount);

        when(mockCalendarRepository.save(any))
            .thenAnswer((_) async => Result.success(null));

        // Act
        await viewModel.createCalendar(
          name: 'New Calendar',
          description: 'Test description',
        );

        // Assert
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.error, null);
        expect(viewModel.state.availableCalendars.length, 1);
        expect(viewModel.state.selectedCalendars.length, 1);
        
        final createdCalendar = viewModel.state.availableCalendars.first;
        expect(createdCalendar.displayName, 'New Calendar');
        expect(createdCalendar.description, 'Test description');
        
        verify(mockCalendarRepository.save(any)).called(1);
      });

      test('should handle no active account', () async {
        // Act
        await viewModel.createCalendar(
          name: 'New Calendar',
          description: 'Test description',
        );

        // Assert
        expect(viewModel.state.error, 'No active account configured');
        verifyNever(mockCalendarRepository.save(any));
      });

      test('should handle creation failure', () async {
        // Arrange
        final testAccount = CaldavAccount(
          id: 'test-id',
          providerType: 'test',
          serverUrl: 'https://test.com',
          username: 'testuser',
          createdAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
        );

        viewModel.state = viewModel.state.copyWith(currentAccount: testAccount);

        when(mockCalendarRepository.save(any))
            .thenAnswer((_) async => Result.failure(
                Failure(exception: Exception('Create error'), message: 'Creation failed')));

        // Act
        await viewModel.createCalendar(
          name: 'New Calendar',
          description: 'Test description',
        );

        // Assert
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.error, contains('Failed to create calendar'));
      });
    });

    group('isCalendarSelected', () {
      test('should return true for selected calendar', () {
        // Arrange
        final testCalendar = TaskCalendar(
          path: '/test/calendar1',
          displayName: 'Test Calendar 1',
          dtstamp: DateTime.now(),
          created: DateTime.now(),
          lastModified: DateTime.now(),
          status: 'NEEDS-ACTION',
        );

        viewModel.state = viewModel.state.copyWith(
          selectedCalendars: [testCalendar],
        );

        // Act & Assert
        expect(viewModel.isCalendarSelected(testCalendar), true);
      });

      test('should return false for non-selected calendar', () {
        // Arrange
        final testCalendar = TaskCalendar(
          path: '/test/calendar1',
          displayName: 'Test Calendar 1',
          dtstamp: DateTime.now(),
          created: DateTime.now(),
          lastModified: DateTime.now(),
          status: 'NEEDS-ACTION',
        );

        // Act & Assert
        expect(viewModel.isCalendarSelected(testCalendar), false);
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

    group('getters', () {
      test('selectedCalendarCount should return correct count', () {
        // Arrange
        final calendars = List.generate(3, (index) => 
          TaskCalendar(
            path: '/test/calendar$index',
            displayName: 'Test Calendar $index',
            dtstamp: DateTime.now(),
            created: DateTime.now(),
            lastModified: DateTime.now(),
            status: 'NEEDS-ACTION',
          )
        );

        viewModel.state = viewModel.state.copyWith(selectedCalendars: calendars);

        // Act & Assert
        expect(viewModel.selectedCalendarCount, 3);
      });

      test('taskSupportedCalendarCount should return correct count', () {
        // Arrange
        final calendars = [
          TaskCalendar(
            path: '/test/calendar1',
            displayName: 'Test Calendar 1',
            supportsTodos: true,
            dtstamp: DateTime.now(),
            created: DateTime.now(),
            lastModified: DateTime.now(),
            status: 'NEEDS-ACTION',
          ),
          TaskCalendar(
            path: '/test/calendar2',
            displayName: 'Test Calendar 2',
            supportsTodos: false,
            dtstamp: DateTime.now(),
            created: DateTime.now(),
            lastModified: DateTime.now(),
            status: 'NEEDS-ACTION',
          ),
          TaskCalendar(
            path: '/test/calendar3',
            displayName: 'Test Calendar 3',
            supportsTodos: true,
            dtstamp: DateTime.now(),
            created: DateTime.now(),
            lastModified: DateTime.now(),
            status: 'NEEDS-ACTION',
          ),
        ];

        viewModel.state = viewModel.state.copyWith(availableCalendars: calendars);

        // Act & Assert
        expect(viewModel.taskSupportedCalendarCount, 2);
      });
    });
  });
} 