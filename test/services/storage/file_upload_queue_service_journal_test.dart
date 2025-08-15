import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileUploadQueueService - Unique Filename Generation', () {
    /// Test helper function that mimics the generateUniqueFileName logic
    String generateUniqueFileName(String originalFileName, String offlineFileId) {
      // Extract file extension
      final lastDotIndex = originalFileName.lastIndexOf('.');
      String nameWithoutExtension;
      String extension;
      
      if (lastDotIndex > 0) {
        nameWithoutExtension = originalFileName.substring(0, lastDotIndex);
        extension = originalFileName.substring(lastDotIndex);
      } else {
        nameWithoutExtension = originalFileName;
        extension = '';
      }
      
      // Use first 8 characters of offline file ID as unique suffix
      final uniqueSuffix = offlineFileId.substring(0, 8);
      
      // Combine: original_name_uuid.ext
      return '${nameWithoutExtension}_$uniqueSuffix$extension';
    }

    test('should generate unique filenames for files with same name', () {
      // Test files with same name but different offline file IDs
      const fileName1 = 'document.pdf';
      const fileName2 = 'document.pdf';
      const offlineFileId1 = '12345678-1234-1234-1234-123456789abc';
      const offlineFileId2 = '87654321-4321-4321-4321-cba987654321';

      // Generate unique filenames
      final uniqueName1 = generateUniqueFileName(fileName1, offlineFileId1);
      final uniqueName2 = generateUniqueFileName(fileName2, offlineFileId2);

      // Verify they are different
      expect(uniqueName1, isNot(equals(uniqueName2)));
      
      // Verify they follow the expected pattern: original_name_uuid.ext
      expect(uniqueName1, equals('document_12345678.pdf'));
      expect(uniqueName2, equals('document_87654321.pdf'));
    });

    test('should handle files without extensions', () {
      const fileName = 'README';
      const offlineFileId = '12345678-1234-1234-1234-123456789abc';

      final uniqueName = generateUniqueFileName(fileName, offlineFileId);
      expect(uniqueName, equals('README_12345678'));
    });

    test('should handle files with multiple dots', () {
      const fileName = 'my.backup.tar.gz';
      const offlineFileId = '12345678-1234-1234-1234-123456789abc';

      final uniqueName = generateUniqueFileName(fileName, offlineFileId);
      expect(uniqueName, equals('my.backup.tar_12345678.gz'));
    });

    test('should handle files with dots at the beginning', () {
      const fileName = '.hidden_file';
      const offlineFileId = '12345678-1234-1234-1234-123456789abc';

      final uniqueName = generateUniqueFileName(fileName, offlineFileId);
      expect(uniqueName, equals('.hidden_file_12345678'));
    });

    test('should handle files with only extension', () {
      const fileName = '.gitignore';
      const offlineFileId = '12345678-1234-1234-1234-123456789abc';

      final uniqueName = generateUniqueFileName(fileName, offlineFileId);
      expect(uniqueName, equals('.gitignore_12345678'));
    });
  });
}


