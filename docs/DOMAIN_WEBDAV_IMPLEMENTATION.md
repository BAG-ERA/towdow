# Domain Implementation via WebDAV Properties

## Overview

FlowIt implements project domains using **WebDAV properties** on calendar collections, following RFC 4918 standards. This approach ensures compatibility with standard CalDAV servers while providing the organizational benefits of project grouping.

## Technical Architecture

### Protocol Details
- **Method**: PROPPATCH for updates, PROPFIND for discovery
- **Namespace**: `http://flowit.app/ns/` 
- **Property Name**: `domain`
- **Full Property**: `<FLOWIT:domain xmlns:FLOWIT="http://flowit.app/ns/">`

### Implementation Flow

#### 1. Domain Assignment
When a user assigns a domain to a project:
```
UI Action → DomainService.assignDomainToCalendar() → CalDAVService.updateCalendarProperties() → WebDAVClient.proppatch()
```

#### 2. Domain Discovery
During calendar discovery:
```
CapabilityDiscoveryService.discoverCalendars() → WebDAVClient.propfind() → Parse response for domain properties
```

## PROPPATCH Request Format

### Setting a Domain
```xml
<?xml version="1.0" encoding="utf-8"?>
<D:propertyupdate xmlns:D="DAV:" xmlns:FLOWIT="http://flowit.app/ns/">
  <D:set>
    <D:prop>
      <FLOWIT:domain>Marketing Campaigns</FLOWIT:domain>
    </D:prop>
  </D:set>
</D:propertyupdate>
```

### Removing a Domain
```xml
<?xml version="1.0" encoding="utf-8"?>
<D:propertyupdate xmlns:D="DAV:" xmlns:FLOWIT="http://flowit.app/ns/">
  <D:remove>
    <D:prop>
      <FLOWIT:domain/>
    </D:prop>
  </D:remove>
</D:propertyupdate>
```

## PROPFIND Discovery

### Request
```xml
<?xml version="1.0" encoding="utf-8"?>
<D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:FLOWIT="http://flowit.app/ns/">
  <D:prop>
    <D:resourcetype/>
    <D:displayname/>
    <C:supported-calendar-component-set/>
    <FLOWIT:domain/>
  </D:prop>
</D:propfind>
```

### Response
```xml
<D:multistatus xmlns:D="DAV:" xmlns:ns3="http://flowit.app/ns/">
  <D:response>
    <D:href>/calendars/user/project-calendar/</D:href>
    <D:propstat>
      <D:prop>
        <D:displayname>Marketing Campaign Q1</D:displayname>
        <ns3:domain>Marketing Campaigns</ns3:domain>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>
```

## Code Implementation

### CalDAV Service
```dart
Future<Result<void>> updateCalendarProperties(TaskCalendar calendar) async {
  final proppatchXml = _generateDomainPropPatch(calendar);
  final proppatchResult = await _client.proppatch(calendar.path, proppatchXml);
  // Handle response...
}
```

### Capability Discovery
```dart
String? _extractFlowItProperty(String xmlContent, String propertyName) {
  // Supports multiple namespace formats:
  // <ns3:domain>, <FLOWIT:domain>, <domain>
  final patterns = [
    RegExp(r'<[^:>]+:' + propertyName + r'[^>]*>(.*?)</[^:>]+:' + propertyName + r'>'),
    RegExp(r'<(?:FLOWIT:)?' + propertyName + r'[^>]*>(.*?)</(?:FLOWIT:)?' + propertyName + r'>'),
    RegExp(r'<' + propertyName + r'[^>]*>(.*?)</' + propertyName + r'>'),
  ];
  // Parse and return value...
}
```

## Server Compatibility

### Tested Servers
- ✅ **Radicale**: Full support, stores properties correctly
- ✅ **CalDAV.net**: Compatible with WebDAV properties
- ✅ **Nextcloud**: Supports custom properties

### Expected Responses
- **Success**: HTTP 207 Multi-Status or HTTP 200 OK
- **Property stored**: Returns in subsequent PROPFIND requests
- **Namespace handling**: Server preserves namespace, may alias (e.g., `ns3:`)

## Error Handling

### Non-Critical Failures
Domain sync failures are treated as **non-critical** to ensure core functionality remains available:
- UI updates immediately (optimistic updates)
- Local storage preserves domain assignments
- Background sync retries during next sync cycle
- User receives informative logging but no blocking errors

### Fallback Behavior
- If PROPPATCH fails → Domain stored locally only
- If PROPFIND doesn't return domain → Shows in "No Domain" section
- If server doesn't support custom properties → Graceful degradation

## Benefits of WebDAV Approach

1. **Standards Compliance**: Uses RFC 4918 WebDAV properties
2. **Server Agnostic**: Works with any CalDAV server supporting custom properties
3. **Efficient Storage**: Domain metadata stored at collection level, not duplicated per task
4. **Atomic Updates**: Single PROPPATCH request updates domain for entire project
5. **Discovery Integration**: Domains discovered during standard CalDAV collection enumeration

## Migration Considerations

- **Backward Compatibility**: Legacy projects without domains appear in "No Domain"
- **No Data Loss**: Failed domain sync doesn't affect core task/project data
- **Incremental Rollout**: Feature can be enabled per calendar without affecting others
- **Client Compatibility**: Non-FlowIt clients ignore custom properties gracefully 