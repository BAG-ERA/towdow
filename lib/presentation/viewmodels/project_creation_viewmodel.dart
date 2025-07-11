import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger.dart';
import '../../core/result.dart';
import '../../data/models/caldav_account.dart';
import '../../data/models/task_calendar.dart';
import '../../data/services/caldav_service.dart';
import '../../data/services/domain_service.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/providers/providers.dart';

// ----- STATE -----
class ProjectCreationState {
  final bool isLoading;
  final String? error;

  const ProjectCreationState({this.isLoading = false, this.error});

  ProjectCreationState copyWith({bool? isLoading, String? error}) =>
      ProjectCreationState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ----- VIEWMODEL -----
class ProjectCreationViewModel extends StateNotifier<ProjectCreationState> {
  final Ref _ref;
  ProjectCreationViewModel(this._ref) : super(const ProjectCreationState());

  Future<void> createProject({
    required String name,
    required String description,
    String? domain,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get active account
      final accountRepository = _ref.read(accountRepositoryProvider);
      final accountResult = await accountRepository.getActiveAccount();
      CaldavAccount? account;
      await accountResult.when(
        success: (acc) => account = acc,
        failure: (f) => throw Exception('No account: ${f.message}'),
      );
      if (account == null) {
        throw Exception('No active CalDAV account found');
      }

      // Generate UID and unique calendar path handled by CalDAVService
      final caldavService = _ref.read(caldavServiceProvider(account!));

      final uid = 'project-${DateTime.now().millisecondsSinceEpoch}-${name.hashCode}';

      final createResult = await caldavService.createCalendar(
        displayName: name,
        description: description,
        uid: uid,
      );

      await createResult.when(
        success: (calendar) async {
          // Save calendar locally
          final calendarRepo = _ref.read(calendarRepositoryProvider);
          final saveRes = await calendarRepo.save(calendar);
          await saveRes.when(
            success: (_) async {
              // Assign domain if provided
              if (domain != null && domain.isNotEmpty) {
                final domainService = _ref.read(domainServiceProvider);
                final res = await domainService.assignDomainToCalendar(calendar.uid, domain);
                res.when(
                  success: (_) {},
                  failure: (f) => throw Exception('Domain assign failed: ${f.message}'),
                );
              }
              // Invalidate providers so UI refreshes
              _ref.invalidate(projectListProvider);
              _ref.invalidate(calendarListProvider);
              _ref.invalidate(activeCalendarListProvider);
            },
            failure: (f) => throw Exception('Save calendar failed: ${f.message}'),
          );
        },
        failure: (f) => throw Exception('Create calendar failed: ${f.message}'),
      );
    } catch (e, st) {
      AppLogger.error('ProjectCreationViewModel: createProject exception', e, st);
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

// Provider
final projectCreationViewModelProvider = StateNotifierProvider<ProjectCreationViewModel, ProjectCreationState>(
  (ref) => ProjectCreationViewModel(ref),
); 