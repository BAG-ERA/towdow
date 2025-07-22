import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/logger.dart';
import '../../core/result.dart';
import '../../data/models/caldav_account.dart';
import '../../data/models/task_calendar.dart';
import '../../data/providers/providers.dart';

// ----- STATE -----
class ProjectCreationState {
  final bool isLoading;
  final String? error;
  final bool wasCreatedLocally;

  const ProjectCreationState({
    this.isLoading = false, 
    this.error,
    this.wasCreatedLocally = false,
  });

  ProjectCreationState copyWith({
    bool? isLoading, 
    String? error,
    bool? wasCreatedLocally,
  }) =>
      ProjectCreationState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        wasCreatedLocally: wasCreatedLocally ?? this.wasCreatedLocally,
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

      // Create calendar using CalDAV service
      final caldavService = _ref.read(caldavServiceProvider(account!));
      final createResult = await caldavService.createCalendar(
        displayName: name,
        description: description,
      );
      
      TaskCalendar? createdCalendar;
      bool wasCreatedLocally = false;
      
      createResult.when(
        success: (calendar) {
          AppLogger.info('ProjectCreationViewModel: Successfully created calendar');
          createdCalendar = calendar;
        },
        failure: (failure) {
          AppLogger.warning('ProjectCreationViewModel: Calendar creation failed: ${failure.message}');
          wasCreatedLocally = true;
          throw Exception('Failed to create calendar: ${failure.message}');
        },
      );

      if (createdCalendar == null) {
        throw Exception('Failed to create calendar');
      }

      // Assign domain if provided
      if (domain != null && domain.isNotEmpty) {
        final domainService = _ref.read(domainServiceProvider);
        final res = await domainService.assignDomainToCalendar(createdCalendar!.path, domain);
        res.when(
          success: (_) {
            AppLogger.info('ProjectCreationViewModel: Domain assigned successfully');
          },
          failure: (f) {
            AppLogger.warning('ProjectCreationViewModel: Domain assignment failed: ${f.message}');
            // Don't fail the whole operation for domain assignment
          },
        );
      }
      
      // Invalidate providers so UI refreshes
      _ref.invalidate(projectListProvider);
      _ref.invalidate(calendarListProvider);
      _ref.invalidate(activeCalendarListProvider);
      
      AppLogger.info('ProjectCreationViewModel: Project creation completed successfully');
      
      // Update state to indicate success
      state = state.copyWith(
        isLoading: false, 
        error: null,
        wasCreatedLocally: wasCreatedLocally,
      );
      
    } catch (e, st) {
      AppLogger.error('ProjectCreationViewModel: createProject exception', e, st);
      state = state.copyWith(
        isLoading: false, 
        error: e.toString(),
        wasCreatedLocally: false,
      );
    }
  }
}

// Provider
final projectCreationViewModelProvider = StateNotifierProvider<ProjectCreationViewModel, ProjectCreationState>(
  (ref) => ProjectCreationViewModel(ref),
); 