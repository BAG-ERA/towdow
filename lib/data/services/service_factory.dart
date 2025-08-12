// ServiceFactory centralizes creation for CalDAV-related services for DI/mocking.

import '../models/caldav_account.dart';
import 'caldav/caldav_task_service.dart';
import 'caldav/caldav_calendar_service.dart';
import 'caldav/caldav_properties_service.dart';
import 'webdav_client.dart';

typedef TaskServiceFactory = CalDavTaskService Function(CaldavAccount account);
typedef CalendarServiceFactory = CalDavCalendarService Function(CaldavAccount account);
typedef PropertiesServiceFactory = CalDavPropertiesService Function(CaldavAccount account);

class ServiceFactory {
  static TaskServiceFactory taskServiceFactory = (account) => CalDavTaskService(account: account);
  static CalendarServiceFactory calendarServiceFactory = (account) => CalDavCalendarService(account: account);
  static PropertiesServiceFactory propertiesServiceFactory = (account) => CalDavPropertiesService(client: WebDAVClient.fromAccount(account));
}



