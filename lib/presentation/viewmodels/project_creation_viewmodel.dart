import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger.dart';
import '../../data/models/caldav_account.dart';
import '../../data/models/task_calendar.dart';
import '../../data/providers/providers.dart';

// ----- STATE -----
class ProjectCreationState {
  final bool isLoading;
  final String? error;
  final bool wasCreatedLocally;
  final String? createdProjectPath; // Add this to track the created project path

  const ProjectCreationState({
    this.isLoading = false, 
    this.error,
    this.wasCreatedLocally = false,
    this.createdProjectPath, // Add this parameter
  });

  ProjectCreationState copyWith({
    bool? isLoading, 
    String? error,
    bool? wasCreatedLocally,
    String? createdProjectPath, // Add this parameter
  }) =>
      ProjectCreationState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        wasCreatedLocally: wasCreatedLocally ?? this.wasCreatedLocally,
        createdProjectPath: createdProjectPath ?? this.createdProjectPath, // Add this line
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
    state = state.copyWith(isLoading: true, error: null, createdProjectPath: null);

    try {
      // Get active account
      final accountRepository = _ref.read(accountRepositoryProvider);
      final accountResult = await accountRepository.getActiveAccount();
      CaldavAccount? account;
      accountResult.when(
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

      // Save the created calendar to repository to add it to sync list
      final calendarRepository = _ref.read(calendarRepositoryProvider);
      final saveResult = await calendarRepository.save(createdCalendar!);
      saveResult.when(
        success: (_) {
          AppLogger.info('ProjectCreationViewModel: Calendar saved to repository successfully');
        },
        failure: (failure) {
          AppLogger.warning('ProjectCreationViewModel: Failed to save calendar to repository: ${failure.message}');
          // Don't fail the whole operation for repository save failure
        },
      );

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
      
      
      // Also refresh the project list view model to ensure it picks up the new project
      final projectListViewModel = _ref.read(projectListViewModelProvider.notifier);
      await projectListViewModel.refresh();
      
      AppLogger.info('ProjectCreationViewModel: Project created successfully');
      
      // Update state to indicate success and store the created project path
      state = state.copyWith(
        isLoading: false, 
        error: null,
        wasCreatedLocally: wasCreatedLocally,
        createdProjectPath: createdCalendar!.path,
      );
      
    } catch (e, st) {
      AppLogger.error('ProjectCreationViewModel: createProject exception', e, st);
      state = state.copyWith(
        isLoading: false, 
        error: e.toString(),
        wasCreatedLocally: false,
        createdProjectPath: null, // Clear project path on error
      );
    }
  }
}

// Provider
final projectCreationViewModelProvider = StateNotifierProvider<ProjectCreationViewModel, ProjectCreationState>(
  (ref) => ProjectCreationViewModel(ref),
); 