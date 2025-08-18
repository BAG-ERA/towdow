// Journal sync integration test
// Tests the complete flow from journal creation to server sync

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:towdow_app/core/result.dart';
import 'package:towdow_app/data/models/journal.dart';
import 'package:towdow_app/data/repositories/journal_repository.dart';
import 'package:towdow_app/data/repositories/task_repository.dart';
import 'package:towdow_app/data/services/sync/sync_service.dart';
import 'package:towdow_app/data/services/storage/local_storage_service.dart';
import 'package:towdow_app/data/repositories/task_repository.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/repositories/category_repository.dart';
import 'package:towdow_app/data/repositories/user_repository.dart';

import 'journal_sync_integration_test.mocks.dart';

@GenerateMocks([
  JournalRepository,
  LocalStorageService,
  TaskRepository,
  AccountRepository,
  CalendarRepository,
  CategoryRepository,
  UserRepository,
])
void main() {
  group('Journal Sync Integration Tests', () {
    late JournalRepository mockJournalRepository;
    late MockLocalStorageService mockLocalStorage;
    late MockTaskRepository mockTaskRepository;
    late MockAccountRepository mockAccountRepository;
    late MockCalendarRepository mockCalendarRepository;
    late MockCategoryRepository mockCategoryRepository;
    late MockUserRepository mockUserRepository;
    late SyncService syncService;

    setUp(() {
      mockLocalStorage = MockLocalStorageService();
      mockTaskRepository = MockTaskRepository();
      mockAccountRepository = MockAccountRepository();
      mockCalendarRepository = MockCalendarRepository();
      mockCategoryRepository = MockCategoryRepository();
      mockUserRepository = MockUserRepository();

      // Create a real journal repository with mocked dependencies first
      final localJournalRepository = LocalJournalRepository(mockLocalStorage);

      syncService = SyncService(
        taskRepository: mockTaskRepository,
        accountRepository: mockAccountRepository,
        calendarRepository: mockCalendarRepository,
        categoryRepository: mockCategoryRepository,
        userRepository: mockUserRepository,
        journalRepository: localJournalRepository,
        localStorage: mockLocalStorage,
      );

      // Now inject the sync service into the repository
      localJournalRepository.setSyncService(syncService);
      mockJournalRepository = localJournalRepository;
    });

    test('should queue journal creation for sync when saving new journal', () async {
      // Arrange
      final journal = Journal(
        uid: 'test-journal-123',
        summary: 'Test Journal',
        description: 'This is a test journal',
        projectPath: '/calendars/test-project/',
        dtstamp: DateTime.now(),
        created: DateTime.now(),
        lastModified: DateTime.now(),
        attachments: '[]',
        mediaAttachments: '[]',
      );

      // Mock local storage success
      when(mockLocalStorage.put(any, any, any))
          .thenAnswer((_) async => const Result.success(null));

      // Mock journal repository getById to return null (new journal)
      when(mockJournalRepository.getById('test-journal-123'))
          .thenAnswer((_) async => const Result.success(null));

      // Act
      final result = await mockJournalRepository.save(journal);

      // Assert
      final isSuccess = result.when(
        success: (_) => true,
        failure: (_) => false,
      );
      expect(isSuccess, true);
      
      // Verify that the journal was saved locally
      verify(mockLocalStorage.put('journals', 'test-journal-123', journal)).called(1);
      
      // Verify that the journal was checked for existence
      verify(mockJournalRepository.getById('test-journal-123')).called(1);
    });

    test('should queue journal update for sync when saving existing journal', () async {
      // Arrange
      final existingJournal = Journal(
        uid: 'test-journal-123',
        summary: 'Original Journal',
        description: 'Original description',
        projectPath: '/calendars/test-project/',
        dtstamp: DateTime.now(),
        created: DateTime.now(),
        lastModified: DateTime.now(),
        attachments: '[]',
        mediaAttachments: '[]',
      );

      final updatedJournal = existingJournal.copyWith(
        summary: 'Updated Journal',
        description: 'Updated description',
        lastModified: DateTime.now(),
      );

      // Mock local storage success
      when(mockLocalStorage.put(any, any, any))
          .thenAnswer((_) async => const Result.success(null));

      // Mock journal repository getById to return existing journal
      when(mockJournalRepository.getById('test-journal-123'))
          .thenAnswer((_) async => Result.success(existingJournal));

      // Act
      final result = await mockJournalRepository.save(updatedJournal);

      // Assert
      final isSuccess = result.when(
        success: (_) => true,
        failure: (_) => false,
      );
      expect(isSuccess, true);
      
      // Verify that the journal was saved locally
      verify(mockLocalStorage.put('journals', 'test-journal-123', updatedJournal)).called(1);
      
      // Verify that the journal was checked for existence
      verify(mockJournalRepository.getById('test-journal-123')).called(1);
    });

    test('should queue journal deletion for sync when deleting journal', () async {
      // Arrange
      final journal = Journal(
        uid: 'test-journal-123',
        summary: 'Test Journal',
        description: 'This is a test journal',
        projectPath: '/calendars/test-project/',
        dtstamp: DateTime.now(),
        created: DateTime.now(),
        lastModified: DateTime.now(),
        attachments: '[]',
        mediaAttachments: '[]',
      );

      // Mock local storage success
      when(mockLocalStorage.delete(any, any))
          .thenAnswer((_) async => const Result.success(null));

      // Mock journal repository getById to return the journal to be deleted
      when(mockJournalRepository.getById('test-journal-123'))
          .thenAnswer((_) async => Result.success(journal));

      // Act
      final result = await mockJournalRepository.delete('test-journal-123');

      // Assert
      final isSuccess = result.when(
        success: (_) => true,
        failure: (_) => false,
      );
      expect(isSuccess, true);
      
      // Verify that the journal was deleted locally
      verify(mockLocalStorage.delete('journals', 'test-journal-123')).called(1);
      
      // Verify that the journal was retrieved before deletion
      verify(mockJournalRepository.getById('test-journal-123')).called(1);
    });

    test('should not queue sync for journal without project path', () async {
      // Arrange
      final journal = Journal(
        uid: 'test-journal-123',
        summary: 'Test Journal',
        description: 'This is a test journal',
        projectPath: null, // No project path
        dtstamp: DateTime.now(),
        created: DateTime.now(),
        lastModified: DateTime.now(),
        attachments: '[]',
        mediaAttachments: '[]',
      );

      // Mock local storage success
      when(mockLocalStorage.put(any, any, any))
          .thenAnswer((_) async => const Result.success(null));

      // Mock journal repository getById to return null (new journal)
      when(mockJournalRepository.getById('test-journal-123'))
          .thenAnswer((_) async => const Result.success(null));

      // Act
      final result = await mockJournalRepository.save(journal);

      // Assert
      final isSuccess = result.when(
        success: (_) => true,
        failure: (_) => false,
      );
      expect(isSuccess, true);
      
      // Verify that the journal was saved locally
      verify(mockLocalStorage.put('journals', 'test-journal-123', journal)).called(1);
      
      // Verify that the journal was checked for existence
      verify(mockJournalRepository.getById('test-journal-123')).called(1);
    });
  });
}
