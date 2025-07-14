import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/data/services/caldav_service.dart';
import 'package:towdow_app/data/services/domain_service.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/providers/providers.dart';
import 'package:towdow_app/core/result.dart';
import 'package:towdow_app/presentation/viewmodels/project_creation_viewmodel.dart';
import 'package:towdow_app/data/services/local_storage_service.dart';

// Import the generated mocks
import 'project_creation_viewmodel_test.mocks.dart';

// Generate mocks
@GenerateMocks([
  CalDAVService,
  DomainService,
  AccountRepository,
  CalendarRepository,
  LocalStorageService,
])
void main() {
  group('ProjectCreationViewModel', () {
    late ProviderContainer container;
    late MockCalDAVService mockCalDAVService;
    late MockDomainService mockDomainService;
    late MockAccountRepository mockAccountRepository;
    late MockCalendarRepository mockCalendarRepository;
    late MockLocalStorageService mockLocalStorageService;
    late CaldavAccount testAccount;
    late TaskCalendar testCalendar;

    setUp(() {
      mockCalDAVService = MockCalDAVService();
      mockDomainService = MockDomainService();
      mockAccountRepository = MockAccountRepository();
      mockCalendarRepository = MockCalendarRepository();
      mockLocalStorageService = MockLocalStorageService();

      testAccount = CaldavAccount(
        id: 'test-account-id',
        providerType: 'custom',
        serverUrl: 'https://test.example.com',
        username: 'testuser',
        password: 'testpass',
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
      );

      testCalendar = TaskCalendar(
        path: '/test/calendar/',
        displayName: 'Test Project',
        description: 'Test Description',
        supportsTodos: true,
        dtstamp: DateTime.now(),
        created: DateTime.now(),
        lastModified: DateTime.now(),
        status: 'NEEDS-ACTION',
      );

      // Set up default stubs
      when(mockAccountRepository.getActiveAccount())
          .thenAnswer((_) async => Result.success(testAccount));

      container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(mockLocalStorageService),
          caldavServiceProvider.overrideWith((ref, account) => mockCalDAVService),
          domainServiceProvider.overrideWith((ref) => mockDomainService),
          accountRepositoryProvider.overrideWith((ref) => mockAccountRepository),
          calendarRepositoryProvider.overrideWith((ref) => mockCalendarRepository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is correct', () {
      final viewModel = container.read(projectCreationViewModelProvider.notifier);
      final state = container.read(projectCreationViewModelProvider);

      expect(state.isLoading, false);
      expect(state.error, null);
    });

    test('createProject success sets loading and clears error', () async {
      when(mockCalDAVService.createCalendar(
        displayName: 'Test Project',
        description: 'Test Description',
        uid: anyNamed('uid'),
      )).thenAnswer((_) async => Result.success(testCalendar));

      when(mockCalendarRepository.save(testCalendar))
          .thenAnswer((_) async => Result.success(testCalendar));

      when(mockDomainService.assignDomainToCalendar(any, any))
          .thenAnswer((_) async => Result.success(null));

      final viewModel = container.read(projectCreationViewModelProvider.notifier);
      
      await viewModel.createProject(
        name: 'Test Project',
        description: 'Test Description',
        domain: 'Test Domain',
      );
      
      final state = container.read(projectCreationViewModelProvider);
      expect(state.isLoading, false);
      expect(state.error, null);
    });

    test('createProject failure sets error state', () async {
      when(mockCalDAVService.createCalendar(
        displayName: 'Test Project',
        description: 'Test Description',
        uid: anyNamed('uid'),
      )).thenAnswer((_) async => Result.failure(const Failure(message: 'Calendar creation failed')));

      final viewModel = container.read(projectCreationViewModelProvider.notifier);
      
      await viewModel.createProject(
        name: 'Test Project',
        description: 'Test Description',
      );
      
      final state = container.read(projectCreationViewModelProvider);
      expect(state.isLoading, false);
      expect(state.error, contains('Create calendar failed: Calendar creation failed'));
    });

    test('createProject with domain creates domain first', () async {
      when(mockCalDAVService.createCalendar(
        displayName: 'Test Project',
        description: 'Test Description',
        uid: anyNamed('uid'),
      )).thenAnswer((_) async => Result.success(testCalendar));

      when(mockCalendarRepository.save(testCalendar))
          .thenAnswer((_) async => Result.success(testCalendar));

      when(mockDomainService.assignDomainToCalendar(any, any))
          .thenAnswer((_) async => Result.success(null));

      final viewModel = container.read(projectCreationViewModelProvider.notifier);
      
      await viewModel.createProject(
        name: 'Test Project',
        description: 'Test Description',
        domain: 'Test Domain',
      );
      
      verify(mockDomainService.assignDomainToCalendar(testCalendar.path, 'Test Domain')).called(1);
      verify(mockCalDAVService.createCalendar(
        displayName: 'Test Project',
        description: 'Test Description',
        uid: anyNamed('uid'),
      )).called(1);
    });

    test('createProject domain creation failure sets error', () async {
      when(mockCalDAVService.createCalendar(
        displayName: 'Test Project',
        description: 'Test Description',
        uid: anyNamed('uid'),
      )).thenAnswer((_) async => Result.success(testCalendar));

      when(mockCalendarRepository.save(testCalendar))
          .thenAnswer((_) async => Result.success(testCalendar));

      when(mockDomainService.assignDomainToCalendar(any, any))
          .thenAnswer((_) async => Result.failure(const Failure(message: 'Domain creation failed')));

      final viewModel = container.read(projectCreationViewModelProvider.notifier);
      
      await viewModel.createProject(
        name: 'Test Project',
        description: 'Test Description',
        domain: 'Test Domain',
      );
      
      final state = container.read(projectCreationViewModelProvider);
      expect(state.isLoading, false);
      expect(state.error, contains('Domain assign failed: Domain creation failed'));
    });

    test('createProject calendar save failure sets error', () async {
      when(mockCalDAVService.createCalendar(
        displayName: 'Test Project',
        description: 'Test Description',
        uid: anyNamed('uid'),
      )).thenAnswer((_) async => Result.success(testCalendar));

      when(mockCalendarRepository.save(testCalendar))
          .thenAnswer((_) async => Result.failure(const Failure(message: 'Calendar save failed')));

      final viewModel = container.read(projectCreationViewModelProvider.notifier);
      
      await viewModel.createProject(
        name: 'Test Project',
        description: 'Test Description',
      );
      
      final state = container.read(projectCreationViewModelProvider);
      expect(state.isLoading, false);
      expect(state.error, contains('Save calendar failed: Calendar save failed'));
    });
  });
} 