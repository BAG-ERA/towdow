import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:towdow_app/data/services/vobject_service.dart';
import 'package:towdow_app/data/models/journal.dart';
import 'package:towdow_app/data/models/offline_file.dart';
import 'package:towdow_app/data/repositories/task_repository.dart';
import 'package:towdow_app/data/repositories/journal_repository.dart';
import 'package:towdow_app/core/result.dart';

import 'vobject_service_journal_test.mocks.dart';

@GenerateMocks([TaskRepository, JournalRepository])
void main() {
  group('VObjectService Journal Attachment Tests', () {
    late VObjectService vobjectService;
    late MockTaskRepository mockTaskRepository;
    late MockJournalRepository mockJournalRepository;

    setUp(() {
      mockTaskRepository = MockTaskRepository();
      mockJournalRepository = MockJournalRepository();
      vobjectService = VObjectService(
        taskRepository: mockTaskRepository,
        journalRepository: mockJournalRepository,
      );
    });

    test('should update journal attachments with S3 info', () async {
      // Arrange
      final journalUid = 'test-journal-123';
      final offlineFileId = 'offline-file-456';
      final s3Key = 'user/test-journal-123/document_abc123.pdf';
      final s3Url = 'https://s3.example.com/bucket/user/test-journal-123/document_abc123.pdf';
      
      final journal = Journal.createNew(
        summary: 'Test Journal',
        projectPath: '/calendars/test-project/',
      ).copyWith(
        uid: journalUid,
        attachments: '[{"uri":"$offlineFileId","filename":"document.pdf","fmttype":"application/pdf","size":1234,"aesKey":"test-key","attachType":"file"}]',
      );

      final offlineFile = OfflineFile(
        id: offlineFileId,
        taskUid: journalUid, // This is the journal UID
        fileName: 'document.pdf',
        aesKey: 'test-key',
        localPath: '/tmp/test.pdf',
        fileSize: 1234,
        contentType: 'application/pdf',
        status: OfflineFileStatus.local,
        createdAt: DateTime.now(),
        validatorId: null,
      );

      final s3Info = {
        's3Key': s3Key,
        's3Url': s3Url,
      };

      // Mock repository calls
      when(mockTaskRepository.getById(journalUid))
          .thenAnswer((_) async => const Result.success(null));
      
      when(mockJournalRepository.getById(journalUid))
          .thenAnswer((_) async => Result.success(journal));
      
      when(mockJournalRepository.save(any))
          .thenAnswer((_) async => const Result.success(null));

      // Act
      final result = await vobjectService.updateWithS3Info(offlineFile, s3Info);

      // Assert
      expect(result, isA<Success<VObjectUpdateResult>>());
      
      final updateResult = result.when(
        success: (result) => result,
        failure: (failure) => throw Exception('Expected success but got failure: ${failure.message}'),
      );
      
      expect(updateResult.updated, true);
      expect(updateResult.uid, journalUid);
      expect(updateResult.type, VObjectType.journal);
      expect(updateResult.projectPath, '/calendars/test-project/');

      // Verify the saved journal has S3 info in attachments
      final savedJournal = verify(mockJournalRepository.save(captureAny)).captured.first as Journal;
      expect(savedJournal.attachments, contains(s3Key));
      expect(savedJournal.attachments, contains(s3Url));
      expect(savedJournal.attachments, contains('"status":"uploaded"'));
    });

    test('should handle journal not found gracefully', () async {
      // Arrange
      final journalUid = 'non-existent-journal';
      final offlineFile = OfflineFile(
        id: 'offline-file-456',
        taskUid: journalUid,
        fileName: 'document.pdf',
        aesKey: 'test-key',
        localPath: '/tmp/test.pdf',
        fileSize: 1234,
        contentType: 'application/pdf',
        status: OfflineFileStatus.local,
        createdAt: DateTime.now(),
        validatorId: null,
      );

      final s3Info = {
        's3Key': 'test-s3-key',
        's3Url': 'test-s3-url',
      };

      // Mock repository calls - both return null
      when(mockTaskRepository.getById(journalUid))
          .thenAnswer((_) async => const Result.success(null));
      
      when(mockJournalRepository.getById(journalUid))
          .thenAnswer((_) async => const Result.success(null));

      // Act
      final result = await vobjectService.updateWithS3Info(offlineFile, s3Info);

      // Assert
      expect(result, isA<Error<VObjectUpdateResult>>());
      
      final failure = result.when(
        success: (result) => throw Exception('Expected failure but got success'),
        failure: (failure) => failure,
      );
      
      expect(failure.message, contains('VObject not found for uid: $journalUid'));
    });

    test('should handle empty attachments gracefully', () async {
      // Arrange
      final journalUid = 'test-journal-123';
      final offlineFileId = 'offline-file-456';
      
      final journal = Journal.createNew(
        summary: 'Test Journal',
        projectPath: '/calendars/test-project/',
      ).copyWith(
        uid: journalUid,
        attachments: '[]', // Empty attachments
      );

      final offlineFile = OfflineFile(
        id: offlineFileId,
        taskUid: journalUid,
        fileName: 'document.pdf',
        aesKey: 'test-key',
        localPath: '/tmp/test.pdf',
        fileSize: 1234,
        contentType: 'application/pdf',
        status: OfflineFileStatus.local,
        createdAt: DateTime.now(),
        validatorId: null,
      );

      final s3Info = {
        's3Key': 'test-s3-key',
        's3Url': 'test-s3-url',
      };

      // Mock repository calls
      when(mockTaskRepository.getById(journalUid))
          .thenAnswer((_) async => const Result.success(null));
      
      when(mockJournalRepository.getById(journalUid))
          .thenAnswer((_) async => Result.success(journal));

      // Act
      final result = await vobjectService.updateWithS3Info(offlineFile, s3Info);

      // Assert
      expect(result, isA<Success<VObjectUpdateResult>>());
      
      final updateResult = result.when(
        success: (result) => result,
        failure: (failure) => throw Exception('Expected success but got failure: ${failure.message}'),
      );
      
      expect(updateResult.updated, false); // No updates made
      expect(updateResult.uid, journalUid);
      expect(updateResult.type, VObjectType.journal);
    });
  });
}
