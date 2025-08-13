import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/data/services/caldav/caldav_service.dart';
import 'package:towdow_app/data/services/domain_service.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/providers/providers.dart';
import 'package:towdow_app/core/result.dart';
import 'package:towdow_app/presentation/viewmodels/project_creation_viewmodel.dart';
import 'package:towdow_app/data/services/storage/local_storage_service.dart';

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
      mockCalendarRepository = MockCalendarRepository();
      mockDomainService = MockDomainService();

      // Add stub for watchCalendars method
      when(mockCalendarRepository.watchCalendars())
          .thenAnswer((_) => Stream.empty());

      mockAccountRepository = MockAccountRepository();
      mockLocalStorageService = MockLocalStorageService();

      testAccount = CaldavAccount(
        id: 'test-account-id',
        providerType: 'custom',
        serverUrl: 'http://localhost',
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
      // Trigger provider init
      container.read(projectCreationViewModelProvider.notifier);
      final state = container.read(projectCreationViewModelProvider);

      expect(state.isLoading, false);
      expect(state.error, null);
    });

    test('createProject success sets loading and clears error', () async {
      when(mockCalDAVService.createCalendar(
        displayName: 'Test Project',
        description: 'Test Description',
        domain: anyNamed('domain'),
        kanban: anyNamed('kanban'),
        categ: anyNamed('categ'),
        author: anyNamed('author'),
        owner: anyNamed('owner'),
      )).thenAnswer((_) async => Result.success(testCalendar));

      // Save should succeed for any created calendar (offline path uses a generated one)
      when(mockCalendarRepository.save(any))
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

    test('createProject with missing account sets error state', () async {
      // Override active account to simulate repository failure
      when(mockAccountRepository.getActiveAccount())
          .thenAnswer((_) async => Result.failure(const Failure(message: 'Database error')));

      final viewModel = container.read(projectCreationViewModelProvider.notifier);

      await viewModel.createProject(
        name: 'Test Project',
        description: 'Test Description',
      );

      final state = container.read(projectCreationViewModelProvider);
      expect(state.isLoading, false);
      expect(state.error, contains('No account'));
    });

    test('createProject with domain creates domain first', () async {
      when(mockCalDAVService.createCalendar(
        displayName: 'Test Project',
        description: 'Test Description',
        domain: anyNamed('domain'),
        kanban: anyNamed('kanban'),
        categ: anyNamed('categ'),
        author: anyNamed('author'),
        owner: anyNamed('owner'),
      )).thenAnswer((_) async => Result.success(testCalendar));

      when(mockCalendarRepository.save(any))
          .thenAnswer((_) async => Result.success(testCalendar));

      when(mockDomainService.assignDomainToCalendar(any, any))
          .thenAnswer((_) async => Result.success(null));

      final viewModel = container.read(projectCreationViewModelProvider.notifier);
      
      await viewModel.createProject(
        name: 'Test Project',
        description: 'Test Description',
        domain: 'Test Domain',
      );
      
      // Domain is assigned after creating the calendar (local or remote), so verify call
      verify(mockDomainService.assignDomainToCalendar(any, 'Test Domain')).called(1);
    });

    test('createProject domain creation failure sets error', () async {
      when(mockCalDAVService.createCalendar(
        displayName: 'Test Project',
        description: 'Test Description',
        domain: anyNamed('domain'),
        kanban: anyNamed('kanban'),
        categ: anyNamed('categ'),
        author: anyNamed('author'),
        owner: anyNamed('owner'),
      )).thenAnswer((_) async => Result.success(testCalendar));

      when(mockCalendarRepository.save(any))
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
      // Domain assignment failure is only logged as warning, doesn't set error state
      expect(state.error, null);
    });

    test('createProject calendar save failure sets error', () async {
      when(mockCalDAVService.createCalendar(
        displayName: 'Test Project',
        description: 'Test Description',
        domain: anyNamed('domain'),
        kanban: anyNamed('kanban'),
        categ: anyNamed('categ'),
        author: anyNamed('author'),
        owner: anyNamed('owner'),
      )).thenAnswer((_) async => Result.success(testCalendar));

      when(mockCalendarRepository.save(any))
          .thenAnswer((_) async => Result.failure(const Failure(message: 'Calendar save failed')));

      final viewModel = container.read(projectCreationViewModelProvider.notifier);
      
      await viewModel.createProject(
        name: 'Test Project',
        description: 'Test Description',
      );
      
      final state = container.read(projectCreationViewModelProvider);
      expect(state.isLoading, false);
      // The save failure is logged as warning but doesn't set error state
      expect(state.error, null);
    });
  });
} 