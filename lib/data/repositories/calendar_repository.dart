// Calendar repository interface and local implementation
// Follows repository pattern for calendar/project data access
// Calendars represent projects at VCALENDAR level according to FlowIt specs

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/task_calendar.dart';
import '../models/shared_with_me_project.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';
import '../services/caldav_service.dart';
import '../services/share_service.dart';
import '../services/share_service.dart';
import 'account_repository.dart';
import 'user_repository.dart';
import 'user_repository.dart';

// Abstract repository interface
abstract class CalendarRepository {
  Future<Result<List<TaskCalendar>>> getAll();
  Future<Result<TaskCalendar?>> getById(String uid);
  Future<Result<TaskCalendar?>> getByPath(String path);
  Future<Result<void>> save(TaskCalendar calendar);
  Future<Result<void>> delete(String uid);
  Future<Result<void>> deleteSharedProject(String uid, String fullPath);
  Stream<List<TaskCalendar>> watchCalendars();
  Future<Result<List<TaskCalendar>>> getProjectCalendars();
  
  // Domain-related methods
  Future<Result<List<TaskCalendar>>> getCalendarsByDomain(String? domain);
  Future<Result<List<String>>> getUniqueDomains();
  Future<Result<void>> renameDomain(String oldDomain, String newDomain);
  Future<Result<Map<String, int>>> getDomainStatistics();
  Future<Result<List<TaskCalendar>>> getCalendarsWithoutDomain();
  
  // Status-related methods
  Future<Result<List<TaskCalendar>>> getCalendarsByStatus(String? status);
  Future<Result<List<String>>> getUniqueStatuses();
  Future<Result<void>> changeStatus(String oldStatus, String newStatus);
  Future<Result<Map<String, int>>> getStatusStatistics();
  Future<Result<List<TaskCalendar>>> getCalendarsWithoutStatus();
  Future<Result<List<TaskCalendar>>> getArchivedCalendars();
  Future<Result<List<TaskCalendar>>> getActiveCalendars();
  
  // Sync-related methods
  Future<Result<void>> updateCalendarProperties(TaskCalendar calendar);
  
  // Domain-related methods with sync
  Future<Result<void>> assignDomainToCalendar(String calendarUid, String? domain);
}

// Local implementation using Hive
class LocalCalendarRepository implements CalendarRepository {
  final LocalStorageService _storageService;
  final AccountRepository _accountRepository;
  final UserRepository _userRepository;

  LocalCalendarRepository(this._storageService, this._accountRepository, this._userRepository);

  /// Check if a project is shared with me by looking up in user preferences
  Future<bool> _isSharedWithMe(String uid) async {
    final userPreferencesResult = await _userRepository.getUserPreferences();
    return userPreferencesResult.when(
      success: (preferences) {
        // Find shared project by extracting UID from project paths
        for (final shared in preferences.sharedWithMeProjects) {
          final segments = shared.projectId.split('/').where((s) => s.isNotEmpty).toList();
          final sharedProjectUid = segments.isNotEmpty ? segments.last : shared.projectId;
          if (sharedProjectUid == uid) {
            return true;
          }
        }
        return false;
      },
      failure: (_) => false,
    );
  }

  /// Remove a project from the shared with me projects list
  Future<void> _removeFromSharedProjects(String uid) async {
    final userPreferencesResult = await _userRepository.getUserPreferences();
    await userPreferencesResult.when(
      success: (preferences) async {
        final updatedPreferences = preferences.copyWith(
          sharedWithMeProjects: preferences.sharedWithMeProjects
              .where((project) {
                // Compare UIDs extracted from paths
                final segments = project.projectId.split('/').where((s) => s.isNotEmpty).toList();
                final projectUid = segments.isNotEmpty ? segments.last : project.projectId;
                return projectUid != uid;
              })
              .toList(),
        );
        
        final saveResult = await _userRepository.saveUserPreferences(updatedPreferences);
        saveResult.when(
          success: (_) {
            AppLogger.info('LocalCalendarRepository: Successfully removed shared project from preferences: $uid');
          },
          failure: (failure) {
            AppLogger.warning('LocalCalendarRepository: Failed to update user preferences after exit share: ${failure.message}');
          },
        );
      },
      failure: (failure) async {
        AppLogger.warning('LocalCalendarRepository: Failed to get user preferences for shared project removal: ${failure.message}');
      },
    );
  }

