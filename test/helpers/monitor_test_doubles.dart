// Test doubles and helpers for CalDAV monitoring-related tests
// - Provides fakes for S3 and CalDAV services
// - Exposes a way to obtain a usable `Ref` from a ProviderContainer
// - Includes fixtures for `CaldavAccount` with different provider types


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:towdow_app/core/result.dart';
import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/data/models/task.dart';
import 'package:towdow_app/data/providers/providers_services_caldav.dart';
import 'package:towdow_app/data/providers/providers_services_core.dart';
import 'package:towdow_app/data/services/caldav/caldav_service.dart' as caldav_impl;
import 'package:towdow_app/data/services/storage/s3_storage_service.dart';

/// Provider that returns the current [Ref]. Useful to get a `Ref` from a
/// [ProviderContainer] in tests without spinning up widgets.
final capturedRefProvider = Provider<Ref>((ref) => ref);

/// Build a [ProviderContainer] with overrides for CalDAV and S3 services, and
/// return both the container and a captured [Ref] usable by services that accept
/// an optional `Ref` (like `CalDAVMonitor`).
({ProviderContainer container, Ref ref}) createContainerWithServiceFakes({
  required CaldavAccount account,
  required caldav_impl.ICalDAVService caldavFake,
  required S3StorageService s3Fake,
}) {
  final container = ProviderContainer(
    overrides: [
      // Override the specific family instances for the provided account
      caldavServiceProvider(account).overrideWithValue(caldavFake),
      s3StorageServiceProvider(account).overrideWithValue(s3Fake),
    ],
  );
  final ref = container.read(capturedRefProvider);
  return (container: container, ref: ref);
}

/// Simple in-memory fake for S3 service used by tests to avoid network/S3 IO.
class FakeS3StorageService extends S3StorageService {
  final Map<String, S3FileInfo> _filesByKey;
  final String _userPrefix;

  FakeS3StorageService({
    required CaldavAccount account,
    Map<String, S3FileInfo>? files,
    String userPrefix = 'user/',
  })  : _filesByKey = Map.of(files ?? <String, S3FileInfo>{}),
        _userPrefix = userPrefix,
        super(account: account);

  @override
  String getUserPrefix() => _userPrefix;

  @override
  Future<Result<S3FileInfo>> getFileInfo({
    required String key,
    required bool isPrivate,
  }) async {
    final info = _filesByKey[key];
    if (info == null) {
      return Result.failure(Failure(message: 'NoSuchKey'));
    }
    return Result.success(info);
  }

  @override
  Future<Result<String?>> getCurrentEtag({
    required String key,
    required bool isPrivate,
  }) async {
    final info = _filesByKey[key];
    return Result.success(info?.etag);
  }

  // Convenience helpers for tests
  void setFile({
    required String key,
    required String bucket,
    required String etag,
    required int size,
    required DateTime lastModified,
    String? contentType,
  }) {
    _filesByKey[key] = S3FileInfo(
      key: key,
      bucket: bucket,
      size: size,
      lastModified: lastModified,
      etag: etag,
      contentType: contentType,
    );
  }

  void clearFiles() => _filesByKey.clear();
}

/// Minimal fake CalDAV service for discovery-only paths used by monitoring.
class FakeCalDAVService implements caldav_impl.ICalDAVService {
  @override
  final CaldavAccount account;

  final List<TaskCalendar> _availableCalendars;

  FakeCalDAVService({
    required this.account,
    List<TaskCalendar>? availableCalendars,
  }) : _availableCalendars = List.of(availableCalendars ?? const <TaskCalendar>[]);

  @override
  Future<Result<caldav_impl.CalDAVCapabilities>> testConnection() async {
    return Result.success(
      caldav_impl.CalDAVCapabilities(
        supportsCalDAV: true,
        supportsTasks: true,
        principal: '/principals/users/${account.username}/',
        calendarHome: '/calendars/${account.username}/',
        taskCalendars: _availableCalendars,
        serverInfo: 'fake',
      ),
    );
  }

  // Unused in monitor paths; keep simple failure to surface accidental usage
  @override
  Future<Result<String>> createTask(task, String calendarPath) async =>
      Result.failure(Failure(message: 'Not implemented in FakeCalDAVService'));
  @override
  Future<Result<void>> updateTask(task, String taskUrl, {String? etag}) async =>
      Result.failure(Failure(message: 'Not implemented in FakeCalDAVService'));
  @override
  Future<Result<void>> deleteTask(String taskUrl, {String? etag}) async =>
      Result.failure(Failure(message: 'Not implemented in FakeCalDAVService'));
  @override
  Future<Result<List<Task>>> fetchTasks({required String calendarPath}) async =>
      Result.failure(Failure(message: 'Not implemented in FakeCalDAVService'));
  @override
  Future<Result<void>> deleteCalendar(String calendarPath) async =>
      Result.failure(Failure(message: 'Not implemented in FakeCalDAVService'));
  @override
  Future<Result<TaskCalendar>> getCalendarProperties(TaskCalendar calendar) async =>
      Result.failure(Failure(message: 'Not implemented in FakeCalDAVService'));
  @override
  Future<Result<TaskCalendar>> createCalendar({
    required String displayName,
    String? description,
    String? domain,
    String? kanban,
    String? categ,
    String? author,
    String? owner,
    bool asWorkflow = false,
  }) async => Result.failure(Failure(message: 'Not implemented in FakeCalDAVService'));
  @override
  Future<Result<void>> updateCalendarProperties(TaskCalendar calendar) async =>
      Result.failure(Failure(message: 'Not implemented in FakeCalDAVService'));
}

/// Account fixtures
CaldavAccount buildCustomAccount({
  String id = 'acc-custom',
  String username = 'user',
  String serverUrl = 'https://example.test',
}) {
  final now = DateTime(2024, 1, 1);
  return CaldavAccount(
    id: id,
    providerType: 'custom',
    serverUrl: serverUrl,
    username: username,
    createdAt: now,
    lastSyncAt: now,
  );
}

CaldavAccount buildTowdowCloudAccount({
  String id = 'acc-cloud',
  String username = 'user',
  String serverUrl = 'https://api.towdow.app',
  String accessToken = 'header.payload.signature',
}) {
  final now = DateTime(2024, 1, 1);
  return CaldavAccount(
    id: id,
    providerType: 'towdow_cloud',
    serverUrl: serverUrl,
    username: username,
    accessToken: accessToken,
    createdAt: now,
    lastSyncAt: now,
  );
}


