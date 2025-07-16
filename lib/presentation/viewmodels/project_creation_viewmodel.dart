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
import '../../data/services/capability_discovery_service.dart';

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

      final uid = 'project-${DateTime.now().millisecondsSinceEpoch}-${name.hashCode}';
      TaskCalendar? createdCalendar;

      // Try to create on server first
      final caldavService = _ref.read(caldavServiceProvider(account!));
      final createResult = await caldavService.createCalendar(
        displayName: name,
        description: description,
        uid: uid,
      );

      bool wasCreatedLocally = false;
      await createResult.when(
        success: (calendar) async {
          AppLogger.info('ProjectCreationViewModel: Successfully created calendar on server');
          createdCalendar = calendar;
        },
        failure: (failure) async {
          AppLogger.warning('ProjectCreationViewModel: Server creation failed, creating locally: ${failure.message}');
          wasCreatedLocally = true;
          
          // Create local calendar using the same path structure the server would use
          // First try to discover the calendar home to match server structure exactly
          String localPath;
          try {
            final discoveryService = CapabilityDiscoveryService(account: account!);
            final discoveryResult = await discoveryService.discoverCapabilities();
            
            final calendarHome = await discoveryResult.when(
              success: (discoveryResult) async => discoveryResult.capabilities.calendarHome,
              failure: (_) async => '/calendars/${account!.username}/', // Fallback
            );
            
            localPath = '$calendarHome$uid/';
            AppLogger.info('ProjectCreationViewModel: Using discovered calendar home for local calendar: $localPath');
          } catch (e) {
            // If discovery fails, use server-compatible fallback
            localPath = '/calendars/${account!.username}/$uid/';
            AppLogger.warning('ProjectCreationViewModel: Discovery failed, using fallback local path: $localPath');
          }
          
          createdCalendar = TaskCalendarFactory.createNew(
            path: localPath,
            displayName: name,
            description: description,
          );
        },
      );

      if (createdCalendar == null) {
        throw Exception('Failed to create calendar both on server and locally');
      }

      // Save calendar locally
      final calendarRepo = _ref.read(calendarRepositoryProvider);
      final saveRes = await calendarRepo.save(createdCalendar!);
      await saveRes.when(
        success: (_) async {
          AppLogger.info('ProjectCreationViewModel: Calendar saved locally successfully');
          
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
        },
        failure: (f) => throw Exception('Save calendar failed: ${f.message}'),
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