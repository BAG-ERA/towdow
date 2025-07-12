// Capability discovery service for CalDAV servers
// Implements RFC 4791 discovery flow to identify server capabilities

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/caldav_account.dart';
import '../models/task_calendar.dart';
import 'webdav_client.dart';

/// Server capabilities discovered during CalDAV discovery process
class ServerCapabilities {
  final bool supportsCalDAV;
  final bool supportsCardDAV;
  final bool supportsWebDAV;
  final bool canCreateCalendars;
  final bool canCreateAddressBooks;
  final List<String> supportedMethods;
  final List<String> davCompliance;
  final String? principal;
  final String? calendarHome;
  final String? addressBookHome;
  final String serverInfo;

  // S3 storage capabilities (optional)
  final bool supportsS3;
  final String? s3Endpoint;
  final String? privateBucket;
  final String? sharedBucket;

  const ServerCapabilities({
    required this.supportsCalDAV,
    required this.supportsCardDAV,
    required this.supportsWebDAV,
    required this.canCreateCalendars,
    required this.canCreateAddressBooks,
    required this.supportedMethods,
    required this.davCompliance,
    this.principal,
    this.calendarHome,
    this.addressBookHome,
    required this.serverInfo,
    this.supportsS3 = false,
    this.s3Endpoint,
    this.privateBucket,
    this.sharedBucket,
  });

  /// Create capabilities from server response headers
  factory ServerCapabilities.fromHeaders({
    required Map<String, String> headers,
    String? principal,
    String? calendarHome,
    String? addressBookHome,
  }) {
    final allowHeader = headers['allow']?.toLowerCase() ?? '';
    final davHeader = headers['dav']?.toLowerCase() ?? '';
    
    final supportedMethods = allowHeader.split(',').map((m) => m.trim()).toList();
    final davCompliance = davHeader.split(',').map((m) => m.trim()).toList();
    
    final supportsCalDAV = davCompliance.contains('calendar-access') || 
                          davCompliance.contains('calendar-access-1') ||
                          supportedMethods.contains('report');
    
    final supportsCardDAV = davCompliance.contains('addressbook') || 
                           davCompliance.contains('addressbook-access');
    
    final supportsWebDAV = davCompliance.contains('1') || 
                          davCompliance.contains('2') ||
                          supportedMethods.contains('propfind');
    
    return ServerCapabilities(
      supportsCalDAV: supportsCalDAV,
      supportsCardDAV: supportsCardDAV,
      supportsWebDAV: supportsWebDAV,
      canCreateCalendars: supportedMethods.contains('mkcalendar'),
      canCreateAddressBooks: supportedMethods.contains('mkcol'),
      supportedMethods: supportedMethods,
      davCompliance: davCompliance,
      principal: principal,
      calendarHome: calendarHome,
      addressBookHome: addressBookHome,
      serverInfo: 'DAV: $davHeader | Allow: $allowHeader',
      // S3 capability will be filled later by server-specific code
      supportsS3: false,
    );
  }

  bool get isCompatible => supportsWebDAV && supportsCalDAV;
  
  String get compatibilityDescription {
    if (!supportsWebDAV) return 'Server does not support WebDAV (RFC 4918)';
    if (!supportsCalDAV) return 'Server does not support CalDAV (RFC 4791)';
    return 'Server is compatible with FlowIt';
  }
}

/// Discovery result containing capabilities and available resources
class DiscoveryResult {
  final ServerCapabilities capabilities;
  final List<TaskCalendar> availableCalendars;
  final bool hasExistingCalendars;
  final String? suggestedCalendarPath;

  const DiscoveryResult({
    required this.capabilities,
    required this.availableCalendars,
    required this.hasExistingCalendars,
    this.suggestedCalendarPath,
  });
}

/// Service for discovering CalDAV server capabilities and resources
class CapabilityDiscoveryService {
  final CaldavAccount account;
  late final WebDAVClient _client;

  CapabilityDiscoveryService({required this.account}) {
    _client = WebDAVClient.fromAccount(account);
  }

