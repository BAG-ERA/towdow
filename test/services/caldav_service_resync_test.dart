// Unit tests for CalDAVService resync functionality
// Tests the resyncCalendarInfo method and XML parsing

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:towdow_app/core/result.dart';
import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/data/services/caldav_service.dart';
import 'package:towdow_app/data/services/webdav_client.dart';
import 'package:towdow_app/core/logger.dart';

import 'caldav_service_resync_test.mocks.dart';

@GenerateMocks([WebDAVClient])
void main() {
  group('CalDAVService Resync', () {
    late CalDAVService caldavService;
    late MockWebDAVClient mockWebDAVClient;
    late CaldavAccount testAccount;
    late TaskCalendar testCalendar;

    setUp(() {
      testAccount = CaldavAccount(
        id: 'test-account',
        providerType: 'custom', // Use supported provider type
        serverUrl: 'https://test.com',
        username: 'testuser',
        password: 'testpass',
        createdAt: DateTime(2024, 1, 1),
        lastSyncAt: DateTime(2024, 1, 1),
      );

      testCalendar = TaskCalendar(
        displayName: 'Test Calendar',
        description: 'Test calendar description',
        path: '/calendars/testuser/test-calendar/',
        syncToken: 'old-sync-token',
        etag: 'old-etag',
        lastSyncAt: DateTime(2024, 1, 1).subtract(const Duration(hours: 1)),
        dtstamp: DateTime(2024, 1, 1),
        created: DateTime(2024, 1, 1),
        lastModified: DateTime(2024, 1, 1),
        status: 'NEEDS-ACTION',
      );

      mockWebDAVClient = MockWebDAVClient();
      caldavService = CalDAVService(account: testAccount, client: mockWebDAVClient);
    });

    group('resyncCalendarInfo', () {
      test('should successfully resync calendar info', () async {
        // Arrange
        const xmlResponse = '''<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:response>
    <D:href>/calendars/testuser/test-calendar/</D:href>
    <D:propstat>
      <D:prop>
        <D:displayname>Updated Calendar Name</D:displayname>
        <D:getetag>"new-etag-123"</D:getetag>
        <D:sync-token>http://example.com/new-sync-token</D:sync-token>
        <C:calendar-description>Updated description</C:calendar-description>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>''';

        when(mockWebDAVClient.propfind(
          any,
          body: anyNamed('body'),
          depth: anyNamed('depth'),
        )).thenAnswer((_) async => Result.success(WebDAVResponse(
          statusCode: 207,
          body: xmlResponse,
          headers: {},
        )));

        // Act
        final result = await caldavService.resyncCalendarInfo(testCalendar);

        // Assert
        await result.when(
          success: (updatedCalendar) async {
            
            expect(updatedCalendar.displayName, equals('Updated Calendar Name'));
            expect(updatedCalendar.etag, equals('"new-etag-123"'));
            expect(updatedCalendar.syncToken, equals('http://example.com/new-sync-token'));
            expect(updatedCalendar.description, equals('Updated description'));
            expect(updatedCalendar.lastSyncAt?.isAfter(testCalendar.lastSyncAt ?? DateTime(2024, 1, 1)), isTrue);
          },
          failure: (failure) async {
            fail('Expected success but got failure: ${failure.message}');
          },
        );
      });

      test('should handle HTTP error response', () async {
        // Arrange
        when(mockWebDAVClient.propfind(
          any,
          body: anyNamed('body'),
          depth: anyNamed('depth'),
        )).thenAnswer((_) async => Result.success(WebDAVResponse(
          statusCode: 404,
          body: 'Not Found',
          headers: {},
        )));

        // Act
        final result = await caldavService.resyncCalendarInfo(testCalendar);

        // Assert
        await result.when(
          success: (calendar) async {
            fail('Expected failure but got success');
          },
          failure: (failure) async {
            expect(failure.message, contains('HTTP 404'));
          },
        );
      });

      test('should handle network failure', () async {
        // Arrange
        when(mockWebDAVClient.propfind(
          any,
          body: anyNamed('body'),
          depth: anyNamed('depth'),
        )).thenAnswer((_) async => Result.failure(Failure(
          message: 'Network error',
          exception: Exception('Connection failed'),
        )));

        // Act
        final result = await caldavService.resyncCalendarInfo(testCalendar);

        // Assert
        await result.when(
          success: (calendar) async {
            fail('Expected failure but got success');
          },
          failure: (failure) async {
            expect(failure.message, contains('Network error'));
          },
        );
      });

      test('should handle malformed XML response', () async {
        // Arrange
        const malformedXml = '<invalid>xml</invalid>';
        when(mockWebDAVClient.propfind(
          any,
          body: anyNamed('body'),
          depth: anyNamed('depth'),
        )).thenAnswer((_) async => Result.success(WebDAVResponse(
          statusCode: 207,
          body: malformedXml,
          headers: {},
        )));

        // Act
        final result = await caldavService.resyncCalendarInfo(testCalendar);

        // Assert
        await result.when(
          success: (updatedCalendar) async {
            fail('Expected failure but got success');
          },
          failure: (failure) async {
            expect(failure.message, contains('No calendar properties found in response'));
          },
        );
      });

      test('should handle missing properties gracefully', () async {
        // Arrange
        const xmlResponse = '''<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:response>
    <D:href>/calendars/testuser/test-calendar/</D:href>
    <D:propstat>
      <D:prop>
        <D:displayname>Updated Calendar Name</D:displayname>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>''';

        when(mockWebDAVClient.propfind(
          any,
          body: anyNamed('body'),
          depth: anyNamed('depth'),
        )).thenAnswer((_) async => Result.success(WebDAVResponse(
          statusCode: 207,
          body: xmlResponse,
          headers: {},
        )));

        // Act
        final result = await caldavService.resyncCalendarInfo(testCalendar);

        // Assert
        await result.when(
          success: (updatedCalendar) async {
            expect(updatedCalendar.displayName, equals('Updated Calendar Name'));
            expect(updatedCalendar.etag, isNull); // Missing ETag
            expect(updatedCalendar.syncToken, isNull); // Missing sync token
            expect(updatedCalendar.description, equals(testCalendar.description)); // Preserve original
          },
          failure: (failure) async {
            fail('Expected success but got failure: ${failure.message}');
          },
        );
      });

      test('should get both sync token and ETag in single request', () async {
        // Arrange
        const xmlResponse = '''<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:response>
    <D:href>/calendars/testuser/test-calendar/</D:href>
    <D:propstat>
      <D:prop>
        <D:getetag>"etag-123"</D:getetag>
        <D:sync-token>http://example.com/sync-token-456</D:sync-token>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>''';

        when(mockWebDAVClient.propfind(
          any,
          body: anyNamed('body'),
          depth: anyNamed('depth'),
        )).thenAnswer((_) async => Result.success(WebDAVResponse(
          statusCode: 207,
          body: xmlResponse,
          headers: {},
        )));

        // Act
        final result = await caldavService.resyncCalendarInfo(testCalendar);

        // Assert
        await result.when(
          success: (updatedCalendar) async {
            expect(updatedCalendar.etag, equals('"etag-123"'));
            expect(updatedCalendar.syncToken, equals('http://example.com/sync-token-456'));
          },
          failure: (failure) async {
            fail('Expected success but got failure: ${failure.message}');
          },
        );
      });

      test('should handle missing properties gracefully', () async {
        // Arrange
        const xmlResponse = '''<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:response>
    <D:href>/calendars/testuser/test-calendar/</D:href>
    <D:propstat>
      <D:prop>
        <!-- No properties returned -->
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>''';

        when(mockWebDAVClient.propfind(
          any,
          body: anyNamed('body'),
          depth: anyNamed('depth'),
        )).thenAnswer((_) async => Result.success(WebDAVResponse(
          statusCode: 207,
          body: xmlResponse,
          headers: {},
        )));

        // Act
        final result = await caldavService.resyncCalendarInfo(testCalendar);

        // Assert
        await result.when(
          success: (updatedCalendar) async {
            // Should preserve original values when no properties are returned
            expect(updatedCalendar.displayName, equals(testCalendar.displayName));
            expect(updatedCalendar.etag, isNull);
            expect(updatedCalendar.syncToken, isNull);
            expect(updatedCalendar.description, equals(testCalendar.description));
          },
          failure: (failure) async {
            fail('Expected success but got failure: ${failure.message}');
          },
        );
      });

      test('should use XMLResponseParser for property parsing', () async {
        // Arrange
        const xmlResponse = '''<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:response>
    <D:href>/calendars/testuser/test-calendar/</D:href>
    <D:propstat>
      <D:prop>
        <D:displayname>Test Calendar</D:displayname>
        <D:getetag>"etag-789"</D:getetag>
        <D:sync-token>http://example.com/sync-token-abc</D:sync-token>
        <C:calendar-description>Test description</C:calendar-description>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>''';

        when(mockWebDAVClient.propfind(
          any,
          body: anyNamed('body'),
          depth: anyNamed('depth'),
        )).thenAnswer((_) async => Result.success(WebDAVResponse(
          statusCode: 207,
          body: xmlResponse,
          headers: {},
        )));

        // Act
        final result = await caldavService.resyncCalendarInfo(testCalendar);

        // Assert
        await result.when(
          success: (updatedCalendar) async {
            expect(updatedCalendar.displayName, equals('Test Calendar'));
            expect(updatedCalendar.etag, equals('"etag-789"'));
            expect(updatedCalendar.syncToken, equals('http://example.com/sync-token-abc'));
            expect(updatedCalendar.description, equals('Test description'));
          },
          failure: (failure) async {
            fail('Expected success but got failure: ${failure.message}');
          },
        );
      });
    });
  });
} 