// CalDavDiscoveryService wraps discovery operations and exposes a stable
// CalDAVCapabilities object used by the rest of the app.

import '../../../core/logger.dart';
import '../../../core/result.dart';
import '../../models/caldav_account.dart';
import '../../models/task_calendar.dart';
import 'capability_discovery_service.dart';

class CalDAVCapabilities {
  final bool supportsCalDAV;
  final bool supportsTasks;
  final String principal;
  final String calendarHome;
  final List<TaskCalendar> taskCalendars;
  final String serverInfo;

  const CalDAVCapabilities({
    required this.supportsCalDAV,
    required this.supportsTasks,
    required this.principal,
    required this.calendarHome,
    required this.taskCalendars,
    required this.serverInfo,
  });
}

class CalDavDiscoveryService {
  final CaldavAccount account;

  CalDavDiscoveryService({required this.account});

  /// High-level test that runs capability discovery and returns normalized capabilities
  Future<Result<CalDAVCapabilities>> testConnection() async {
    try {
      final discovery = CapabilityDiscoveryService(account: account);
      final result = await discovery.discoverCapabilities();
      return result.when(
        success: (details) => Result.success(CalDAVCapabilities(
          supportsCalDAV: details.capabilities.supportsCalDAV,
          supportsTasks: true,
          principal: details.capabilities.principal ?? '/principals/users/${account.username}/',
          calendarHome: details.capabilities.calendarHome ?? '/calendars/${account.username}/',
          taskCalendars: details.availableCalendars,
          serverInfo: details.capabilities.serverInfo,
        )),
        failure: (f) {
          AppLogger.error('CalDavDiscoveryService: testConnection failed', f.exception, f.stackTrace);
          return Result.failure(f);
        },
      );
    } catch (e, st) {
      AppLogger.error('CalDavDiscoveryService: Exception during testConnection', e, st);
      return Result.failure(Failure(message: 'Discovery error: $e'));
    }
  }
}


