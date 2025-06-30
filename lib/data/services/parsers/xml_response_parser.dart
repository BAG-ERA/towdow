// XML response parser for CalDAV operations
// Centralizes all XML parsing logic for CalDAV responses

import 'package:xml/xml.dart';
import '../../../core/logger.dart';
import '../../models/task_calendar.dart';

class XMLResponseParser {
  /// Extract sync token from PROPFIND response
  static String? extractSyncToken(String xmlResponse) {
    try {
      final document = XmlDocument.parse(xmlResponse);
      final syncTokenElement = document.findAllElements('sync-token').firstOrNull;
      return syncTokenElement?.innerText;
    } catch (e) {
      AppLogger.error('XMLResponseParser: Failed to parse sync token from PROPFIND response', e, StackTrace.current);
      return null;
    }
  }

  /// Parse current-user-principal from PROPFIND response
  static String? extractCurrentUserPrincipal(String xmlResponse) {
    try {
      // Parse without namespace prefix first (Radicale doesn't use prefixes consistently)
      final principalPattern = RegExp(r'<current-user-principal[^>]*>.*?<href[^>]*>(.*?)</href>.*?</current-user-principal>', 
        dotAll: true, caseSensitive: false);
      final match = principalPattern.firstMatch(xmlResponse);
      
      if (match != null) {
        return match.group(1)?.trim();
      }
      
      // Fallback: with namespace prefix
      final principalPatternNS = RegExp(r'<d:current-user-principal[^>]*>.*?<d:href[^>]*>(.*?)</d:href>.*?</d:current-user-principal>', 
        dotAll: true, caseSensitive: false);
      final matchNS = principalPatternNS.firstMatch(xmlResponse);
      
      if (matchNS != null) {
        return matchNS.group(1)?.trim();
      }
      
      return null;
    } catch (e) {
      AppLogger.error('XMLResponseParser: Error parsing current-user-principal', e, StackTrace.current);
      return null;
    }
  }

  /// Parse calendar-home-set from PROPFIND response
  static String? extractCalendarHomeSet(String xmlResponse) {
    try {
      // Parse the XML response like the example:
      // <C:calendar-home-set><href>/rootdir/</href></C:calendar-home-set>
      final calendarHomePattern = RegExp(
        r'<C:calendar-home-set[^>]*>.*?<href[^>]*>(.*?)</href>.*?</C:calendar-home-set>', 
        dotAll: true, 
        caseSensitive: false
      );
      final match = calendarHomePattern.firstMatch(xmlResponse);
      
      if (match != null) {
        return match.group(1)?.trim();
      }
      
      // Fallback: try without namespace prefix
      final fallbackPattern = RegExp(
        r'<calendar-home-set[^>]*>.*?<href[^>]*>(.*?)</href>.*?</calendar-home-set>', 
        dotAll: true, 
        caseSensitive: false
      );
      final fallbackMatch = fallbackPattern.firstMatch(xmlResponse);
      
      if (fallbackMatch != null) {
        return fallbackMatch.group(1)?.trim();
      }
      
      return null;
    } catch (e) {
      AppLogger.error('XMLResponseParser: Error parsing calendar-home-set', e, StackTrace.current);
      return null;
    }
  }

