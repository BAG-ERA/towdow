// Provides a thin SyncCommander that avoids provider cycles by delegating
// to the SyncService singleton internally. This lets repositories/services
// receive a commander via DI without depending on the heavy SyncService provider.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/calendar_repository.dart' show SyncCommander;
import 'sync_service.dart';
import '../../../core/result.dart';

class FallbackSyncCommander implements SyncCommander {
  SyncService? get _svc => SyncService.instance;

  @override
  Future<Result<void>> queueCalendarUpdate(String calendarPath) async {
    final svc = _svc;
    if (svc == null) {
      return const Result.failure(Failure(message: 'SyncService not initialized'));
    }
    return svc.queueCalendarUpdate(calendarPath);
  }

  @override
  Future<Result<void>> queueCalendarDeletion(String calendarPath) async {
    final svc = _svc;
    if (svc == null) {
      return const Result.failure(Failure(message: 'SyncService not initialized'));
    }
    return svc.queueCalendarDeletion(calendarPath);
  }

  @override
  Future<Result<void>> queueExitShare(String calendarPath) async {
    final svc = _svc;
    if (svc == null) {
      return const Result.failure(Failure(message: 'SyncService not initialized'));
    }
    return svc.queueExitShare(calendarPath);
  }

  @override
  Future<Result<void>> queueCalendarCreation(String calendarPath) async {
    final svc = _svc;
    if (svc == null) {
      return const Result.failure(Failure(message: 'SyncService not initialized'));
    }
    return svc.queueCalendarCreation(calendarPath);
  }
}

final syncCommanderProvider = Provider<SyncCommander>((ref) {
  return FallbackSyncCommander();
});


