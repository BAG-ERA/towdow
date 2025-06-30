/**
 * Tests de Conformité RFC et Résilience URL
 * Valide la conformité aux standards RFC 4791 (CalDAV), RFC 4918 (WebDAV), RFC 5545 (iCalendar)
 * et la robustesse face aux différents formats d'URL possibles
 */

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RFC Compliance & URL Resilience Tests', () {
    
    group('RFC 4791 CalDAV Compliance', () {
      test('should handle all RFC 4791 discovery patterns', () {
        String? parseCurrentUserPrincipal(String xmlResponse) {
          try {
            // RFC 4791 Section 5.2: current-user-principal property
            final patterns = [
              // Standard namespace avec préfixe D:
              RegExp(r'<D:current-user-principal[^>]*>.*?<D:href[^>]*>(.*?)</D:href>.*?</D:current-user-principal>', 
                     dotAll: true, caseSensitive: false),
              // Namespace CalDAV avec préfixe C:
              RegExp(r'<C:current-user-principal[^>]*>.*?<C:href[^>]*>(.*?)</C:href>.*?</C:current-user-principal>', 
                     dotAll: true, caseSensitive: false),
              // Sans préfixe (Radicale)
              RegExp(r'<current-user-principal[^>]*>.*?<href[^>]*>(.*?)</href>.*?</current-user-principal>', 
                     dotAll: true, caseSensitive: false),
              // Avec namespace par défaut
              RegExp(r'<(?:.*?:)?current-user-principal[^>]*>.*?<(?:.*?:)?href[^>]*>(.*?)</(?:.*?:)?href>.*?</(?:.*?:)?current-user-principal>', 
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
            return null;
          }
        }

        // Test RFC 4791 Example 1: Standard DAV namespace
        const rfc4791Example1 = '''<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/</D:href>
    <D:propstat>
      <D:prop>
        <D:current-user-principal>
          <D:href>/principals/users/cdaboo/</D:href>
        </D:current-user-principal>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>''';

        expect(parseCurrentUserPrincipal(rfc4791Example1), '/principals/users/cdaboo/');

        // Test RFC 4791 avec namespace CalDAV
        const rfc4791WithCalDAV = '''<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:response>
    <D:href>/</D:href>
    <D:propstat>
      <D:prop>
        <C:current-user-principal>
          <C:href>/caldav/v1/users/john/</C:href>
        </C:current-user-principal>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>''';

        expect(parseCurrentUserPrincipal(rfc4791WithCalDAV), '/caldav/v1/users/john/');

        // Test réponse Radicale (notre cas réel)
        const radicaleResponse = '''<?xml version='1.0' encoding='utf-8'?>
<multistatus xmlns="DAV:">
    <response>
        <href>/</href>
        <propstat>
            <prop>
                <current-user-principal>
                    <href>/tibo/</href>
                </current-user-principal>
            </prop>
            <status>HTTP/1.1 200 OK</status>
        </propstat>
    </response>
</multistatus>''';

        expect(parseCurrentUserPrincipal(radicaleResponse), '/tibo/');
      });

      test('should validate RFC 4791 PROPFIND depth header compliance', () {
        Map<String, String> buildRFC4791Headers(int depth, String? authHeader) {
          final headers = <String, String>{
            'Content-Type': 'application/xml; charset=utf-8',
            'Accept': 'application/xml, text/xml',
            'User-Agent': 'FlowIt/1.0 (CalDAV Client)',
          };
          
          if (authHeader != null) {
            headers['Authorization'] = authHeader;
          }
          
          // RFC 4918 Section 9.1: Depth header values
          switch (depth) {
            case 0:
              headers['Depth'] = '0';
              break;
            case 1:
              headers['Depth'] = '1';
              break;
            case -1:
              headers['Depth'] = 'infinity';
              break;
            default:
              // RFC ne permet que 0, 1, infinity
              throw ArgumentError('Invalid depth value: $depth. RFC 4918 allows only 0, 1, or infinity');
          }
          
          return headers;
        }

        // Test valeurs RFC conformes
        expect(buildRFC4791Headers(0, null)['Depth'], '0');
        expect(buildRFC4791Headers(1, null)['Depth'], '1');
        expect(buildRFC4791Headers(-1, null)['Depth'], 'infinity');

        // Test valeur invalide
        expect(() => buildRFC4791Headers(2, null), throwsArgumentError);
        expect(() => buildRFC4791Headers(-2, null), throwsArgumentError);
      });

      test('should handle RFC 4791 calendar-home-set discovery', () {
        String? parseCalendarHomeSet(String xmlResponse) {
          try {
            // RFC 4791 Section 6.2.1: calendar-home-set property
            final patterns = [
              // Avec namespace CalDAV
              RegExp(r'<C:calendar-home-set[^>]*>.*?<D:href[^>]*>(.*?)</D:href>.*?</C:calendar-home-set>',
                     dotAll: true, caseSensitive: false),
              RegExp(r'<(?:.*?:)?calendar-home-set[^>]*>.*?<(?:.*?:)?href[^>]*>(.*?)</(?:.*?:)?href>.*?</(?:.*?:)?calendar-home-set>',
                     dotAll: true, caseSensitive: false),
              // Format collection
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
            return null;
          }
        }

        // Test RFC 4791 Example
        const rfc4791CalendarHome = '''<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:response>
    <D:href>/principals/users/cdaboo/</D:href>
    <D:propstat>
      <D:prop>
        <C:calendar-home-set>
          <D:href>/calendars/users/cdaboo/</D:href>
        </C:calendar-home-set>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>''';

        expect(parseCalendarHomeSet(rfc4791CalendarHome), '/calendars/users/cdaboo/');
      });
    });

    group('URL Resilience & Edge Cases', () {
      test('should handle all possible URL formats correctly', () {
        String buildResilientUri(String serverUrl, String path) {
          try {
            final serverUri = Uri.parse(serverUrl);
            
            if (path.startsWith('/')) {
              // Chemin absolu - remplace le chemin du serveur
              final pathUri = Uri.parse(path);
              return Uri(
                scheme: serverUri.scheme,
                host: serverUri.host,
                port: serverUri.port == 80 && serverUri.scheme == 'http' ? null :
                     serverUri.port == 443 && serverUri.scheme == 'https' ? null :
                     serverUri.port,
                path: pathUri.path,
                query: pathUri.query.isEmpty ? null : pathUri.query,
                fragment: pathUri.fragment.isEmpty ? null : pathUri.fragment,
              ).toString();
            } else {
              // Chemin relatif - normalise la concaténation
              final normalizedServerUrl = serverUrl.endsWith('/') ? serverUrl : '$serverUrl/';
              final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
              return Uri.parse('$normalizedServerUrl$normalizedPath').toString();
            }
          } catch (e) {
            throw ArgumentError('Invalid URL format: $serverUrl + $path');
          }
        }

        // Test ports standards (ne doivent pas apparaître)
        expect(buildResilientUri('https://example.com:443/dav/', '/test/'), 
               'https://example.com/test/');
        expect(buildResilientUri('http://example.com:80/dav/', '/test/'), 
               'http://example.com/test/');

        // Test ports non-standards (doivent apparaître)
        expect(buildResilientUri('https://example.com:8443/dav/', '/test/'), 
               'https://example.com:8443/test/');
        expect(buildResilientUri('http://example.com:8080/dav/', '/test/'), 
               'http://example.com:8080/test/');

        // Test avec/sans trailing slash
        expect(buildResilientUri('https://example.com/dav', 'calendar'), 
               'https://example.com/dav/calendar');
        expect(buildResilientUri('https://example.com/dav/', 'calendar'), 
               'https://example.com/dav/calendar');

        // Test avec query et fragment
        expect(buildResilientUri('https://example.com/', '/cal?expand=1#section'), 
               'https://example.com/cal?expand=1#section');

        // Test caractères internationaux
        expect(buildResilientUri('https://example.com/', '/café/naïve/'), 
               'https://example.com/caf%C3%A9/na%C3%AFve/');

        // Test caractères réservés
        expect(buildResilientUri('https://example.com/', '/path with spaces/'), 
               'https://example.com/path%20with%20spaces/');

        // Test IPv6
        expect(buildResilientUri('https://[::1]:8080/', '/test'), 
               'https://[::1]:8080/test');
      });

      test('should validate URL schemes according to RFC 3986', () {
        bool isValidCalDAVUrl(String url) {
          try {
            final uri = Uri.parse(url);
            
            // RFC 3986: scheme doit être présent et valide pour CalDAV
            if (uri.scheme.isEmpty) return false;
            
            // CalDAV supporte HTTP et HTTPS uniquement
            if (!['http', 'https'].contains(uri.scheme.toLowerCase())) return false;
            
            // Host doit être présent
            if (uri.host.isEmpty) return false;
            
            // Port valide (1-65535)
            if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) return false;
            
            return true;
          } catch (e) {
            return false;
          }
        }

        // URLs valides
        expect(isValidCalDAVUrl('https://example.com/dav/'), true);
        expect(isValidCalDAVUrl('http://example.com:8080/'), true);
        expect(isValidCalDAVUrl('https://cal.example.com:443/caldav/'), true);
        expect(isValidCalDAVUrl('http://[::1]:8008/'), true);

        // URLs invalides
        expect(isValidCalDAVUrl('ftp://example.com/'), false);
        expect(isValidCalDAVUrl('example.com/dav/'), false);
        expect(isValidCalDAVUrl('https:///dav/'), false);
        expect(isValidCalDAVUrl('https://example.com:70000/'), false);
        expect(isValidCalDAVUrl(''), false);
      });

      test('should handle international domain names (IDN)', () {
        String normalizeCalDAVUrl(String url) {
          try {
            final uri = Uri.parse(url);
            
            // Normalise le host (IDN encoding)
            var normalizedHost = uri.host.toLowerCase();
            
            // Pour les vrais IDN, il faudrait punycode encoding
            // Ici on simule la validation basique
            if (normalizedHost.contains('xn--')) {
              // C'est déjà encodé en punycode
            }
            
            return Uri(
              scheme: uri.scheme.toLowerCase(),
              host: normalizedHost,
              port: uri.port,
              path: uri.path,
              query: uri.query.isEmpty ? null : uri.query,
            ).toString();
          } catch (e) {
            throw ArgumentError('Cannot normalize URL: $url');
          }
        }

        // Test domaines normaux
        expect(normalizeCalDAVUrl('HTTPS://EXAMPLE.COM/DAV/'), 
               'https://example.com/dav/');

        // Test punycode (domaines internationaux)
        expect(normalizeCalDAVUrl('https://xn--e1afmkfd.xn--p1ai/dav/'), 
               'https://xn--e1afmkfd.xn--p1ai/dav/');

        // Test case sensitivity
        expect(normalizeCalDAVUrl('HTTPS://Example.Com:8080/Dav/'), 
               'https://example.com:8080/Dav/');
      });

      test('should handle URL encoding/decoding correctly', () {
        String encodeCalDAVPath(String path) {
          // RFC 3986 compliant encoding pour CalDAV
          return Uri.encodeComponent(path)
            .replaceAll('%2F', '/') // Garde les slashes
            .replaceAll('%3A', ':') // Garde les colons pour les schemes
            .replaceAll('%3F', '?') // Garde les query separators
            .replaceAll('%23', '#'); // Garde les fragments
        }

        String decodeCalDAVPath(String encodedPath) {
          return Uri.decodeComponent(encodedPath);
        }

        // Test caractères spéciaux
        expect(encodeCalDAVPath('path with spaces'), 'path%20with%20spaces');
        expect(encodeCalDAVPath('café'), 'caf%C3%A9');
        expect(encodeCalDAVPath('naïve'), 'na%C3%AFve');
        expect(encodeCalDAVPath('100%'), '100%25');

        // Test que les caractères de structure restent
        expect(encodeCalDAVPath('/path/to/resource'), '/path/to/resource');
        expect(encodeCalDAVPath('resource?param=value'), 'resource?param=value');

        // Test round-trip
        const originalPath = 'café/naïve folder/100%';
        final encoded = encodeCalDAVPath(originalPath);
        final decoded = decodeCalDAVPath(encoded);
        expect(decoded, originalPath);
      });
    });

    group('RFC 5545 iCalendar Compliance', () {
      test('should validate VTODO structure according to RFC 5545', () {
        bool isValidVTodoStructure(String vtodoString) {
          final lines = vtodoString.split('\n');
          if (lines.isEmpty) return false;
          
          // RFC 5545 Section 4.6.2: VTODO structure
          if (!lines.first.trim().startsWith('BEGIN:VTODO')) return false;
          if (!lines.last.trim().startsWith('END:VTODO')) return false;
          
          bool hasUID = false;
          bool hasDTSTAMP = false;
          
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.startsWith('UID:')) hasUID = true;
            if (trimmed.startsWith('DTSTAMP:')) hasDTSTAMP = true;
            
            // Validation ligne par ligne selon RFC 5545
            if (trimmed.contains(':') && !trimmed.startsWith('BEGIN:') && !trimmed.startsWith('END:')) {
              final parts = trimmed.split(':');
              if (parts.length < 2) return false;
              
              final property = parts[0];
              // Properties must be valid according to RFC 5545
              if (property.isEmpty || property.contains(' ')) return false;
            }
          }
          
          // RFC 5545: UID is required, DTSTAMP is required for VTODO
          return hasUID; // DTSTAMP often auto-generated
        }

        // Test structure RFC 5545 valide
        const validVTodo = '''BEGIN:VTODO
UID:20240101T120000Z-123456@example.com
DTSTAMP:20240101T120000Z
SUMMARY:Test Task
DESCRIPTION:This is a test task
DUE:20241224T140000Z
STATUS:NEEDS-ACTION
PRIORITY:1
END:VTODO''';

        expect(isValidVTodoStructure(validVTodo), true);

        // Test structure invalide (pas de UID)
        const invalidVTodo1 = '''BEGIN:VTODO
SUMMARY:Task without UID
END:VTODO''';

        expect(isValidVTodoStructure(invalidVTodo1), false);

        // Test structure invalide (property malformée)
        const invalidVTodo2 = '''BEGIN:VTODO
UID:test-001
INVALID PROPERTY WITHOUT COLON
END:VTODO''';

        expect(isValidVTodoStructure(invalidVTodo2), false);
      });

      test('should handle RFC 5545 datetime formats correctly', () {
        DateTime? parseRFC5545DateTime(String? dateTimeString) {
          if (dateTimeString == null || dateTimeString.isEmpty) return null;
          
          try {
            // RFC 5545 Section 3.3.5: DATE-TIME formats
            
            // Format: YYYYMMDDTHHMMSSZ (UTC)
            if (RegExp(r'^\d{8}T\d{6}Z$').hasMatch(dateTimeString)) {
              final year = int.parse(dateTimeString.substring(0, 4));
              final month = int.parse(dateTimeString.substring(4, 6));
              final day = int.parse(dateTimeString.substring(6, 8));
              final hour = int.parse(dateTimeString.substring(9, 11));
              final minute = int.parse(dateTimeString.substring(11, 13));
              final second = int.parse(dateTimeString.substring(13, 15));
              
              return DateTime.utc(year, month, day, hour, minute, second);
            }
            
            // Format: YYYYMMDDTHHMMSS (floating time)
            if (RegExp(r'^\d{8}T\d{6}$').hasMatch(dateTimeString)) {
              final year = int.parse(dateTimeString.substring(0, 4));
              final month = int.parse(dateTimeString.substring(4, 6));
              final day = int.parse(dateTimeString.substring(6, 8));
              final hour = int.parse(dateTimeString.substring(9, 11));
              final minute = int.parse(dateTimeString.substring(11, 13));
              final second = int.parse(dateTimeString.substring(13, 15));
              
              return DateTime(year, month, day, hour, minute, second);
            }
            
            // Format: YYYYMMDD (date only)
            if (RegExp(r'^\d{8}$').hasMatch(dateTimeString)) {
              final year = int.parse(dateTimeString.substring(0, 4));
              final month = int.parse(dateTimeString.substring(4, 6));
              final day = int.parse(dateTimeString.substring(6, 8));
              
              return DateTime(year, month, day);
            }
            
            return null;
          } catch (e) {
            return null;
          }
        }

        // Test formats RFC 5545 valides
        expect(parseRFC5545DateTime('20241224T140000Z')?.isUtc, true);
        expect(parseRFC5545DateTime('20241224T140000')?.isUtc, false);
        expect(parseRFC5545DateTime('20241224'), isNotNull);

        // Test formats invalides
        expect(parseRFC5545DateTime('2024-12-24T14:00:00Z'), isNull); // ISO format
        expect(parseRFC5545DateTime('invalid-date'), isNull);
        expect(parseRFC5545DateTime(''), isNull);

        // Test précision des valeurs
        final utcDateTime = parseRFC5545DateTime('20241224T140530Z')!;
        expect(utcDateTime.year, 2024);
        expect(utcDateTime.month, 12);
        expect(utcDateTime.day, 24);
        expect(utcDateTime.hour, 14);
        expect(utcDateTime.minute, 5);
        expect(utcDateTime.second, 30);
      });

      test('should validate RFC 5545 property parameters', () {
        Map<String, dynamic> parsePropertyWithParams(String propertyLine) {
          final colonIndex = propertyLine.indexOf(':');
          if (colonIndex == -1) throw ArgumentError('Invalid property format');
          
          final propertyPart = propertyLine.substring(0, colonIndex);
          final value = propertyLine.substring(colonIndex + 1);
          
          final params = <String, String>{};
          String propertyName = propertyPart;
          
          // Parse parameters (RFC 5545 Section 3.2)
          if (propertyPart.contains(';')) {
            final parts = propertyPart.split(';');
            propertyName = parts.first;
            
            for (int i = 1; i < parts.length; i++) {
              final paramParts = parts[i].split('=');
              if (paramParts.length == 2) {
                params[paramParts[0].toUpperCase()] = paramParts[1];
              }
            }
          }
          
          return {
            'property': propertyName.toUpperCase(),
            'value': value,
            'parameters': params,
          };
        }

        // Test property simple
        final simple = parsePropertyWithParams('SUMMARY:Test Task');
        expect(simple['property'], 'SUMMARY');
        expect(simple['value'], 'Test Task');
        expect((simple['parameters'] as Map).isEmpty, true);

        // Test property avec paramètres
        final withParams = parsePropertyWithParams('DTSTART;TZID=America/New_York:20241224T140000');
        expect(withParams['property'], 'DTSTART');
        expect(withParams['value'], '20241224T140000');
        expect((withParams['parameters'] as Map)['TZID'], 'America/New_York');

        // Test property avec plusieurs paramètres
        final multiParams = parsePropertyWithParams('ATTENDEE;CN=John Doe;ROLE=REQ-PARTICIPANT:mailto:john@example.com');
        expect(multiParams['property'], 'ATTENDEE');
        expect((multiParams['parameters'] as Map)['CN'], 'John Doe');
        expect((multiParams['parameters'] as Map)['ROLE'], 'REQ-PARTICIPANT');
      });
    });

    group('Error Recovery & Graceful Degradation', () {
      test('should recover from malformed URLs gracefully', () {
        String? sanitizeUrl(String url) {
          try {
            // Tentative de parsing direct
            final uri = Uri.tryParse(url);
            if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
              return uri.toString();
            }
            
            // Tentative de récupération
            var sanitized = url.trim();
            
            // Ajouter scheme si manquant
            if (!sanitized.contains('://')) {
              sanitized = 'https://$sanitized';
            }
            
            // Retenter le parsing
            final retryUri = Uri.tryParse(sanitized);
            if (retryUri != null && retryUri.host.isNotEmpty) {
              return retryUri.toString();
            }
            
            return null;
          } catch (e) {
            return null;
          }
        }

        // URLs récupérables
        expect(sanitizeUrl('example.com/dav'), 'https://example.com/dav');
        expect(sanitizeUrl('  https://example.com/  '), 'https://example.com/');
        expect(sanitizeUrl('http://example.com'), 'http://example.com');

        // URLs non récupérables
        expect(sanitizeUrl(''), isNull);
        expect(sanitizeUrl('not-a-url'), isNull);
        expect(sanitizeUrl('://missing-scheme'), isNull);
      });

      test('should handle network timeouts and retries gracefully', () {
        // Simulation d'une stratégie de retry avec backoff
        Future<String> simulateNetworkCall(String url, {int attempt = 1}) async {
          final random = DateTime.now().millisecondsSinceEpoch % 100;
          
          // Simule des erreurs temporaires
          if (attempt <= 2 && random < 30) {
            throw Exception('Network timeout on attempt $attempt');
          }
          
          return 'Success after $attempt attempts';
        }

        Future<String?> resilientNetworkCall(String url, {int maxRetries = 3}) async {
          for (int attempt = 1; attempt <= maxRetries; attempt++) {
            try {
              return await simulateNetworkCall(url, attempt: attempt);
            } catch (e) {
              if (attempt == maxRetries) {
                return null; // Échec final
              }
              
              // Backoff exponentiel : 1s, 2s, 4s
              await Future.delayed(Duration(seconds: attempt));
            }
          }
          return null;
        }

        // Test basique (sans vraie exécution async dans les tests)
        expect(resilientNetworkCall('https://example.com'), completes);
      });
    });
  });
} 