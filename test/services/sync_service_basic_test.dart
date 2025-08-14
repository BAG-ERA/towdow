// Basic sync service test to validate setup
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:towdow_app/data/services/sync/sync_service.dart';
import 'package:towdow_app/data/services/storage/local_storage_service.dart';
import 'package:towdow_app/data/repositories/task_repository.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/repositories/category_repository.dart';
import 'package:towdow_app/data/repositories/user_repository.dart';
import 'package:towdow_app/data/repositories/journal_repository.dart';
import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/core/result.dart';

import 'sync_service_basic_test.mocks.dart';

@GenerateMocks([
  TaskRepository,
  AccountRepository,
  CalendarRepository,
  CategoryRepository,
  UserRepository,
  JournalRepository,
  LocalStorageService,
])
void main() {
  group('SyncService Basic Tests', () {
    late SyncService syncService;
    late MockTaskRepository mockTaskRepository;
    late MockAccountRepository mockAccountRepository;
    late MockCalendarRepository mockCalendarRepository;
    late MockCategoryRepository mockCategoryRepository;
    late MockUserRepository mockUserRepository;
    late MockJournalRepository mockJournalRepository;
    late MockLocalStorageService mockLocalStorage;

    setUp(() {
      mockTaskRepository = MockTaskRepository();
      mockAccountRepository = MockAccountRepository();
      mockCalendarRepository = MockCalendarRepository();
      mockCategoryRepository = MockCategoryRepository();
      mockUserRepository = MockUserRepository();
      mockJournalRepository = MockJournalRepository();
      mockLocalStorage = MockLocalStorageService();

      syncService = SyncService(
        taskRepository: mockTaskRepository,
        accountRepository: mockAccountRepository,
        calendarRepository: mockCalendarRepository,
        categoryRepository: mockCategoryRepository,
        userRepository: mockUserRepository,
        journalRepository: mockJournalRepository,
        localStorage: mockLocalStorage,
      );
    });

    test('should initialize with no account', () async {
      // Arrange
      when(mockAccountRepository.getActiveAccount())
          .thenAnswer((_) async => const Result.success(null));

      // Act
      final result = await syncService.initialize();

      // Assert
      final isSuccess = result.when(
        success: (_) => true,
        failure: (_) => false,
      );
      expect(isSuccess, true);
      verify(mockAccountRepository.getActiveAccount()).called(1);
    });

    test('should provide streams and status', () {
      expect(syncService.statusStream, isA<Stream<SyncStatus>>());
      expect(syncService.progressStream, isA<Stream<double>>());
      expect(syncService.status, SyncStatus.idle);
      expect(syncService.lastSyncTime, isNull);
    });

    test('should handle no account during sync', () async {
      // Arrange
      when(mockAccountRepository.getActiveAccount())
          .thenAnswer((_) async => const Result.success(null));

      // Act
              final result = await syncService.syncAllActiveCaldav();

      // Assert
      final hasCorrectError = result.when(
        success: (_) => false,
        failure: (failure) => failure.message.contains('No active CalDAV account'),
      );
      expect(hasCorrectError, true);
      expect(syncService.status, SyncStatus.offline);
    });
  });
} 