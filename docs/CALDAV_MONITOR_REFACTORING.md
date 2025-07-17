# CalDAV Monitor Refactoring

## Overview

The `CalDAVMonitor` is a refactored version of the `BackgroundSyncService` that focuses specifically on **change detection** rather than performing actual synchronization. It monitors calendars for changes using sync tokens and ETags, then delegates actual sync operations to the `SyncService`.

## Architecture

### **Core Responsibilities**
1. **Change Detection**: Monitor sync tokens and ETags for all calendars
2. **Queue Processing**: Process queued operations when connection is available
3. **Dynamic Interval Management**: Adjust monitoring frequency based on change activity
4. **Delegation**: Delegate actual sync operations to `SyncService`

### **Key Dependencies**
- `AccountRepository`: Get active CalDAV account
- `CalendarRepository`: Access local calendar data
- `ConnectionMonitorService`: Check network connectivity
- `SyncService`: Delegate sync operations
- `WebDAVClient`: Make CalDAV requests

### **Minimal Dependencies**
Unlike the old `BackgroundSyncService`, the `CalDAVMonitor` has a focused set of dependencies:
- ❌ No direct task management
- ❌ No file handling
- ❌ No complex sync logic
- ✅ Only calendar-focused monitoring

## Dynamic Interval Management

### **Configuration**
```dart
static const Duration _minInterval = Duration(seconds: 2);
static const Duration _maxInterval = Duration(seconds: 40);
static const Duration _initialInterval = Duration(seconds: 10);
static const double _changeMultiplier = 0.5; // Divide by 2 when change detected
static const double _noChangeMultiplier = 1.5; // Multiply by 1.5 when no change
```

### **Behavior**
- **Changes Detected**: Interval decreases (more frequent monitoring)
- **No Changes**: Interval increases (less frequent monitoring)
- **Bounds**: Always between 2-40 seconds
- **Adaptive**: Responds to activity patterns

## Change Detection Logic

### **1. Queue Processing**
```dart
// Process queued operations first
final queueChanges = await _processQueuedOperations();
if (queueChanges) {
  changesDetected = true;
}
```

### **2. Sync Token Comparison**
```dart
if (localSyncToken != serverSyncToken) {
  // Sync tokens differ - delegate to SyncService
  await _syncService.syncNow();
  return true;
}
```

### **3. ETag Comparison**
```dart
if (localEtag != serverEtag) {
  // ETags differ - resync calendar information
  await _resyncCalendarInfo(account, calendar);
  return true;
}
```

## Expected Failures and Handling

### **Connection-Related Failures**

#### **No Internet Connection**
- **Detection**: `ConnectionMonitorService.currentStatus != ConnectionStatus.connected`
- **Action**: Warning logged, monitoring skipped
- **Recovery**: Automatic retry on next interval
- **Log Level**: Warning

#### **Network Timeout**
- **Detection**: WebDAV request timeout
- **Action**: Error logged, operation continues with next calendar
- **Recovery**: Automatic retry on next interval
- **Log Level**: Error

#### **Server Unreachable**
- **Detection**: HTTP connection failure
- **Action**: Warning logged, specific calendar skipped
- **Recovery**: Automatic retry on next interval
- **Log Level**: Warning

### **Authentication Failures**

#### **Invalid Credentials**
- **Detection**: HTTP 401/403 responses
- **Action**: Error logged, monitoring continues
- **Recovery**: Requires user intervention
- **Log Level**: Error

#### **Token Expired**
- **Detection**: HTTP 401 responses with token expiry
- **Action**: Error logged, monitoring continues
- **Recovery**: Requires re-authentication
- **Log Level**: Error

#### **Account Not Found**
- **Detection**: No active account in repository
- **Action**: Debug logged, monitoring skipped
- **Recovery**: Automatic when account becomes available
- **Log Level**: Debug

### **CalDAV Protocol Failures**

#### **PROPFIND Failed**
- **Detection**: HTTP status != 207
- **Action**: Warning logged, specific calendar skipped
- **Recovery**: Automatic retry on next interval
- **Log Level**: Warning

#### **Invalid XML Response**
- **Detection**: XML parsing exception
- **Action**: Error logged, parsing fails gracefully
- **Recovery**: Automatic retry on next interval
- **Log Level**: Error

#### **Missing Sync Token**
- **Detection**: No sync-token element in response
- **Action**: Warning logged, treated as no change
- **Recovery**: Automatic retry on next interval
- **Log Level**: Warning

#### **Missing ETag**
- **Detection**: No getetag element in response
- **Action**: Warning logged, treated as no change
- **Recovery**: Automatic retry on next interval
- **Log Level**: Warning

