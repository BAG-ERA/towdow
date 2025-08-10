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

  /// Extract ETag from PROPFIND response
  static String? extractETag(String xmlResponse) {
    try {
      final document = XmlDocument.parse(xmlResponse);
      final etagElement = document.findAllElements('getetag').firstOrNull;
      return etagElement?.innerText;
    } catch (e) {
      AppLogger.error('XMLResponseParser: Failed to parse ETag from PROPFIND response', e, StackTrace.current);
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
      
      // Extract FlowIt namespace prefixes from the FULL XML response (namespace declarations are at root level)
      final globalFlowItPrefixes = _findFlowItNamespacePrefixes(xmlResponse);
      AppLogger.debug('XMLResponseParser: Found global FlowIt prefixes: $globalFlowItPrefixes');
      
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
        
        // Check if it's a calendar collection (when resourcetype is requested)
        final isCalendar = responseContent.contains('<C:calendar/>') || 
                          responseContent.contains('<calendar/>') ||
                          responseContent.contains('calendar'); // Fallback for basic checks
        
        // Extract display name
        final displayNamePattern = RegExp(r'<(?:d:)?displayname[^>]*>(.*?)</(?:d:)?displayname>', dotAll: true, caseSensitive: false);
        final displayNameMatch = displayNamePattern.firstMatch(responseContent);
        final displayName = displayNameMatch?.group(1)?.trim() ?? 'Unnamed Calendar';
        
        // Check VTODO support (when supported-calendar-component-set is requested)
        final supportsTodos = responseContent.contains('VTODO') || 
                             responseContent.contains('vtodo') ||
                             displayName.isNotEmpty; // Fallback assume support
        
        // Extract description
        final descriptionPattern = RegExp(r'<(?:C:)?calendar-description[^>]*>(.*?)</(?:C:)?calendar-description>', 
          dotAll: true, caseSensitive: false);
        final descriptionMatch = descriptionPattern.firstMatch(responseContent);
        final description = descriptionMatch?.group(1)?.trim();
        
        // Extract FlowIt properties using the global namespace prefixes
        AppLogger.debug('XMLResponseParser: Extracting FlowIt properties from response content for $href');
        AppLogger.debug('XMLResponseParser: Response content snippet: ${responseContent.substring(0, responseContent.length > 500 ? 500 : responseContent.length)}...');
        final domain = _extractFlowItPropertyWithPrefixes(responseContent, 'domain', globalFlowItPrefixes);
        AppLogger.debug('XMLResponseParser: Domain extraction result: $domain');
        final flowitType = _extractFlowItPropertyWithPrefixes(responseContent, 'type', globalFlowItPrefixes);
        final flowitAsFlowStr = _extractFlowItPropertyWithPrefixes(responseContent, 'asflow', globalFlowItPrefixes);
        final flowitAsFlow = flowitAsFlowStr?.toLowerCase() == 'true';
        final flowitOwner = _extractFlowItPropertyWithPrefixes(responseContent, 'owner', globalFlowItPrefixes);
        final flowitTemplate = _extractFlowItPropertyWithPrefixes(responseContent, 'template', globalFlowItPrefixes);
        final flowitStatus = _extractFlowItPropertyWithPrefixes(responseContent, 'status', globalFlowItPrefixes);
        final flowitKanban = _extractFlowItPropertyWithPrefixes(responseContent, 'kanban', globalFlowItPrefixes);
        final flowitCategories = _extractFlowItPropertyWithPrefixes(responseContent, 'categories', globalFlowItPrefixes);
        final flowitRequirements = _extractFlowItPropertyWithPrefixes(responseContent, 'requirements', globalFlowItPrefixes);
        final flowitSharedWith = _extractFlowItPropertyWithPrefixes(responseContent, 'sharedWith', globalFlowItPrefixes);
        
        if (isCalendar && supportsTodos) {
          AppLogger.debug('XMLResponseParser: Found VTODO calendar: $displayName at $href with domain: $domain, status: $flowitStatus');
          final calendar = TaskCalendarFactory.fromCalDAVDiscovery(
            path: href,
            displayName: displayName,
            description: description ?? (supportsTodos ? 'Supports tasks (VTODO)' : 'Calendar collection'),
            domain: domain,
            flowitType: flowitType,
            flowitAsFlow: flowitAsFlow,
            flowitOwner: flowitOwner,
            flowitTemplate: flowitTemplate,
            flowitStatus: flowitStatus,
            flowitKanban: flowitKanban,
            sharedWith: flowitSharedWith,
          );
          
          // Update project categories/requirements if found
          TaskCalendar withCollections = calendar;
          if (flowitCategories != null && flowitCategories.isNotEmpty) {
            withCollections = withCollections.copyWith(projectCategories: flowitCategories);
          }
          if (flowitRequirements != null && flowitRequirements.isNotEmpty) {
            withCollections = withCollections.copyWith(projectRequirements: flowitRequirements);
          }
          calendars.add(withCollections);
        }
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

  /// Parse multi-status response to extract calendar properties
  static List<Map<String, dynamic>> parseMultiStatusResponse(String xmlResponse) {
    final responses = <Map<String, dynamic>>[];
    
    try {
      AppLogger.debug('XMLResponseParser: Parsing multi-status response');
      
      // Extract individual response elements using regex
      final responsePattern = RegExp(r'<(?:d:)?response[^>]*>(.*?)</(?:d:)?response>', dotAll: true, caseSensitive: false);
      final responseMatches = responsePattern.allMatches(xmlResponse);
      
      for (final responseMatch in responseMatches) {
        final responseContent = responseMatch.group(1)!;
        
        // Check if this response has status 200 OK
        final statusPattern = RegExp(r'<(?:d:)?status[^>]*>.*?200\s+OK.*?</(?:d:)?status>', caseSensitive: false);
        if (!statusPattern.hasMatch(responseContent)) {
          continue; // Skip non-200 responses
        }
        
        final responseData = <String, dynamic>{};
        
        // Extract href
        final hrefPattern = RegExp(r'<(?:d:)?href[^>]*>(.*?)</(?:d:)?href>', caseSensitive: false);
        final hrefMatch = hrefPattern.firstMatch(responseContent);
        if (hrefMatch != null) {
          responseData['href'] = hrefMatch.group(1)!.trim();
        }
        
        // Extract display name
        final displayNamePattern = RegExp(r'<(?:d:)?displayname[^>]*>(.*?)</(?:d:)?displayname>', dotAll: true, caseSensitive: false);
        final displayNameMatch = displayNamePattern.firstMatch(responseContent);
        if (displayNameMatch != null) {
          responseData['displayname'] = displayNameMatch.group(1)!.trim();
        }
        
        // Extract resource type
        final resourceTypePattern = RegExp(r'<(?:d:)?resourcetype[^>]*>(.*?)</(?:d:)?resourcetype>', dotAll: true, caseSensitive: false);
        final resourceTypeMatch = resourceTypePattern.firstMatch(responseContent);
        if (resourceTypeMatch != null) {
          responseData['resourcetype'] = resourceTypeMatch.group(1)!.trim();
        }
        
        // Extract calendar description
        final descriptionPattern = RegExp(r'<(?:C:)?calendar-description[^>]*>(.*?)</(?:C:)?calendar-description>', dotAll: true, caseSensitive: false);
        final descriptionMatch = descriptionPattern.firstMatch(responseContent);
        if (descriptionMatch != null) {
          responseData['calendar-description'] = descriptionMatch.group(1)!.trim();
        }
        
        // Extract calendar color
        final colorPattern = RegExp(r'<(?:ICAL:)?calendar-color[^>]*>(.*?)</(?:ICAL:)?calendar-color>', dotAll: true, caseSensitive: false);
        final colorMatch = colorPattern.firstMatch(responseContent);
        if (colorMatch != null) {
          responseData['calendar-color'] = colorMatch.group(1)!.trim();
        }
        
        // Extract etag
        final etagPattern = RegExp(r'<(?:d:)?getetag[^>]*>(.*?)</(?:d:)?getetag>', dotAll: true, caseSensitive: false);
        final etagMatch = etagPattern.firstMatch(responseContent);
        if (etagMatch != null) {
          responseData['getetag'] = etagMatch.group(1)!.trim();
        }
        
        // Extract sync-token
        final syncTokenPattern = RegExp(r'<(?:d:)?sync-token[^>]*>(.*?)</(?:d:)?sync-token>', dotAll: true, caseSensitive: false);
        final syncTokenMatch = syncTokenPattern.firstMatch(responseContent);
        if (syncTokenMatch != null) {
          responseData['sync-token'] = syncTokenMatch.group(1)!.trim();
        }
        
        // Extract ctag
        final ctagPattern = RegExp(r'<(?:CS:)?getctag[^>]*>(.*?)</(?:CS:)?getctag>', dotAll: true, caseSensitive: false);
        final ctagMatch = ctagPattern.firstMatch(responseContent);
        if (ctagMatch != null) {
          responseData['getctag'] = ctagMatch.group(1)!.trim();
        }
        
        // Extract supported calendar component set
        final componentSetPattern = RegExp(r'<(?:[a-zA-Z0-9]+:)?supported-calendar-component-set[^>]*>(.*?)</(?:[a-zA-Z0-9]+:)?supported-calendar-component-set>', dotAll: true, caseSensitive: false);
        final componentSetMatch = componentSetPattern.firstMatch(responseContent);
        if (componentSetMatch != null) {
          final componentSetContent = componentSetMatch.group(1)!.trim();
          
          // Parse individual comp elements to extract component names
          final compNames = <String>[];
          final compPattern = RegExp(r'<(?:[a-zA-Z0-9]+:)?comp\s+name=["\x27]([^"\x27]+)["\x27]', caseSensitive: false);
          final compMatches = compPattern.allMatches(componentSetContent);
          
          for (final compMatch in compMatches) {
            final compName = compMatch.group(1);
            if (compName != null) {
              compNames.add(compName);
            }
          }
          
          // Store the parsed component names as a comma-separated string for backward compatibility
          responseData['supported-calendar-component-set'] = compNames.join(',');
        }
        
        // Extract FlowIt properties
        final globalFlowItPrefixes = _findFlowItNamespacePrefixes(xmlResponse);
        responseData['flowit-domain'] = _extractFlowItPropertyWithPrefixes(responseContent, 'domain', globalFlowItPrefixes);
        responseData['flowit-status'] = _extractFlowItPropertyWithPrefixes(responseContent, 'status', globalFlowItPrefixes);
        responseData['flowit-kanban'] = _extractFlowItPropertyWithPrefixes(responseContent, 'kanban', globalFlowItPrefixes);
        responseData['flowit-categories'] = _extractFlowItPropertyWithPrefixes(responseContent, 'categories', globalFlowItPrefixes);
        responseData['flowit-requirements'] = _extractFlowItPropertyWithPrefixes(responseContent, 'requirements', globalFlowItPrefixes);
        responseData['flowit-steps'] = _extractFlowItPropertyWithPrefixes(responseContent, 'steps', globalFlowItPrefixes);
        responseData['flowit-type'] = _extractFlowItPropertyWithPrefixes(responseContent, 'type', globalFlowItPrefixes);
        responseData['flowit-asflow'] = _extractFlowItPropertyWithPrefixes(responseContent, 'asflow', globalFlowItPrefixes);
        responseData['flowit-owner'] = _extractFlowItPropertyWithPrefixes(responseContent, 'owner', globalFlowItPrefixes);
        responseData['flowit-template'] = _extractFlowItPropertyWithPrefixes(responseContent, 'template', globalFlowItPrefixes);
        responseData['flowit-sharedWith'] = _extractFlowItPropertyWithPrefixes(responseContent, 'sharedWith', globalFlowItPrefixes);
        responseData['flowit-author'] = _extractFlowItPropertyWithPrefixes(responseContent, 'author', globalFlowItPrefixes);
        responseData['flowit-manager'] = _extractFlowItPropertyWithPrefixes(responseContent, 'manager', globalFlowItPrefixes);
        responseData['flowit-started-at'] = _extractFlowItPropertyWithPrefixes(responseContent, 'started-at', globalFlowItPrefixes);
        responseData['flowit-ended-at'] = _extractFlowItPropertyWithPrefixes(responseContent, 'ended-at', globalFlowItPrefixes);
        
        responses.add(responseData);
      }
      
    } catch (e) {
      AppLogger.error('XMLResponseParser: Failed to parse multi-status response', e, StackTrace.current);
    }
    
    AppLogger.debug('XMLResponseParser: Parsed ${responses.length} responses from multi-status');
    return responses;
  }

  /// Extract FlowIt property using known namespace prefixes
  /// This version takes the prefixes as a parameter to avoid re-parsing namespaces for each property
  static String? _extractFlowItPropertyWithPrefixes(String xmlContent, String propertyName, List<String> knownPrefixes) {
    try {
      AppLogger.debug('XMLResponseParser: Extracting $propertyName with known prefixes: $knownPrefixes');
      
      // Try to extract property using each known FlowIt namespace prefix
      for (final prefix in knownPrefixes) {
        final pattern = RegExp('<$prefix:$propertyName[^>]*>(.*?)</$prefix:$propertyName>', 
          dotAll: true, caseSensitive: false);
        
        final match = pattern.firstMatch(xmlContent);
        if (match != null) {
          final value = match.group(1)?.trim();
          if (value != null && value.isNotEmpty) {
            AppLogger.debug('XMLResponseParser: Found FlowIt property $propertyName=$value using prefix $prefix');
            return value;
          }
        }
      }
      
      // Fallback to legacy parsing if no prefixes worked
      return _extractFlowItPropertyLegacy(xmlContent, propertyName);
    } catch (e) {
      AppLogger.debug('XMLResponseParser: Error extracting FlowIt property $propertyName: $e');
      return null;
    }
  }

  /// Extract FlowIt property from XML response, supporting dynamic namespaces
  /// Handles server responses where FlowIt namespace is declared with dynamic prefixes
  /// Example: xmlns:ns1="https://flowit.app/ns/" and properties like `<ns1:domain>`
  static String? _extractFlowItProperty(String xmlContent, String propertyName) {
    try {
      // First, find which namespace prefix(es) map to FlowIt namespace URI
      final flowItPrefixes = _findFlowItNamespacePrefixes(xmlContent);
      
      if (flowItPrefixes.isEmpty) {
        // Fallback to old parsing for backward compatibility
        return _extractFlowItPropertyLegacy(xmlContent, propertyName);
      }
      
      // Try to extract property using each FlowIt namespace prefix
      for (final prefix in flowItPrefixes) {
        final pattern = RegExp('<$prefix:$propertyName[^>]*>(.*?)</$prefix:$propertyName>', 
          dotAll: true, caseSensitive: false);
        
        final match = pattern.firstMatch(xmlContent);
        if (match != null) {
          final value = match.group(1)?.trim();
          if (value != null && value.isNotEmpty) {
            AppLogger.debug('XMLResponseParser: Found FlowIt property $propertyName=$value using prefix $prefix');
            return value;
          }
        }
      }
      
      return null;
    } catch (e) {
      AppLogger.debug('XMLResponseParser: Error extracting FlowIt property $propertyName: $e');
      return null;
    }
  }

  /// Find namespace prefixes that map to FlowIt namespace URI
  static List<String> _findFlowItNamespacePrefixes(String xmlContent) {
    final prefixes = <String>[];
    
    try {
      // FlowIt namespace URIs (support both http and https)
      const flowItNamespaces = [
        'https://flowit.app/ns/',
        'http://flowit.app/ns/',
      ];
      
      AppLogger.debug('XMLResponseParser: Looking for FlowIt namespaces in content length: ${xmlContent.length}');
      
      // Find all xmlns declarations
      final xmlnsMatches = RegExp(r'xmlns:([^=\s]+)=["\x27]([^"\x27]+)["\x27]').allMatches(xmlContent);
      
      AppLogger.debug('XMLResponseParser: Found ${xmlnsMatches.length} xmlns declarations');
      
      for (final match in xmlnsMatches) {
        final prefix = match.group(1);
        final uri = match.group(2);
        
        AppLogger.debug('XMLResponseParser: Found namespace: $prefix -> $uri');
        
        if (prefix != null && uri != null && flowItNamespaces.contains(uri)) {
          prefixes.add(prefix);
          AppLogger.debug('XMLResponseParser: Found FlowIt namespace prefix: $prefix -> $uri');
        }
      }
      
      AppLogger.debug('XMLResponseParser: Total FlowIt prefixes found: ${prefixes.length}');
    } catch (e) {
      AppLogger.debug('XMLResponseParser: Error finding FlowIt namespace prefixes: $e');
    }
    
    return prefixes;
  }

  /// Legacy FlowIt property extraction for backward compatibility
  /// Handles formats like: `<FLOWIT:domain>`, or `<domain>` (no namespace)
  static String? _extractFlowItPropertyLegacy(String xmlContent, String propertyName) {
    try {
      final patterns = [
        // FLOWIT namespace (like FLOWIT:domain)
        RegExp('<(?:FLOWIT:)?$propertyName[^>]*>(.*?)</(?:FLOWIT:)?$propertyName>', 
          dotAll: true, caseSensitive: false),
        // No namespace (like <domain>)
        RegExp('<$propertyName[^>]*>(.*?)</$propertyName>', 
          dotAll: true, caseSensitive: false),
      ];
      
      for (final pattern in patterns) {
        final match = pattern.firstMatch(xmlContent);
        if (match != null) {
          final value = match.group(1)?.trim();
          if (value != null && value.isNotEmpty) {
            AppLogger.debug('XMLResponseParser: Found FlowIt property $propertyName=$value (legacy)');
            return value;
          }
        }
      }
      
      return null;
    } catch (e) {
      AppLogger.debug('XMLResponseParser: Error in legacy FlowIt property extraction: $e');
      return null;
    }
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