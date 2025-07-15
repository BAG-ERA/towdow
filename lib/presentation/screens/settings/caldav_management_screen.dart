// CalDAV Management Screen
// Discover and manage calendar selections for synchronization

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/caldav_account.dart';
import '../../../data/models/task_calendar.dart';
import '../../../data/services/caldav_service.dart';
import '../../../data/services/local_storage_service.dart';
import '../../../data/services/user_sync_service.dart';
import '../../../data/providers/providers.dart';
import '../../../core/logger.dart';
import '../../../data/services/webdav_client.dart';

class CalDAVManagementScreen extends ConsumerStatefulWidget {
  const CalDAVManagementScreen({super.key});

  @override
  ConsumerState<CalDAVManagementScreen> createState() => _CalDAVManagementScreenState();
}

class _CalDAVManagementScreenState extends ConsumerState<CalDAVManagementScreen> {
  CaldavAccount? _currentAccount;
  CalDAVCapabilities? _capabilities;
  Set<TaskCalendar> _selectedCalendars = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadAccountAndDiscoverCalendars();
  }

  Future<void> _loadSelectedCalendars() async {
    final calendarRepository = ref.read(calendarRepositoryProvider);
    final userRepository = ref.read(userRepositoryProvider);
    
    // First try to load from repository (existing calendars)
    final result = await calendarRepository.getProjectCalendars();
    
    result.when(
      success: (calendars) {
        setState(() {
          _selectedCalendars = Set.from(calendars);
        });
        AppLogger.info('CalDAVManagement: Loaded ${calendars.length} selected calendars from repository');
      },
      failure: (failure) {
        AppLogger.warning('CalDAVManagement: Failed to load selected calendars: ${failure.message}');
        setState(() {
          _selectedCalendars = {};
        });
      },
    );
    
    // Also check user preferences for project order (in case of sync from cloud)
    final preferencesResult = await userRepository.getUserPreferences();
    await preferencesResult.when(
      success: (preferences) async {
        if (preferences.projectOrder.isNotEmpty) {
          AppLogger.info('CalDAVManagement: Found ${preferences.projectOrder.length} projects in user preferences order');
          
          // If we have project order but no selected calendars, we might need to discover and select those calendars
          if (_selectedCalendars.isEmpty && _capabilities != null) {
            final discoveredCalendars = _capabilities!.taskCalendars;
            final calendarsToSelect = <TaskCalendar>[];
            
            for (final projectPath in preferences.projectOrder) {
              final matchingCalendar = discoveredCalendars.where((cal) => cal.path == projectPath).firstOrNull;
              if (matchingCalendar != null) {
                calendarsToSelect.add(matchingCalendar);
              }
            }
            
            if (calendarsToSelect.isNotEmpty) {
              setState(() {
                _selectedCalendars = Set.from(calendarsToSelect);
                _hasChanges = true; // Mark as having changes to trigger save
              });
              AppLogger.info('CalDAVManagement: Auto-selected ${calendarsToSelect.length} calendars from user preferences');
            }
          }
        }
      },
      failure: (failure) {
        AppLogger.debug('CalDAVManagement: No user preferences found or failed to load: ${failure.message}');
      },
    );
  }

  Future<void> _loadAccountAndDiscoverCalendars() async {
    AppLogger.debug('CalDAVManagement: Starting account and calendar discovery');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load current account
      final accountResult = ref.read(activeAccountProvider);
      await accountResult.when(
        data: (account) async {
          if (account != null) {
            AppLogger.debug('CalDAVManagement: Account loaded, starting calendar discovery');
            setState(() {
              _currentAccount = account;
            });
            
            // Load currently selected calendars from repository
            await _loadSelectedCalendars();
            
            // Discover calendars via PROPFIND
            await _discoverCalendars(account);
          } else {
            AppLogger.warning('CalDAVManagement: No active CalDAV account found');
            setState(() {
              _errorMessage = 'No active CalDAV account found';
            });
          }
        },
        loading: () async {
          AppLogger.debug('CalDAVManagement: Account provider is loading');
          // Keep loading state
        },
        error: (error, stack) async {
          AppLogger.error('CalDAVManagement: Failed to load account: $error');
          setState(() {
            _errorMessage = 'Failed to load account: $error';
          });
        },
      );
    } catch (e) {
      AppLogger.error('CalDAVManagement: Unexpected error during initialization', e, StackTrace.current);
      setState(() {
        _errorMessage = 'Unexpected error: $e';
      });
    } finally {
      if (mounted) {
        AppLogger.debug('CalDAVManagement: Setting loading to false. Capabilities: ${_capabilities?.taskCalendars.length ?? 0} calendars');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _discoverCalendars(CaldavAccount account) async {
    AppLogger.info('CalDAVManagement: Starting calendar discovery for ${account.serverUrl}');
    
    try {
      final caldavService = CalDAVService(account: account);
      final capabilitiesResult = await caldavService.discoverCapabilities();
      
      await capabilitiesResult.when(
        success: (capabilities) async {
          AppLogger.info('CalDAVManagement: Successfully discovered ${capabilities.taskCalendars.length} calendars');
          setState(() {
            _capabilities = capabilities;
          });
        },
        failure: (failure) async {
          AppLogger.error('CalDAVManagement: Failed to discover calendars: ${failure.message}');
          setState(() {
            _errorMessage = 'Failed to discover calendars: ${failure.message}';
          });
        },
      );
    } catch (e) {
      AppLogger.error('CalDAVManagement: Discovery error', e, StackTrace.current);
      setState(() {
        _errorMessage = 'Discovery error: $e';
      });
    }
  }

  Future<void> _refreshCalendars() async {
    if (_currentAccount != null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      try {
        await _discoverCalendars(_currentAccount!);
      } on RefreshTokenExpiredException catch (_) {
        handleSessionExpired();
        return;
      } catch (e) {
        AppLogger.error('CalDAVManagement: Refresh error', e, StackTrace.current);
        setState(() {
          _errorMessage = 'Refresh error: $e';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _toggleCalendarSelection(TaskCalendar calendar) {
    setState(() {
      // Find existing calendar with same path and replace/remove it
      final existingCalendar = _selectedCalendars.where((c) => c.path == calendar.path).firstOrNull;
      
      if (existingCalendar != null) {
        _selectedCalendars.remove(existingCalendar);
      } else {
        _selectedCalendars.add(calendar);
      }
      _hasChanges = true;
    });
    
    // Update user preferences with new project order
    _updateUserPreferencesProjectOrder();
  }

  bool _isCalendarSelected(TaskCalendar calendar) {
    return _selectedCalendars.any((c) => c.path == calendar.path);
  }

  /// Update user preferences with current project order and sync status
  Future<void> _updateUserPreferencesProjectOrder() async {
    try {
      final userRepository = ref.read(userRepositoryProvider);
      
      // Get current preferences
      final preferencesResult = await userRepository.getUserPreferences();
      await preferencesResult.when(
        success: (preferences) async {
          // Create project order from selected calendars (using calendar path as project UID)
          final projectOrder = _selectedCalendars.map((c) => c.path).toList();
          
          // Update preferences with new project order
          final updatedPreferences = preferences.copyWith(
            projectOrder: projectOrder,
            syncedProjects: projectOrder, // Also update synced projects list
          );
          
          // Save updated preferences
          await userRepository.saveUserPreferences(updatedPreferences);
          AppLogger.info('CalDAVManagement: Updated user preferences with ${projectOrder.length} projects');
        },
        failure: (failure) {
          AppLogger.warning('CalDAVManagement: Failed to update user preferences: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVManagement: Error updating user preferences', e, stackTrace);
    }
  }

  /// Trigger user sync upload for cloud/self-hosted users
  Future<void> _triggerUserSyncUpload() async {
    try {
      if (_currentAccount == null) return;
      
      final userRepository = ref.read(userRepositoryProvider);
      final externalAccountRepository = ref.read(externalAccountRepositoryProvider);
      final accountRepository = ref.read(accountRepositoryProvider);
      final calendarRepository = ref.read(calendarRepositoryProvider);
      
      final userSyncService = UserSyncService(
        userRepository: userRepository,
        externalAccountRepository: externalAccountRepository,
        accountRepository: accountRepository,
        calendarRepository: calendarRepository,
      );
      
      final syncAvailable = await userSyncService.isSyncAvailable();
      if (syncAvailable) {
        final uploadResult = await userSyncService.uploadUserData();
        uploadResult.when(
          success: (_) {
            AppLogger.info('CalDAVManagement: Successfully uploaded user data to S3');
          },
          failure: (failure) {
            AppLogger.warning('CalDAVManagement: Failed to sync user data: ${failure.message}');
          },
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVManagement: Error triggering user sync upload', e, stackTrace);
    }
  }

  /// Clear existing calendars and save selected calendars as local projects
  Future<void> _createProjectsForSelectedCalendars() async {
    // AppLogger.info('CalDAVManagement: Starting to update projects for selected calendars');
    // AppLogger.info('CalDAVManagement: Selected calendars count: ${_selectedCalendars.length}');
    
    final calendarRepository = ref.read(calendarRepositoryProvider);
    final localStorage = ref.read(localStorageServiceProvider);
    
    // First, clear all existing calendars (repository is now source of truth)
    // AppLogger.info('CalDAVManagement: Clearing existing calendars from repository');
    final clearResult = await localStorage.clear(LocalStorageService.calendarsBoxName);
    
    clearResult.when(
      success: (_) {
        // AppLogger.info('CalDAVManagement: Successfully cleared existing calendars');
      },
      failure: (failure) {
        AppLogger.warning('CalDAVManagement: Failed to clear calendars: ${failure.message}');
      },
    );
    
    // Now save only the selected calendars
    // AppLogger.info('CalDAVManagement: Saving ${_selectedCalendars.length} selected calendars');
    for (final calendar in _selectedCalendars) {
      // AppLogger.info('CalDAVManagement: Processing calendar: ${calendar.displayName} (${calendar.path})');
      
      final saveResult = await calendarRepository.save(calendar);
      saveResult.when(
        success: (_) {
          // AppLogger.info('CalDAVManagement: ✅ Successfully saved calendar ${calendar.displayName}');
        },
        failure: (failure) {
          AppLogger.error('CalDAVManagement: ❌ Failed to save calendar ${calendar.displayName}: ${failure.message}');
        },
      );
    }
    
    // AppLogger.info('CalDAVManagement: Finished updating selected calendars');
    
    // Invalidate project list provider to refresh the UI
    ref.invalidate(projectListProvider);
  }

  Future<void> _saveChanges() async {
    if (_currentAccount == null || !_hasChanges) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Account no longer stores selectedCalendars - just use current account
      final updatedAccount = _currentAccount!;

      final accountRepository = ref.read(accountRepositoryProvider);
      final saveResult = await accountRepository.save(updatedAccount);

      saveResult.when(
        success: (_) async {
          // AppLogger.info('CalDAVManagement: Saved ${_selectedCalendars.length} selected calendars');
          
          // Invalidate providers to refresh the app state
          ref.invalidate(activeAccountProvider);
          
          // Create projects for selected calendars
          await _createProjectsForSelectedCalendars();
          
          setState(() {
            _currentAccount = updatedAccount;
            _hasChanges = false;
          });

          // Trigger user sync upload after saving changes
          _triggerUserSyncUpload();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Saved ${_selectedCalendars.length} calendar selections and created projects'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        failure: (failure) async {
          setState(() {
            _errorMessage = 'Failed to save changes: ${failure.message}';
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Save error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CalDAV Calendar Management'),
        actions: [
          if (_capabilities != null && !_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refreshCalendars,
              tooltip: 'Refresh calendar list',
            ),
        ],
      ),
      body: Column(
        children: [
          // Account info
          if (_currentAccount != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_circle_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CalDAV Account',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Server: ${_currentAccount!.serverUrl}'),
                  Text('User: ${_currentAccount!.username}'),
                  if (_capabilities != null) ...[
                    const SizedBox(height: 4),
                    Text('Capabilities: ${_capabilities!.serverInfo}'),
                  ],
                ],
              ),
            ),

          // Calendar list
          Expanded(
            child: _buildCalendarList(),
          ),

          // Action buttons
          if (_hasChanges && !_isLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      // Reset by reloading from repository
                      await _loadSelectedCalendars();
                      setState(() {
                        _hasChanges = false;
                      });
                    },
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _saveChanges,
                    icon: const Icon(Icons.save_rounded),
                    label: Text('Save ${_selectedCalendars.length} selections'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Discovering calendars...'),
            SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAccountAndDiscoverCalendars,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_capabilities == null || _capabilities!.taskCalendars.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _capabilities == null ? 'No calendars discovered' : 'No task calendars found',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _capabilities == null 
                  ? 'Calendar discovery may still be in progress or failed.'
                  : 'No calendars found that support tasks (VTODO).\n\nMake sure your CalDAV server has task-enabled calendars.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _capabilities!.taskCalendars.length,
      itemBuilder: (context, index) {
        final calendar = _capabilities!.taskCalendars[index];
        final isSelected = _isCalendarSelected(calendar);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (_) => _toggleCalendarSelection(calendar),
            title: Text(
              calendar.displayName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (calendar.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(calendar.description),
                ],
                const SizedBox(height: 4),
                Text(
                  calendar.path,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontFamily: 'monospace',
                  ),
                ),
                if (calendar.etag != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'ETag: ${calendar.etag}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
            secondary: Icon(
              calendar.supportsTodos 
                  ? Icons.task_alt_rounded 
                  : Icons.event_note_rounded,
              color: calendar.supportsTodos 
                  ? Colors.green 
                  : Colors.orange,
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
      },
    );
  }
}
