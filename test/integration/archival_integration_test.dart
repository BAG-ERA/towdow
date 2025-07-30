// Integration test for calendar archival functionality
// Tests that ARCHIVE status is correctly parsed from CalDAV server responses

import 'package:flutter_test/flutter_test.dart';
import 'package:towdow_app/data/services/parsers/xml_response_parser.dart';
import 'package:towdow_app/data/models/task_calendar.dart';

void main() {
  group('Calendar Archival Integration Tests', () {
    test('should parse ARCHIVE status from CalDAV XML response', () {
      // Mock CalDAV XML response with archived calendar
      const xmlResponse = '''<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:FLOWIT="https://flowit.app/ns/">
  <D:response>
    <D:href>/calendars/user/archived-project/</D:href>
    <D:propstat>
      <D:prop>
        <D:resourcetype>
          <D:collection/>
          <C:calendar/>
        </D:resourcetype>
        <D:displayname>Archived Project</D:displayname>
        <C:supported-calendar-component-set>
          <C:comp name="VTODO"/>
        </C:supported-calendar-component-set>
        <C:calendar-description>Test archived project</C:calendar-description>
        <FLOWIT:domain>Test Domain</FLOWIT:domain>
        <FLOWIT:type>PROJECT</FLOWIT:type>
        <FLOWIT:asflow>false</FLOWIT:asflow>
        <FLOWIT:status>ARCHIVE</FLOWIT:status>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>''';

      // Parse calendars from response
      final calendars = XMLResponseParser.parseCalendarsFromResponse(
        xmlResponse, 
        '/calendars/user/'
      );

      // Verify that the calendar was parsed
      expect(calendars, hasLength(1));
      
      final calendar = calendars.first;
      expect(calendar.displayName, equals('Archived Project'));
      expect(calendar.flowitStatus, equals('ARCHIVE'));
      expect(calendar.isArchived, isTrue);
      expect(calendar.flowitDomain, equals('Test Domain'));
    });

    test('should parse ongoing status from CalDAV XML response', () {
      // Mock CalDAV XML response with ongoing calendar
      const xmlResponse = '''<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:FLOWIT="https://flowit.app/ns/">
  <D:response>
    <D:href>/calendars/user/active-project/</D:href>
    <D:propstat>
      <D:prop>
        <D:resourcetype>
          <D:collection/>
          <C:calendar/>
        </D:resourcetype>
        <D:displayname>Active Project</D:displayname>
        <C:supported-calendar-component-set>
          <C:comp name="VTODO"/>
        </C:supported-calendar-component-set>
        <FLOWIT:status>ONGOING</FLOWIT:status>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>''';

      // Parse calendars from response
      final calendars = XMLResponseParser.parseCalendarsFromResponse(
        xmlResponse, 
        '/calendars/user/'
      );

      // Verify that the calendar was parsed
      expect(calendars, hasLength(1));
      
      final calendar = calendars.first;
      expect(calendar.displayName, equals('Active Project'));
      expect(calendar.flowitStatus, equals('ONGOING'));
      expect(calendar.isArchived, isFalse);
      expect(calendar.isActive, isTrue);
    });

    test('should handle calendar without status property', () {
      // Mock CalDAV XML response without status
      const xmlResponse = '''<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:FLOWIT="https://flowit.app/ns/">
  <D:response>
    <D:href>/calendars/user/regular-project/</D:href>
    <D:propstat>
      <D:prop>
        <D:resourcetype>
          <D:collection/>
          <C:calendar/>
        </D:resourcetype>
        <D:displayname>Regular Project</D:displayname>
        <C:supported-calendar-component-set>
          <C:comp name="VTODO"/>
        </C:supported-calendar-component-set>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>''';

      // Parse calendars from response
      final calendars = XMLResponseParser.parseCalendarsFromResponse(
        xmlResponse, 
        '/calendars/user/'
      );

      // Verify that the calendar was parsed
      expect(calendars, hasLength(1));
      
      final calendar = calendars.first;
      expect(calendar.displayName, equals('Regular Project'));
      expect(calendar.flowitStatus, equals('ONGOING')); // Default status when not provided in XML
      expect(calendar.statusDisplayName, equals('ONGOING')); // Default status
      expect(calendar.isArchived, isFalse);
      expect(calendar.isActive, isTrue);
    });

    test('should handle dynamic namespace prefixes for status', () {
      // Mock CalDAV XML response with dynamic namespace prefix
      const xmlResponse = '''<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:ns1="https://flowit.app/ns/">
  <D:response>
    <D:href>/calendars/user/dynamic-project/</D:href>
    <D:propstat>
      <D:prop>
        <D:resourcetype>
          <D:collection/>
          <C:calendar/>
        </D:resourcetype>
        <D:displayname>Dynamic Prefix Project</D:displayname>
        <C:supported-calendar-component-set>
          <C:comp name="VTODO"/>
        </C:supported-calendar-component-set>
        <ns1:domain>Dynamic Domain</ns1:domain>
        <ns1:status>ARCHIVE</ns1:status>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>''';

      // Parse calendars from response
      final calendars = XMLResponseParser.parseCalendarsFromResponse(
        xmlResponse, 
        '/calendars/user/'
      );

      // Verify that the calendar was parsed with dynamic namespace
      expect(calendars, hasLength(1));
      
      final calendar = calendars.first;
      expect(calendar.displayName, equals('Dynamic Prefix Project'));
      expect(calendar.flowitStatus, equals('ARCHIVE'));
      expect(calendar.flowitDomain, equals('Dynamic Domain'));
      expect(calendar.isArchived, isTrue);
    });
  });
} 