  @override
  Future<Result<List<TaskCalendar>>> getAll() async {
    final result = await _storageService.getAll<TaskCalendar>(LocalStorageService.calendarsBoxName);
    return result.when(
      success: (calendars) {
        // AppLogger.info('LocalCalendarRepository: Found ${calendars.length} calendars');
        return Result.success(calendars);
      },
      failure: (failure) {
        AppLogger.error('LocalCalendarRepository: Failed to get calendars: ${failure.message}');
        return Result.failure(failure);
      },
    );
  }

  @override
  Future<Result<TaskCalendar?>> getById(String uid) async {
    return await _storageService.get<TaskCalendar>(LocalStorageService.calendarsBoxName, uid);
  }

  @override
  Future<Result<TaskCalendar?>> getByPath(String path) async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final calendar = calendars.where((c) => c.path == path).firstOrNull;
        return Result.success(calendar);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> save(TaskCalendar calendar) async {
    final result = await _storageService.put(LocalStorageService.calendarsBoxName, calendar.path, calendar);
    
    return await result.when(
      success: (_) async {
        return Result.success(null);
      },
      failure: (failure) async {
        AppLogger.error('CalendarRepository: Failed to save calendar ${calendar.path}: ${failure.message}');
        return Result.failure(failure);
      },
    );
  }