  /// Parse calendar information from PROPFIND response
  static List<TaskCalendar> parseCalendarsFromResponse(String xmlResponse, String calendarHome) {
    final calendars = <TaskCalendar>[];
    
    try {
      AppLogger.debug('XMLResponseParser: Parsing calendars from XML response');
      
      // Extract individual calendar responses using regex (simple approach)
      final responsePattern = RegExp(r'<(?:d:)?response[^>]*>(.*?)</(?:d:)?response>', dotAll: true, caseSensitive: false);
      final responses = responsePattern.allMatches(xmlResponse);
      
      for (final response in responses) {
        final responseContent = response.group(1)!;
        
        // Check if this response has status 200 OK (only include successful ones)
        final statusPattern = RegExp(r'<(?:d:)?status[^>]*>.*?200\s+OK.*?</(?:d:)?status>', caseSensitive: false);
        if (!statusPattern.hasMatch(responseContent)) {
          AppLogger.debug('XMLResponseParser: Skipping response without 200 OK status');
          continue;
        }
        
        // Extract href (calendar path)
        final hrefPattern = RegExp(r'<(?:d:)?href[^>]*>(.*?)</(?:d:)?href>', caseSensitive: false);
        final hrefMatch = hrefPattern.firstMatch(responseContent);
        if (hrefMatch == null) continue;
        
        final href = hrefMatch.group(1)!.trim();
        // Skip the calendar home itself
        if (href == calendarHome || href == '$calendarHome/') continue;
        
        // Extract display name
        final displayNamePattern = RegExp(r'<(?:d:)?displayname[^>]*>(.*?)</(?:d:)?displayname>', dotAll: true, caseSensitive: false);
        final displayNameMatch = displayNamePattern.firstMatch(responseContent);
        final displayName = displayNameMatch?.group(1)?.trim() ?? 'Unnamed Calendar';
        
        // For basic discovery, assume all responses with displayname are calendars
        // We'll check VTODO support in a separate call if needed
        final isCalendar = displayName.isNotEmpty && displayName != 'Unnamed Calendar';
        
        // For now, assume all calendars can support VTODO (we'll verify later)
        // This is a reasonable assumption for modern CalDAV servers
        final supportsTodos = true;
        
        if (isCalendar) {
          AppLogger.debug('XMLResponseParser: Found calendar: $displayName at $href (VTODO: $supportsTodos)');
          calendars.add(TaskCalendarFactory.fromCalDAVDiscovery(
            path: href,
            displayName: displayName,
            //description: supportsTodos ? 'Supports tasks (VTODO)' : 'Calendar collection',
          ));
        }
      }
      
      // If no calendars found, add a default one to create
      if (calendars.isEmpty) {
        AppLogger.info('XMLResponseParser: No existing calendars found, suggesting default');
        calendars.add(TaskCalendarFactory.fromCalDAVDiscovery(
          path: '${calendarHome}flowit-tasks/',
          displayName: 'FlowIt Tasks',
          description: 'Default task calendar (to be created)',
        ));
      }
      
    } catch (e) {
      AppLogger.error('XMLResponseParser: Failed to parse calendars response', e, StackTrace.current);
      
      // Fallback calendar
      calendars.add(TaskCalendarFactory.fromCalDAVDiscovery(
        path: '${calendarHome}tasks/',
        displayName: 'Tasks',
        description: 'Default task calendar',
      ));
    }
    
    AppLogger.info('XMLResponseParser: Discovered ${calendars.length} calendars');
    return calendars;
  }

  /// Parse REPORT sync-collection response
  static Map<String, dynamic> parseSyncCollectionResponse(String xmlResponse) {
    final changes = <SyncChange>[];
    String? newSyncToken;

    try {
      final document = XmlDocument.parse(xmlResponse);
      
      // Extract new sync token
      final syncTokenElement = document.findAllElements('sync-token').firstOrNull;
      newSyncToken = syncTokenElement?.innerText;
      
      // Extract responses
      for (final responseElement in document.findAllElements('response')) {
        final href = responseElement.findElements('href').firstOrNull?.innerText;
        if (href == null) continue;
        
        final propstatElement = responseElement.findElements('propstat').firstOrNull;
        if (propstatElement == null) continue;
        
        final statusElement = propstatElement.findElements('status').firstOrNull;
        final status = statusElement?.innerText ?? '';
        
        if (status.contains('404')) {
          // Resource was deleted
          changes.add(SyncChange(
            href: href,
            type: SyncChangeType.deleted,
          ));
        } else if (status.contains('200')) {
          // Resource was created or updated
          final propElement = propstatElement.findElements('prop').firstOrNull;
          if (propElement != null) {
            final etag = propElement.findElements('getetag').firstOrNull?.innerText;
            // Try with C: namespace prefix first, then without
            final calendarDataElement = propElement.findAllElements('calendar-data').firstOrNull ??
                                       propElement.findAllElements('*').where((e) => e.localName == 'calendar-data').firstOrNull;
            
            if (calendarDataElement != null) {
              final vtodoContent = calendarDataElement.innerText;
              // Note: Task parsing will be handled by VTODOParser
              changes.add(SyncChange(
                href: href,
                etag: etag,
                type: SyncChangeType.updated, // Could be created or updated
                vtodoContent: vtodoContent,
              ));
            }
          }
        }
      }
    } catch (e) {
      AppLogger.error('XMLResponseParser: Failed to parse sync-collection response', e, StackTrace.current);
    }

    return {
      'changes': changes,
      'syncToken': newSyncToken,
    };
  }
}

// Sync change types and classes (moved from BackgroundSyncService)
enum SyncChangeType {
  created,
  updated,
  deleted,
}

class SyncChange {
  final String href;
  final String? etag;
  final SyncChangeType type;
  final String? vtodoContent; // Raw VTODO content, to be parsed by VTODOParser

  SyncChange({
    required this.href,
    this.etag,
    required this.type,
    this.vtodoContent,
  });
} 