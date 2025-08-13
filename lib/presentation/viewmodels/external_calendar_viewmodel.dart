// External calendar management ViewModel
// Encapsulates all IO with repositories/services for the external calendar feature

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logger.dart';
import '../../core/result.dart';
import '../../data/models/external_caldav_account.dart';
import '../../data/models/external_calendar.dart';
import '../../data/repositories/external_account_repository.dart';
import '../../data/repositories/external_calendar_repository.dart';
import '../../data/repositories/external_event_repository.dart';
import '../../data/services/integration/external_caldav_calendar/external_sync_service.dart';

class ExternalCalendarState {
  final bool isLoading;
  final String? error;

  const ExternalCalendarState({this.isLoading = false, this.error});

  ExternalCalendarState copyWith({bool? isLoading, String? error}) => ExternalCalendarState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class ExternalCalendarViewModel extends StateNotifier<ExternalCalendarState> {
  final ExternalAccountRepository _accountRepository;
  final ExternalCalendarRepository _calendarRepository;
  final ExternalEventRepository _eventRepository;
  final ExternalCalendarSyncService _syncService;

  ExternalCalendarViewModel(
    this._accountRepository,
    this._calendarRepository,
    this._eventRepository,
    this._syncService,
  ) : super(const ExternalCalendarState());

  // Streams for UI consumption
  Stream<List<ExternalCaldavAccount>> get accountsStream => _accountRepository.watchAccounts();

  Future<void> toggleAccount(ExternalCaldavAccount account) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _accountRepository.setActive(account.id, !account.isActive);
      result.when(
        success: (_) {},
        failure: (f) => state = state.copyWith(error: f.message),
      );
    } catch (e, st) {
      AppLogger.error('ExternalCalendarVM: toggleAccount failed', e, st);
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> syncAccount(String accountId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _syncService.syncAccount(accountId);
      result.when(
        success: (_) {},
        failure: (f) => state = state.copyWith(error: f.message),
      );
    } catch (e, st) {
      AppLogger.error('ExternalCalendarVM: syncAccount failed', e, st);
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> deleteAccount(ExternalCaldavAccount account) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final deleteEventsResult = await _eventRepository.deleteByAccount(account.id);
      if (deleteEventsResult is Error<void>) {
        throw Exception(deleteEventsResult.failure.message);
      }
      final deleteCalendarsResult = await _calendarRepository.deleteCalendarsByAccount(account.id);
      if (deleteCalendarsResult is Error<void>) {
        throw Exception(deleteCalendarsResult.failure.message);
      }
      final deleteAccountResult = await _accountRepository.delete(account.id);
      if (deleteAccountResult is Error<void>) {
        throw Exception(deleteAccountResult.failure.message);
      }
    } catch (e, st) {
      AppLogger.error('ExternalCalendarVM: deleteAccount failed', e, st);
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> toggleCalendar(ExternalCalendar calendar, bool enabled) async {
    try {
      final result = await _calendarRepository.setEnabled(calendar.id, enabled);
      result.when(success: (_) {}, failure: (f) => state = state.copyWith(error: f.message));
    } catch (e, st) {
      AppLogger.error('ExternalCalendarVM: toggleCalendar failed', e, st);
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateCalendarColor(ExternalCalendar calendar, String? color) async {
    try {
      final updated = calendar.copyWith(color: color, lastModified: DateTime.now());
      final result = await _calendarRepository.save(updated);
      result.when(success: (_) {}, failure: (f) => state = state.copyWith(error: f.message));
    } catch (e, st) {
      AppLogger.error('ExternalCalendarVM: updateCalendarColor failed', e, st);
      state = state.copyWith(error: e.toString());
    }
  }
}