  @override
  Future<Result<void>> delete(String uid) async {
    AppLogger.info('LocalCalendarRepository: Deleting calendar: $uid');
    
    try {
      // Check if this is a shared project first (before looking for local calendar)
      AppLogger.info('LocalCalendarRepository: Checking if project $uid is shared with me');
      final userPreferencesResult = await _userRepository.getUserPreferences();
      SharedWithMeProject? sharedProject;
      await userPreferencesResult.when(
        success: (preferences) async {
          AppLogger.info('LocalCalendarRepository: Found ${preferences.sharedWithMeProjects.length} shared projects');
          // Find shared project by extracting UID from project paths
          // SharedWithMeProject.projectId contains full path like /user-uuid/project-uuid/
          // We need to compare extracted UIDs
          for (final shared in preferences.sharedWithMeProjects) {
            final segments = shared.projectId.split('/').where((s) => s.isNotEmpty).toList();
            final sharedProjectUid = segments.isNotEmpty ? segments.last : shared.projectId;
            AppLogger.info('LocalCalendarRepository: Comparing UID "$uid" with shared project UID "$sharedProjectUid" (path: ${shared.projectId})');
            if (sharedProjectUid == uid) {
              sharedProject = shared;
              AppLogger.info('LocalCalendarRepository: MATCH FOUND! Project $uid is shared with me');
              break;
            }
          }
          if (sharedProject == null) {
            AppLogger.info('LocalCalendarRepository: No match found, project $uid is not shared with me');
          }
        },
        failure: (failure) async {
          AppLogger.warning('LocalCalendarRepository: Failed to get user preferences: ${failure.message}');
          // Continue with local calendar lookup if we can't get preferences
        },
      );

      if (sharedProject != null) {
        // Handle shared project deletion using exitShare API
        AppLogger.info('LocalCalendarRepository: Project $uid is shared, using exitShare API');
        
        final accountResult = await _accountRepository.getActiveAccount();
        await accountResult.when(
          success: (account) async {
            if (account != null) {
              try {
                // For exitShare API, we need to pass the project UID, not the full path
                AppLogger.info('LocalCalendarRepository: Using project UID for exitShare: $uid');
                
                final shareService = ShareService(account: account);
                final exitShareResult = await shareService.exitShare(uid);
                
                exitShareResult.when(
                  success: (_) {
                    AppLogger.info('LocalCalendarRepository: Successfully exited share for project: $uid');
                  },
                  failure: (failure) {
                    AppLogger.warning('LocalCalendarRepository: Failed to exit share on server: ${failure.message}');
                    // Continue with local removal even if server exit fails
                  },
                );
              } catch (e) {
                AppLogger.warning('LocalCalendarRepository: Exception during exitShare: $e');
              }
            } else {
              AppLogger.warning('LocalCalendarRepository: No active account for exitShare');
            }
          },
          failure: (failure) {
            AppLogger.warning('LocalCalendarRepository: Failed to get account for exitShare: ${failure.message}');
          },
        );

        // Remove from local shared projects list
        await userPreferencesResult.when(
          success: (preferences) async {
            final updatedPreferences = preferences.copyWith(
              sharedWithMeProjects: preferences.sharedWithMeProjects
                  .where((project) {
                    // Compare UIDs extracted from paths
                    final segments = project.projectId.split('/').where((s) => s.isNotEmpty).toList();
                    final projectUid = segments.isNotEmpty ? segments.last : project.projectId;
                    return projectUid != uid;
                  })
                  .toList(),
            );
            final saveResult = await _userRepository.saveUserPreferences(updatedPreferences);
            saveResult.when(
              success: (_) {
                AppLogger.info('LocalCalendarRepository: Successfully removed shared project from preferences');
              },
              failure: (failure) {
                AppLogger.warning('LocalCalendarRepository: Failed to update user preferences after exit share: ${failure.message}');
              },
            );
          },
          failure: (_) async {
            AppLogger.warning('LocalCalendarRepository: Failed to update user preferences after exit share');
          },
        );

        // Also attempt to remove local calendar cache for shared project
        // Use the project path from SharedWithMeProject for deletion
        final projectPath = sharedProject!.projectId; // This contains the full path
        
        // DEBUG: Log all calendars in storage before deletion
        final allCalendarsBeforeResult = await getAll();
        await allCalendarsBeforeResult.when(
          success: (calendars) async {
            AppLogger.info('LocalCalendarRepository: DEBUG - Before deletion, found ${calendars.length} calendars in storage:');
            for (final cal in calendars) {
              AppLogger.info('  - Calendar: ${cal.displayName} | Path: ${cal.path} | UID: ${cal.uid}');
            }
            AppLogger.info('LocalCalendarRepository: DEBUG - Attempting to delete calendar with path: $projectPath');
          },
          failure: (failure) async {
            AppLogger.warning('LocalCalendarRepository: DEBUG - Failed to get calendars before deletion: ${failure.message}');
          },
        );
        
        final localDeleteResult = await _storageService.delete(LocalStorageService.calendarsBoxName, projectPath);
        localDeleteResult.when(
          success: (_) {
            AppLogger.info('LocalCalendarRepository: Successfully deleted shared project calendar from local storage: $projectPath');
          },
          failure: (failure) {
            AppLogger.info('LocalCalendarRepository: Shared project calendar not found in local storage (expected): $projectPath');
          },
        );
        
        // DEBUG: Log all calendars in storage after deletion
        final allCalendarsAfterResult = await getAll();
        await allCalendarsAfterResult.when(
          success: (calendars) async {
            AppLogger.info('LocalCalendarRepository: DEBUG - After deletion, found ${calendars.length} calendars in storage:');
            for (final cal in calendars) {
              AppLogger.info('  - Calendar: ${cal.displayName} | Path: ${cal.path} | UID: ${cal.uid}');
            }
          },
          failure: (failure) async {
            AppLogger.warning('LocalCalendarRepository: DEBUG - Failed to get calendars after deletion: ${failure.message}');
          },
        );

        return const Result.success(null);
      }

      // Handle owned project deletion (traditional flow)
      final calendarResult = await getById(uid);
      await calendarResult.when(
        success: (calendar) async {
          if (calendar == null) {
            AppLogger.warning('LocalCalendarRepository: Calendar $uid not found for deletion');
            return; // Already deleted
          }

          // Check if this is a shared project and use appropriate API
          final isShared = await _isSharedWithMe(uid);
          
          final accountResult = await _accountRepository.getActiveAccount();
          await accountResult.when(
            success: (account) async {
              if (account != null) {
                try {
                  if (isShared) {
                    // Use exit share API for shared projects
                    AppLogger.info('LocalCalendarRepository: Project is shared with me, using exit share: ${calendar.displayName}');
                    final shareService = ShareService(account: account);
                    final exitShareResult = await shareService.exitShare(uid);
                    
                    exitShareResult.when(
                      success: (_) {
                        AppLogger.info('LocalCalendarRepository: Successfully exited share: ${calendar.displayName}');
                      },
                      failure: (failure) {
                        AppLogger.warning('LocalCalendarRepository: Failed to exit share: ${failure.message}');
                        // Continue with local deletion even if server exit fails
                      },
                    );
                  } else {
                    // Use traditional delete for owned projects
                    AppLogger.info('LocalCalendarRepository: Project is owned by me, using delete: ${calendar.displayName}');
                    final caldavService = CalDAVService(account: account);
                    final serverDeleteResult = await caldavService.deleteCalendar(calendar.path);
                    
                    serverDeleteResult.when(
                      success: (_) {
                        AppLogger.info('LocalCalendarRepository: Successfully deleted calendar from server: ${calendar.displayName}');
                      },
                      failure: (failure) {
                        AppLogger.warning('LocalCalendarRepository: Failed to delete calendar from server: ${failure.message}');
                        // Continue with local deletion even if server deletion fails
                      },
                    );
                  }
                } catch (e) {
                  AppLogger.warning('LocalCalendarRepository: Exception during server operation: $e');
                  // Continue with local deletion even if server operation fails
                }
              } else {
                AppLogger.info('LocalCalendarRepository: No active account - skipping server operation');
              }
            },
            failure: (failure) {
              AppLogger.warning('LocalCalendarRepository: Failed to get account for server operation: ${failure.message}');
              // Continue with local deletion even if we can't get account
            },
          );
        },
        failure: (failure) {
          AppLogger.warning('LocalCalendarRepository: Failed to get calendar for deletion: ${failure.message}');
          // Continue with local deletion attempt
        },
      );

      // If this was a shared project, also remove it from user preferences
      final isShared = await _isSharedWithMe(uid);
      if (isShared) {
        await _removeFromSharedProjects(uid);
      }

      // Always attempt local deletion regardless of server deletion result
      final localDeleteResult = await _storageService.delete(LocalStorageService.calendarsBoxName, uid);
      localDeleteResult.when(
        success: (_) {
          AppLogger.info('LocalCalendarRepository: Successfully deleted calendar from local storage: $uid');
        },
        failure: (failure) {
          AppLogger.error('LocalCalendarRepository: Failed to delete calendar from local storage: ${failure.message}');
        },
      );
      
      return localDeleteResult;
    } catch (e, stackTrace) {
      AppLogger.error('LocalCalendarRepository: Exception during calendar deletion', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to delete calendar: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<void>> deleteSharedProject(String uid, String fullPath) async {
    AppLogger.info('LocalCalendarRepository: Deleting shared project - UID: $uid, Path: $fullPath');
    
    try {
      // Check if this is a shared project using UserPreferences
      final userPreferencesResult = await _userRepository.getUserPreferences();
      SharedWithMeProject? sharedProject;
      await userPreferencesResult.when(
        success: (preferences) async {
          // Find shared project by extracting UID from project paths
          // SharedWithMeProject.projectId contains full path like /user-uuid/project-uuid/
          // We need to compare extracted UIDs
          for (final shared in preferences.sharedWithMeProjects) {
            final segments = shared.projectId.split('/').where((s) => s.isNotEmpty).toList();
            final sharedProjectUid = segments.isNotEmpty ? segments.last : shared.projectId;
            if (sharedProjectUid == uid) {
              sharedProject = shared;
              break;
            }
          }
        },
        failure: (_) async {
          // Continue if we can't get preferences
        },
      );

      if (sharedProject != null) {
        // Handle shared project deletion using exitShare API
        AppLogger.info('LocalCalendarRepository: Project $uid is shared, using exitShare API');
        
        final accountResult = await _accountRepository.getActiveAccount();
        await accountResult.when(
          success: (account) async {
            if (account != null) {
              try {
                // Use the project UID for exitShare API
                AppLogger.info('LocalCalendarRepository: Using project UID for exitShare: $uid');
                
                final shareService = ShareService(account: account);
                final exitShareResult = await shareService.exitShare(uid);
                
                exitShareResult.when(
                  success: (_) {
                    AppLogger.info('LocalCalendarRepository: Successfully exited share for project: $uid');
                  },
                  failure: (failure) {
                    AppLogger.warning('LocalCalendarRepository: Failed to exit share on server: ${failure.message}');
                    // Continue with local removal even if server exit fails
                  },
                );
              } catch (e) {
                AppLogger.warning('LocalCalendarRepository: Exception during exitShare: $e');
              }
            } else {
              AppLogger.warning('LocalCalendarRepository: No active account for exitShare');
            }
          },
          failure: (failure) {
            AppLogger.warning('LocalCalendarRepository: Failed to get account for exitShare: ${failure.message}');
          },
        );

        // Remove from local shared projects list
        await userPreferencesResult.when(
          success: (preferences) async {
            final updatedPreferences = preferences.copyWith(
              sharedWithMeProjects: preferences.sharedWithMeProjects
                  .where((project) {
                    // Compare UIDs extracted from paths
                    final segments = project.projectId.split('/').where((s) => s.isNotEmpty).toList();
                    final projectUid = segments.isNotEmpty ? segments.last : project.projectId;
                    return projectUid != uid;
                  })
                  .toList(),
            );
            final saveResult = await _userRepository.saveUserPreferences(updatedPreferences);
            saveResult.when(
              success: (_) {
                AppLogger.info('LocalCalendarRepository: Successfully removed shared project from preferences');
              },
              failure: (failure) {
                AppLogger.warning('LocalCalendarRepository: Failed to update user preferences after exit share: ${failure.message}');
              },
            );
          },
          failure: (_) async {
            AppLogger.warning('LocalCalendarRepository: Failed to update user preferences after exit share');
          },
        );

        // Remove local calendar cache for shared project using the full path
        AppLogger.info('LocalCalendarRepository: DEBUG - Attempting to delete calendar with full path: $fullPath');
        final localDeleteResult = await _storageService.delete(LocalStorageService.calendarsBoxName, fullPath);
        localDeleteResult.when(
          success: (_) {
            AppLogger.info('LocalCalendarRepository: Successfully deleted shared project calendar from local storage: $fullPath');
          },
          failure: (failure) {
            AppLogger.warning('LocalCalendarRepository: Failed to delete shared project calendar from local storage: ${failure.message}');
          },
        );

        // DEBUG: Log all calendars in storage after deletion
        final allCalendarsAfterResult = await getAll();
        await allCalendarsAfterResult.when(
          success: (calendars) async {
            AppLogger.info('LocalCalendarRepository: DEBUG - After shared project deletion, found ${calendars.length} calendars in storage:');
            for (final cal in calendars) {
              AppLogger.info('  - Calendar: ${cal.displayName} | Path: ${cal.path} | UID: ${cal.uid}');
            }
          },
          failure: (failure) async {
            AppLogger.warning('LocalCalendarRepository: DEBUG - Failed to get calendars after deletion: ${failure.message}');
          },
        );

        return const Result.success(null);
      } else {
        AppLogger.warning('LocalCalendarRepository: Project $uid not found in shared projects list');
        return Result.failure(Failure(
          message: 'Project not found in shared projects',
          exception: Exception('Not a shared project'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('LocalCalendarRepository: Exception during shared project deletion', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to delete shared project: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Stream<List<TaskCalendar>> watchCalendars() async* {
    // Emit initial value
    final result = await getAll();
    final initialCalendars = result.when(
      success: (calendars) => calendars,
      failure: (_) => <TaskCalendar>[],
    );
    AppLogger.info('LocalCalendarRepository: DEBUG - watchCalendars initial emit: ${initialCalendars.length} calendars');
    yield initialCalendars;
    
    // Then listen to changes
    yield* _storageService.getStream(LocalStorageService.calendarsBoxName)
        .asyncMap((boxEvent) async {
          AppLogger.info('LocalCalendarRepository: DEBUG - watchCalendars received box event: ${boxEvent.key} ${boxEvent.deleted ? "DELETED" : "UPDATED"}');
          final result = await getAll();
          final calendars = result.when(
            success: (calendars) => calendars,
            failure: (_) => <TaskCalendar>[],
          );
          AppLogger.info('LocalCalendarRepository: DEBUG - watchCalendars emitting: ${calendars.length} calendars');
          return calendars;
        });
  }

  @override
  Future<Result<List<TaskCalendar>>> getProjectCalendars() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        // All calendars that support VTODO are projects (including archived ones)
        final projects = calendars.where((c) => c.supportsTodos).toList();
        // AppLogger.info('LocalCalendarRepository: Found  [32m${projects.length} [0m project calendars (all VTODO calendars including archived)');
        return Result.success(projects);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<TaskCalendar>>> getCalendarsByDomain(String? domain) async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final filteredCalendars = calendars.where((calendar) {
          if (domain == null || domain.toLowerCase() == 'no domain') {
            return !calendar.hasDomain;
          }
          return calendar.belongsToDomain(domain);
        }).toList();
        
        AppLogger.info('LocalCalendarRepository: Found ${filteredCalendars.length} calendars in domain: ${domain ?? "No Domain"}');
        return Result.success(filteredCalendars);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<String>>> getUniqueDomains() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final domains = calendars
            .where((calendar) => calendar.hasDomain)
            .map((calendar) => calendar.flowitDomain!)
            .toSet()
            .toList();
        
        // Sort domains alphabetically (case-insensitive)
        domains.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        
        AppLogger.info('LocalCalendarRepository: Found ${domains.length} unique domains');
        return Result.success(domains);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> renameDomain(String oldDomain, String newDomain) async {
    final result = await getAll();
    return result.when(
      success: (calendars) async {
        final calendarsToUpdate = calendars
            .where((calendar) => calendar.belongsToDomain(oldDomain))
            .toList();
        
        AppLogger.info('LocalCalendarRepository: Renaming domain "$oldDomain" to "$newDomain" for ${calendarsToUpdate.length} calendars');
        
        for (final calendar in calendarsToUpdate) {
          final updatedCalendar = calendar.withDomain(newDomain);
          final saveResult = await save(updatedCalendar);
          if (saveResult is Error<void>) {
            AppLogger.error('LocalCalendarRepository: Failed to rename domain for calendar ${calendar.path}: ${saveResult.failure.message}');
            return saveResult;
          }
        }
        
        return Result.success(null);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<Map<String, int>>> getDomainStatistics() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final statistics = <String, int>{};
        
        for (final calendar in calendars) {
          final domain = calendar.domainDisplayName;
          statistics[domain] = (statistics[domain] ?? 0) + 1;
        }
        
        AppLogger.info('LocalCalendarRepository: Domain statistics calculated for ${statistics.length} domains');
        return Result.success(statistics);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<TaskCalendar>>> getCalendarsWithoutDomain() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final calendarsWithoutDomain = calendars.where((calendar) => !calendar.hasDomain).toList();
        AppLogger.info('LocalCalendarRepository: Found ${calendarsWithoutDomain.length} calendars without domain');
        return Result.success(calendarsWithoutDomain);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<TaskCalendar>>> getCalendarsByStatus(String? status) async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
                 final filteredCalendars = calendars.where((calendar) {
           if (status == null || status.toLowerCase() == 'no status') {
             return !calendar.hasStatus;
           }
           return calendar.hasProjectStatus(status);
         }).toList();
        
        AppLogger.info('LocalCalendarRepository: Found ${filteredCalendars.length} calendars in status: ${status ?? "No Status"}');
        return Result.success(filteredCalendars);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<String>>> getUniqueStatuses() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final statuses = calendars
            .where((calendar) => calendar.hasStatus)
            .map((calendar) => calendar.flowitStatus!)
            .toSet()
            .toList();
        
        // Sort statuses alphabetically (case-insensitive)
        statuses.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        
        AppLogger.info('LocalCalendarRepository: Found ${statuses.length} unique statuses');
        return Result.success(statuses);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> changeStatus(String oldStatus, String newStatus) async {
    final result = await getAll();
    return result.when(
      success: (calendars) async {
                 final calendarsToUpdate = calendars
             .where((calendar) => calendar.hasProjectStatus(oldStatus))
             .toList();
        
        AppLogger.info('LocalCalendarRepository: Changing status from "$oldStatus" to "$newStatus" for ${calendarsToUpdate.length} calendars');
        
        for (final calendar in calendarsToUpdate) {
          final updatedCalendar = calendar.withStatus(newStatus);
          final saveResult = await save(updatedCalendar);
          if (saveResult is Error<void>) {
            AppLogger.error('LocalCalendarRepository: Failed to change status for calendar ${calendar.path}: ${saveResult.failure.message}');
            return saveResult;
          }
        }
        
        return Result.success(null);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<Map<String, int>>> getStatusStatistics() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final statistics = <String, int>{};
        
        for (final calendar in calendars) {
          final status = calendar.statusDisplayName;
          statistics[status] = (statistics[status] ?? 0) + 1;
        }
        
        AppLogger.info('LocalCalendarRepository: Status statistics calculated for ${statistics.length} statuses');
        return Result.success(statistics);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<TaskCalendar>>> getCalendarsWithoutStatus() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final calendarsWithoutStatus = calendars.where((calendar) => !calendar.hasStatus).toList();
        AppLogger.info('LocalCalendarRepository: Found ${calendarsWithoutStatus.length} calendars without status');
        return Result.success(calendarsWithoutStatus);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<TaskCalendar>>> getArchivedCalendars() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final archivedCalendars = calendars.where((calendar) => calendar.isArchived).toList();
        AppLogger.info('LocalCalendarRepository: Found ${archivedCalendars.length} archived calendars');
        return Result.success(archivedCalendars);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<TaskCalendar>>> getActiveCalendars() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final activeCalendars = calendars.where((calendar) => !calendar.isArchived).toList();
        AppLogger.info('LocalCalendarRepository: Found ${activeCalendars.length} active calendars');
        return Result.success(activeCalendars);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> updateCalendarProperties(TaskCalendar calendar) async {
    try {
      AppLogger.info('LocalCalendarRepository: Updating calendar properties for ${calendar.displayName}');
      AppLogger.debug('LocalCalendarRepository: Calendar path: ${calendar.path}');
      
      final saveResult = await save(calendar); // Save locally first
      
      return await saveResult.when(
        success: (_) async {
          AppLogger.debug('LocalCalendarRepository: Calendar saved locally, queuing server sync');
          
          // Always use sync queue for offline resilience via singleton
          final syncService = SyncService.instance;
          if (syncService != null) {
            AppLogger.debug('LocalCalendarRepository: SyncService singleton found, queuing calendar update');
            AppLogger.debug('LocalCalendarRepository: Queuing update for calendar path: ${calendar.path}');
            
            final queueResult = await syncService.queueCalendarUpdate(calendar.path);
            
            return await queueResult.when(
              success: (_) async {
                AppLogger.info('LocalCalendarRepository: Successfully queued calendar properties update');
                return Result.success(null);
              },
              failure: (failure) async {
                AppLogger.error('LocalCalendarRepository: Failed to queue calendar update: ${failure.message}');
                return Result.failure(failure);
              },
            );
          } else {
            AppLogger.error('LocalCalendarRepository: SyncService singleton is NULL - cannot queue update');
            AppLogger.error('LocalCalendarRepository: This indicates the SyncService was not properly initialized');
            return Result.failure(Failure(
              message: 'SyncService not initialized',
              exception: Exception('SyncService singleton not available - check initialization order'),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('LocalCalendarRepository: Failed to save calendar locally: ${failure.message}');
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('LocalCalendarRepository: Exception updating calendar properties', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to update calendar properties: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<void>> assignDomainToCalendar(String calendarUid, String? domain) async {
    // Get the calendar and update its domain
    final calendarResult = await getById(calendarUid);
    return calendarResult.when(
      success: (calendar) async {
        if (calendar == null) {
          return Result.failure(const Failure(
            message: 'Calendar not found',
            code: 'CALENDAR_NOT_FOUND',
          ));
        }
        
        final updatedCalendar = calendar.copyWith(flowitDomain: domain);
        
        // Save locally first
        final saveResult = await save(updatedCalendar);
        if (saveResult is Error<void>) {
          return saveResult;
        }
        
        // Then queue sync to server
        return await _queueCalendarSync(updatedCalendar);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Queue calendar update for server sync
  Future<Result<void>> _queueCalendarSync(TaskCalendar calendar) async {
    try {
      // Use SyncService singleton to queue the calendar update
      final syncService = SyncService.instance;
      if (syncService != null) {
        AppLogger.debug('CalendarRepository: Queuing calendar update for domain sync');
        final queueResult = await syncService.queueCalendarUpdate(calendar.path);
        
        return await queueResult.when(
          success: (_) async {
            AppLogger.info('CalendarRepository: Successfully queued calendar sync to server');
            return Result.success(null);
          },
          failure: (failure) async {
            AppLogger.error('CalendarRepository: Failed to queue calendar sync: ${failure.message}');
            return Result.failure(failure);
          },
        );
      } else {
        AppLogger.error('CalendarRepository: SyncService singleton not initialized - cannot queue update');
        return Result.failure(Failure(
          message: 'SyncService not initialized',
          exception: Exception('SyncService singleton not available'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('CalendarRepository: Exception during calendar sync to server', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to sync calendar to server: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }
} 