### **Data Processing Failures**

#### **Calendar Repository Error**
- **Detection**: Repository operation failure
- **Action**: Error logged, monitoring continues
- **Recovery**: Automatic retry on next interval
- **Log Level**: Error

#### **Sync Service Error**
- **Detection**: SyncService operation failure
- **Action**: Warning logged, operation continues
- **Recovery**: Automatic retry on next interval
- **Log Level**: Warning

#### **XML Parsing Error**
- **Detection**: XML parsing exception
- **Action**: Error logged, specific operation fails
- **Recovery**: Automatic retry on next interval
- **Log Level**: Error

### **System Failures**

#### **Timer Creation Failed**
- **Detection**: Timer.periodic throws exception
- **Action**: Error logged, monitoring stops
- **Recovery**: Requires manual restart
- **Log Level**: Error

#### **Memory Issues**
- **Detection**: OutOfMemoryException
- **Action**: Error logged, monitoring stops
- **Recovery**: Requires app restart
- **Log Level**: Error

#### **Unexpected Exceptions**
- **Detection**: Any unhandled exception
- **Action**: Error logged, monitoring continues
- **Recovery**: Automatic retry on next interval
- **Log Level**: Error

## Logging Strategy

### **Log Levels**
- **Debug**: Normal operation, change detection results
- **Warning**: Expected failures (no connection, missing tokens)
- **Error**: Unexpected failures, system errors

### **Log Messages**
```dart
// Debug messages
AppLogger.debug('CalDAVMonitor: Changes detected for calendar ${calendar.displayName}');
AppLogger.debug('CalDAVMonitor: No changes detected, interval adjusted to ${_currentInterval.inSeconds}s');

// Warning messages
AppLogger.warning('CalDAVMonitor: No internet connection, skipping change monitoring');
AppLogger.warning('CalDAVMonitor: Could not get server sync token for ${calendar.displayName}: ${failure.message}');

// Error messages
AppLogger.error('CalDAVMonitor: Failed to start monitoring', e, stackTrace);
AppLogger.error('CalDAVMonitor: Change monitoring failed', e, stackTrace);
```

## Testing Strategy

### **Unit Tests**
- **Initialization**: Start/stop functionality
- **Connection Monitoring**: Network status handling
- **Queue Processing**: Queued operation handling
- **Dynamic Interval**: Interval adjustment logic
- **Error Handling**: Graceful failure handling
- **Resource Management**: Proper cleanup

### **Integration Tests**
- **End-to-End**: Full monitoring cycle
- **Network Simulation**: Connection loss/recovery
- **Server Interaction**: Real CalDAV server communication

## Migration from BackgroundSyncService

### **Removed Functionality**
- ❌ Direct task synchronization
- ❌ File upload handling
- ❌ Complex sync state management
- ❌ Progress reporting streams

### **Preserved Functionality**
- ✅ Queue processing (delegated to SyncService)
- ✅ Connection monitoring
- ✅ Periodic execution
- ✅ Error handling

### **New Functionality**
- ✅ Focused calendar monitoring
- ✅ Dynamic interval adjustment
- ✅ Sync token comparison
- ✅ ETag comparison
- ✅ Delegation to SyncService

## Future Enhancements

### **Completed Improvements**
1. ✅ **Centralized CalDAV Operations**: CalDAVService provides `getCalendarProperties()` method
2. ✅ **Unified Property Fetching**: Both CalDAVMonitor and SyncService use CalDAVService
3. ✅ **Efficient Single Request**: Single PROPFIND request for both sync token and ETag
4. ✅ **Direct XML Parser Usage**: Calls `XMLResponseParser` methods directly without wrapper methods
5. ✅ **Resync Method**: Added `resyncCalendarInfo` to CalDAVService with full property support
6. ✅ **Custom Namespace Support**: Handles all FlowIt custom properties (domain, type, asflow, etc.)
7. ✅ **Comprehensive Testing**: Added unit tests for all new functionality
8. ✅ **Error Handling**: Robust error handling for all failure scenarios

### **Planned Improvements**
1. **Metrics**: Add monitoring metrics and analytics
2. **Configuration**: Make intervals configurable per environment
3. **Performance Optimization**: Add caching and batch processing
4. **Integration Testing**: Test with real CalDAV servers

### **Performance Optimizations**
1. **Batch Processing**: Process multiple calendars in parallel
2. **Caching**: Cache sync tokens and ETags
3. **Selective Monitoring**: Only monitor active calendars
4. **Smart Intervals**: Use machine learning for interval prediction 