  /// Perform complete CalDAV discovery process
  /// Following RFC 4791 Section 6.2.1 - CalDAV Service Discovery
  Future<Result<DiscoveryResult>> discoverCapabilities() async {
    try {
      // AppLogger.info('CapabilityDiscovery: Starting discovery for ${account.serverUrl}');
      
      // Step 1: Test basic connectivity with OPTIONS
      final optionsResult = await _testBasicConnectivity();
      return await optionsResult.when(
        success: (serverCaps) async {
          if (!serverCaps.isCompatible) {
            return Result.failure(Failure(
              message: serverCaps.compatibilityDescription,
              exception: Exception('Server incompatible'),
            ));
          }

          // Step 2: Discover principal URL
          final principalResult = await _discoverPrincipal();
          return await principalResult.when(
            success: (principal) async {
              // AppLogger.debug('CapabilityDiscovery: Found principal: $principal');
              
              // Step 3: Find calendar home
              final calendarHomeResult = await _discoverCalendarHome(principal);
              return await calendarHomeResult.when(
                success: (calendarHome) async {
                  // AppLogger.debug('CapabilityDiscovery: Found calendar home: $calendarHome');
                  
                  // Step 4: List existing calendars
                  final calendarsResult = await _discoverCalendars(calendarHome);
                  return await calendarsResult.when(
                    success: (calendars) async {
                      // Create final capabilities with discovered paths
                      final finalCapabilities = ServerCapabilities(
                        supportsCalDAV: serverCaps.supportsCalDAV,
                        supportsCardDAV: serverCaps.supportsCardDAV,
                        supportsWebDAV: serverCaps.supportsWebDAV,
                        canCreateCalendars: serverCaps.canCreateCalendars,
                        canCreateAddressBooks: serverCaps.canCreateAddressBooks,
                        supportedMethods: serverCaps.supportedMethods,
                        davCompliance: serverCaps.davCompliance,
                        principal: principal,
                        calendarHome: calendarHome,
                        serverInfo: serverCaps.serverInfo,
                        // S3 capability will be filled later by server-specific code
                        supportsS3: false,
                      );

                      final hasExisting = calendars.isNotEmpty;
                      final suggestedPath = hasExisting 
                          ? null 
                          : '${calendarHome}flowit-tasks/';

                      final result = DiscoveryResult(
                        capabilities: finalCapabilities,
                        availableCalendars: calendars,
                        hasExistingCalendars: hasExisting,
                        suggestedCalendarPath: suggestedPath,
                      );

                      // AppLogger.info('CapabilityDiscovery: Discovery completed successfully');
                      // AppLogger.info('CapabilityDiscovery: Found ${calendars.length} calendars');
                      return Result.success(result);
                    },
                    failure: (failure) async => Result.failure(failure),
                  );
                },
                failure: (failure) async => Result.failure(failure),
              );
            },
            failure: (failure) async => Result.failure(failure),
          );
        },
        failure: (failure) async => Result.failure(failure),
      );

    } catch (e, stackTrace) {
      AppLogger.error('CapabilityDiscovery: Discovery failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'CalDAV discovery failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Test basic server connectivity and capabilities
  Future<Result<ServerCapabilities>> _testBasicConnectivity() async {
    // AppLogger.debug('CapabilityDiscovery: Testing basic connectivity');
    
    final optionsResult = await _client.options('/');
    return await optionsResult.when(
      success: (response) async {
        if (response.statusCode != 200) {
          return Result.failure(Failure(
            message: 'Server returned ${response.statusCode} for OPTIONS request',
            exception: Exception('HTTP ${response.statusCode}'),
          ));
        }

        final capabilities = ServerCapabilities.fromHeaders(headers: response.headers);
        // AppLogger.debug('CapabilityDiscovery: Server capabilities: ${capabilities.serverInfo}');
        
        return Result.success(capabilities);
      },
      failure: (failure) async => Result.failure(failure),
    );
  }

  /// Discover current user principal - RFC 5397 Section 3
  Future<Result<String>> _discoverPrincipal() async {
    // AppLogger.debug('CapabilityDiscovery: Discovering current user principal');
    
    const propfindQuery = '''<?xml version="1.0" encoding="utf-8"?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:current-user-principal/>
  </D:prop>
</D:propfind>''';

    final propfindResult = await _client.propfind('/', body: propfindQuery, depth: 0);
    return await propfindResult.when(
      success: (response) async {
        if (response.statusCode != 207) {
          return Result.failure(Failure(
            message: 'PROPFIND for principal returned ${response.statusCode}',
            exception: Exception('HTTP ${response.statusCode}'),
          ));
        }

        final principal = _parseCurrentUserPrincipal(response.body);
        if (principal == null) {
          return Result.failure(Failure(
            message: 'Could not parse current-user-principal from server response',
            exception: Exception('Principal parsing failed'),
          ));
        }

        return Result.success(principal);
      },
      failure: (failure) async => Result.failure(failure),
    );
  }

  /// Discover calendar home collection - RFC 4791 Section 6.2.1
  Future<Result<String>> _discoverCalendarHome(String principal) async {
    // AppLogger.debug('CapabilityDiscovery: Discovering calendar home for principal: $principal');
    
    const propfindQuery = '''<?xml version="1.0" encoding="utf-8"?>
<D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:prop>
    <C:calendar-home-set/>
  </D:prop>
</D:propfind>''';

    final propfindResult = await _client.propfind(principal, body: propfindQuery, depth: 0);
    return await propfindResult.when(
      success: (response) async {
        if (response.statusCode != 207) {
          return Result.failure(Failure(
            message: 'PROPFIND for calendar home returned ${response.statusCode}',
            exception: Exception('HTTP ${response.statusCode}'),
          ));
        }

        final calendarHome = _parseCalendarHomeSet(response.body);
        if (calendarHome == null) {
          return Result.failure(Failure(
            message: 'Could not parse calendar-home-set from server response',
            exception: Exception('Calendar home parsing failed'),
          ));
        }

        return Result.success(calendarHome);
      },
      failure: (failure) async => Result.failure(failure),
    );
  }

  /// Discover available calendars that support VTODO
  Future<Result<List<TaskCalendar>>> _discoverCalendars(String calendarHome) async {
    AppLogger.debug('CapabilityDiscovery: Discovering calendars in: $calendarHome');
    
    const propfindQuery = '''<?xml version="1.0" encoding="utf-8"?>
<D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:FLOWIT="https://flowit.app/ns/">
  <D:prop>
    <D:resourcetype/>
    <D:displayname/>
    <C:supported-calendar-component-set/>
    <C:calendar-description/>
    <FLOWIT:domain/>
    <FLOWIT:type/>
    <FLOWIT:asflow/>
    <FLOWIT:owner/>
    <FLOWIT:template/>
  </D:prop>
</D:propfind>''';

    final propfindResult = await _client.propfind(calendarHome, body: propfindQuery, depth: 1);
    return await propfindResult.when(
      success: (response) async {
        if (response.statusCode != 207) {
          return Result.failure(Failure(
            message: 'PROPFIND for calendars returned ${response.statusCode}',
            exception: Exception('HTTP ${response.statusCode}'),
          ));
        }

        final calendars = _parseCalendarsFromResponse(response.body, calendarHome);
        AppLogger.info('CapabilityDiscovery: PROPFIND response: ${response.body}');
        AppLogger.info('CapabilityDiscovery: Found ${calendars.length} available calendars');
        
        return Result.success(calendars);
      },
      failure: (failure) async => Result.failure(failure),
    );
  }

  /// Parse current-user-principal from PROPFIND response
  String? _parseCurrentUserPrincipal(String xmlResponse) {
    try {
      final patterns = [
        RegExp(r'<(?:D:)?current-user-principal[^>]*>.*?<(?:D:)?href[^>]*>(.*?)</(?:D:)?href>.*?</(?:D:)?current-user-principal>', 
          dotAll: true, caseSensitive: false),
        RegExp(r'<current-user-principal[^>]*>.*?<href[^>]*>(.*?)</href>.*?</current-user-principal>', 
          dotAll: true, caseSensitive: false),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(xmlResponse);
        if (match != null) {
          return match.group(1)?.trim();
        }
      }

      return null;
    } catch (e) {
                // AppLogger.debug('CapabilityDiscovery: Error parsing current-user-principal: $e');
      return null;
    }
  }

  /// Parse calendar-home-set from PROPFIND response
  String? _parseCalendarHomeSet(String xmlResponse) {
    try {
      final patterns = [
        RegExp(r'<(?:C:)?calendar-home-set[^>]*>.*?<(?:D:)?href[^>]*>(.*?)</(?:D:)?href>.*?</(?:C:)?calendar-home-set>', 
          dotAll: true, caseSensitive: false),
        RegExp(r'<calendar-home-set[^>]*>.*?<href[^>]*>(.*?)</href>.*?</calendar-home-set>', 
          dotAll: true, caseSensitive: false),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(xmlResponse);
        if (match != null) {
          return match.group(1)?.trim();
        }
      }

      return null;
    } catch (e) {
              // AppLogger.debug('CapabilityDiscovery: Error parsing calendar-home-set: $e');
      return null;
    }
  }

  /// Parse available calendars from PROPFIND response
  List<TaskCalendar> _parseCalendarsFromResponse(String xmlResponse, String calendarHome) {
    final calendars = <TaskCalendar>[];
    
    try {
      // Extract FlowIt namespace prefixes from the FULL XML response (namespace declarations are at root level)
      final globalFlowItPrefixes = _findFlowItNamespacePrefixes(xmlResponse);
      AppLogger.debug('CapabilityDiscovery: Found global FlowIt prefixes: $globalFlowItPrefixes');
      
      // Extract individual responses
      final responsePattern = RegExp(r'<(?:D:)?response[^>]*>(.*?)</(?:D:)?response>', 
        dotAll: true, caseSensitive: false);
      final responses = responsePattern.allMatches(xmlResponse);
      
      for (final response in responses) {
        final responseContent = response.group(1)!;
        
        // Only process successful responses
        if (!responseContent.contains('200 OK')) continue;
        
        // Extract href (calendar path)
        final hrefPattern = RegExp(r'<(?:D:)?href[^>]*>(.*?)</(?:D:)?href>', caseSensitive: false);
        final hrefMatch = hrefPattern.firstMatch(responseContent);
        if (hrefMatch == null) continue;
        
        final href = hrefMatch.group(1)!.trim();
        if (href == calendarHome || href == '$calendarHome/') continue; // Skip home itself
        
        // Check if it's a calendar collection
        final isCalendar = responseContent.contains('<C:calendar/>') || 
                          responseContent.contains('<calendar/>');
        if (!isCalendar) continue;
        
        // Extract display name
        final displayNamePattern = RegExp(r'<(?:D:)?displayname[^>]*>(.*?)</(?:D:)?displayname>', 
          dotAll: true, caseSensitive: false);
        final displayNameMatch = displayNamePattern.firstMatch(responseContent);
        final displayName = displayNameMatch?.group(1)?.trim() ?? 'Unnamed Calendar';
        
        // Check VTODO support
        final supportsTodos = responseContent.contains('VTODO') || 
                             responseContent.contains('vtodo');
        
        // Extract description
        final descriptionPattern = RegExp(r'<(?:C:)?calendar-description[^>]*>(.*?)</(?:C:)?calendar-description>', 
          dotAll: true, caseSensitive: false);
        final descriptionMatch = descriptionPattern.firstMatch(responseContent);
        final description = descriptionMatch?.group(1)?.trim();
        
        // Extract FlowIt properties using global namespace prefixes
        AppLogger.debug('CapabilityDiscovery: Extracting FlowIt properties from response content for $href');
        AppLogger.debug('CapabilityDiscovery: Response content snippet: ${responseContent.substring(0, responseContent.length > 500 ? 500 : responseContent.length)}...');
        final domain = _extractFlowItPropertyWithPrefixes(responseContent, 'domain', globalFlowItPrefixes);
        AppLogger.debug('CapabilityDiscovery: Domain extraction result: $domain');
        final flowitType = _extractFlowItPropertyWithPrefixes(responseContent, 'type', globalFlowItPrefixes);
        final flowitAsFlowStr = _extractFlowItPropertyWithPrefixes(responseContent, 'asflow', globalFlowItPrefixes);
        final flowitAsFlow = flowitAsFlowStr?.toLowerCase() == 'true';
        final flowitOwner = _extractFlowItPropertyWithPrefixes(responseContent, 'owner', globalFlowItPrefixes);
        final flowitTemplate = _extractFlowItPropertyWithPrefixes(responseContent, 'template', globalFlowItPrefixes);
        
        if (supportsTodos) {
          AppLogger.debug('CapabilityDiscovery: Found VTODO calendar: $displayName at $href with domain: $domain');
          calendars.add(TaskCalendarFactory.fromCalDAVDiscovery(
            path: href,
            displayName: displayName,
            description: description ?? 'Supports tasks (VTODO)',
            domain: domain,
            flowitType: flowitType,
            flowitAsFlow: flowitAsFlow,
            flowitOwner: flowitOwner,
            flowitTemplate: flowitTemplate,
          ));
        }
      }
      
    } catch (e) {
      AppLogger.error('CapabilityDiscovery: Failed to parse calendars response', e, StackTrace.current);
    }
    
    return calendars;
  }

  /// Extract FlowIt property using known namespace prefixes
  /// This version takes the prefixes as a parameter to avoid re-parsing namespaces for each property
  String? _extractFlowItPropertyWithPrefixes(String xmlContent, String propertyName, List<String> knownPrefixes) {
    try {
      AppLogger.debug('CapabilityDiscovery: Extracting $propertyName with known prefixes: $knownPrefixes');
      
      // Try to extract property using each known FlowIt namespace prefix
      for (final prefix in knownPrefixes) {
        final openTag = '<$prefix:$propertyName';
        final closeTag = '</$prefix:$propertyName>';
        
        final startIndex = xmlContent.indexOf(openTag);
        if (startIndex != -1) {
          final contentStart = xmlContent.indexOf('>', startIndex) + 1;
          final contentEnd = xmlContent.indexOf(closeTag, contentStart);
          
          if (contentStart > 0 && contentEnd > contentStart) {
            final value = xmlContent.substring(contentStart, contentEnd).trim();
            if (value.isNotEmpty) {
              AppLogger.debug('CapabilityDiscovery: Found FlowIt property $propertyName=$value using prefix $prefix');
              return value;
            }
          }
        }
      }
      
      // Fallback to legacy parsing if no prefixes worked
      return _extractFlowItPropertyLegacy(xmlContent, propertyName);
    } catch (e) {
      AppLogger.debug('CapabilityDiscovery: Error extracting FlowIt property $propertyName: $e');
      return null;
    }
  }

  /// Extract FlowIt property from XML response, supporting dynamic namespaces
  /// Handles server responses where FlowIt namespace is declared with dynamic prefixes
  /// Example: xmlns:ns1="https://flowit.app/ns/" and properties like `<ns1:domain>`
  String? _extractFlowItProperty(String xmlContent, String propertyName) {
    try {
      // First, find which namespace prefix(es) map to FlowIt namespace URI
      final flowItPrefixes = _findFlowItNamespacePrefixes(xmlContent);
      
      // Try to extract property using each FlowIt namespace prefix
      for (final prefix in flowItPrefixes) {
        final openTag = '<$prefix:$propertyName';
        final closeTag = '</$prefix:$propertyName>';
        
        final startIndex = xmlContent.indexOf(openTag);
        if (startIndex != -1) {
          final contentStart = xmlContent.indexOf('>', startIndex) + 1;
          final contentEnd = xmlContent.indexOf(closeTag, contentStart);
          
          if (contentStart > 0 && contentEnd > contentStart) {
            final value = xmlContent.substring(contentStart, contentEnd).trim();
            if (value.isNotEmpty) {
              AppLogger.debug('CapabilityDiscovery: Found FlowIt property $propertyName=$value using prefix $prefix');
              return value;
            }
          }
        }
      }
      
      // Fallback to legacy parsing for backward compatibility
      return _extractFlowItPropertyLegacy(xmlContent, propertyName);
    } catch (e) {
      AppLogger.debug('CapabilityDiscovery: Error extracting FlowIt property $propertyName: $e');
      return null;
    }
  }
  
  /// Find namespace prefixes that map to FlowIt namespace URI
  /// Supports both http:// and https:// versions of the FlowIt namespace
  List<String> _findFlowItNamespacePrefixes(String xmlContent) {
    final prefixes = <String>[];
    
    try {
      // Look for FlowIt namespace declarations (both http and https)
      final httpPattern = 'http://flowit.app/ns/';
      final httpsPattern = 'https://flowit.app/ns/';
      
      // Find all xmlns declarations
      final xmlnsMatches = RegExp(r'xmlns:([^=\s]+)=["\x27]([^"\x27]+)["\x27]').allMatches(xmlContent);
      
      for (final match in xmlnsMatches) {
        final prefix = match.group(1);
        final uri = match.group(2);
        
        if (prefix != null && uri != null) {
          if (uri == httpPattern || uri == httpsPattern) {
            if (!prefixes.contains(prefix)) {
              prefixes.add(prefix);
              AppLogger.debug('CapabilityDiscovery: Found FlowIt namespace prefix: $prefix for URI: $uri');
            }
          }
        }
      }
    } catch (e) {
      AppLogger.debug('CapabilityDiscovery: Error finding FlowIt namespace prefixes: $e');
    }
    
    return prefixes;
  }
  
  /// Legacy FlowIt property extraction for backward compatibility
  /// Handles formats like: `<FLOWIT:domain>`, or `<domain>` (no namespace)
  String? _extractFlowItPropertyLegacy(String xmlContent, String propertyName) {
    try {
      // Try FLOWIT namespace format
      final flowitOpenTag = '<FLOWIT:$propertyName';
      final flowitCloseTag = '</FLOWIT:$propertyName>';
      
      var startIndex = xmlContent.indexOf(flowitOpenTag);
      if (startIndex != -1) {
        final contentStart = xmlContent.indexOf('>', startIndex) + 1;
        final contentEnd = xmlContent.indexOf(flowitCloseTag, contentStart);
        
        if (contentStart > 0 && contentEnd > contentStart) {
          final value = xmlContent.substring(contentStart, contentEnd).trim();
          if (value.isNotEmpty) {
            AppLogger.debug('CapabilityDiscovery: Found FlowIt property $propertyName=$value using FLOWIT namespace');
            return value;
          }
        }
      }
      
      // Try no namespace format
      final openTag = '<$propertyName';
      final closeTag = '</$propertyName>';
      
      startIndex = xmlContent.indexOf(openTag);
      if (startIndex != -1) {
        final contentStart = xmlContent.indexOf('>', startIndex) + 1;
        final contentEnd = xmlContent.indexOf(closeTag, contentStart);
        
        if (contentStart > 0 && contentEnd > contentStart) {
          final value = xmlContent.substring(contentStart, contentEnd).trim();
          if (value.isNotEmpty) {
            AppLogger.debug('CapabilityDiscovery: Found FlowIt property $propertyName=$value using no namespace');
            return value;
          }
        }
      }

      return null;
    } catch (e) {
      AppLogger.debug('CapabilityDiscovery: Error in legacy FlowIt property extraction for $propertyName: $e');
      return null;
    }
  }
}

// Extension to help with capabilities copying
extension ServerCapabilitiesCopy on ServerCapabilities {
  ServerCapabilities copyWith({
    bool? supportsCalDAV,
    bool? supportsCardDAV, 
    bool? supportsWebDAV,
    bool? canCreateCalendars,
    bool? canCreateAddressBooks,
    List<String>? supportedMethods,
    List<String>? davCompliance,
    String? principal,
    String? calendarHome,
    String? addressBookHome,
    String? serverInfo,
  }) {
    return ServerCapabilities(
      supportsCalDAV: supportsCalDAV ?? this.supportsCalDAV,
      supportsCardDAV: supportsCardDAV ?? this.supportsCardDAV,
      supportsWebDAV: supportsWebDAV ?? this.supportsWebDAV,
      canCreateCalendars: canCreateCalendars ?? this.canCreateCalendars,
      canCreateAddressBooks: canCreateAddressBooks ?? this.canCreateAddressBooks,
      supportedMethods: supportedMethods ?? this.supportedMethods,
      davCompliance: davCompliance ?? this.davCompliance,
      principal: principal ?? this.principal,
      calendarHome: calendarHome ?? this.calendarHome,
      addressBookHome: addressBookHome ?? this.addressBookHome,
      serverInfo: serverInfo ?? this.serverInfo,
    );
  }
} 
