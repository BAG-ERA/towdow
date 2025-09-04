// CalDAV and integration service providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../models/caldav_account.dart';
import '../models/external_caldav_account.dart';
import '../services/caldav/caldav_discovery_service.dart';
import '../services/caldav/caldav_service.dart' as caldav_impl;
import '../services/integration/external_caldav_calendar/external_caldav_service.dart';
import '../services/share/sharing_sync_service.dart';
// Capabilities type is declared in caldav discovery service file; no extra import needed

final caldavDiscoveryServiceProvider = Provider.family<CalDavDiscoveryService, CaldavAccount>((ref, account) {
  return CalDavDiscoveryService(account: account);
});

final caldavServiceProvider = Provider.family<caldav_impl.ICalDAVService, CaldavAccount>((ref, account) {
  // Avoid cross-module provider coupling here; inject default sharing sync
  return caldav_impl.CalDAVService(account: account, sharingSyncService: const SharingSyncService());
});

// Server capabilities provider for account setup
final serverCapabilitiesProvider = FutureProvider.family.autoDispose<CalDAVCapabilities, CaldavAccount>((ref, account) async {
  final discovery = ref.watch(caldavDiscoveryServiceProvider(account));
  final result = await discovery.testConnection();
  return result.when(
    success: (capabilities) => capabilities,
    failure: (failure) => throw Exception(failure.message),
  );
});

final externalCalDAVServiceProvider = Provider.family<ExternalCalDAVService, ExternalCaldavAccount>((ref, account) {
  return ExternalCalDAVService(account: account);
});


