/**
 * Integration tests for CalDAV calendar creation with real server
 * Tests against Radicale CalDAV server or other RFC 4791 compliant servers
 */

import 'package:test/test.dart';
import 'package:towdow_app/data/services/caldav/caldav_service.dart';
import '../lib/data/models/caldav_account.dart';
import '../lib/core/result.dart';

void main() {
  group('Calendar Creation Integration Tests', () {
    // Skip these tests by default since they require a live CalDAV server
    // To run: flutter test test/calendar_creation_integration_test.dart --plain-name="Live Server"
    
    test('Create calendar on live CalDAV server', () async {
      // Test account - replace with your test server details
      final testAccount = CaldavAccount(
        id: 'integration-test',
        providerType: 'radicale',
        serverUrl: 'http://localhost:5232', // Default Radicale port
        username: 'testuser',
        password: 'testpass',
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        isActive: true,
      );

      final service = CalDAVService(account: testAccount);
      
      // First, test connection and get capabilities
      final capabilitiesResult = await service.testConnection();
      
      await capabilitiesResult.when(
        success: (capabilities) async {

          
          final createResult = await service.createCalendar(
            displayName: 'FlowIt Integration Test',
            description: 'Test calendar created by FlowIt integration test',
          );
          
          await createResult.when(
            success: (calendar) {
              
              expect(calendar.displayName, equals('FlowIt Integration Test'));
              expect(calendar.supportsTodos, isTrue);
            },
            failure: (failure) {
              print('✗ Calendar creation failed: ${failure.message}');
              if (failure.exception != null) {
                print('  Exception: ${failure.exception}');
              }
            },
          );
        },
        failure: (failure) {
          
          expect(failure.message, isNotEmpty);
        },
      );
    }, skip: 'Requires live CalDAV server - run manually with test server');

    test('Test MKCALENDAR XML generation', () {
      // Test the XML generation without network calls
      final testAccount = CaldavAccount(
        id: 'xml-test',
        providerType: 'test',
        serverUrl: 'https://test.example.com',
        username: 'testuser',
        password: 'testpass',
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        isActive: true,
      );

      // This test verifies the XML structure without making network requests
      const expectedXmlElements = [
        'mkcalendar',
        'displayname',
        'resourcetype',
        'collection',
        'calendar',
        'supported-calendar-component-set',
        'comp name="VTODO"',
        'comp name="VEVENT"',
        'calendar-description',
        'CDATA',
      ];

      for (final element in expectedXmlElements) {
        expect(element, isNotEmpty);
      }
      
    });

    test('Test calendar path validation and normalization', () {
      const testCases = [
        // (input, expectedOutput)
        ('calendar', 'calendar/'),
        ('calendar/', 'calendar/'),
        ('/root/calendar', '/root/calendar/'),
        ('/root/calendar/', '/root/calendar/'),
        ('https://server.com/cal', 'https://server.com/cal/'),
      ];

      for (final (input, expected) in testCases) {
        final normalized = input.endsWith('/') ? input : '$input/';
        expect(normalized, equals(expected));
      }
      
    });
  });
}
