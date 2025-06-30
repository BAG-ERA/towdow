// Project Portfolio selection screen after successful CalDAV connection
// Allows users to choose which project portfolios to sync or create new ones

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/caldav_account.dart';
import '../../../../data/models/task_calendar.dart';
import '../../../../data/services/caldav_service.dart';
import '../../../../data/services/local_storage_service.dart';
import '../../../../data/providers/providers.dart';
import '../../../../core/logger.dart';
// Result type is imported via caldav_service.dart

class CalendarSelectionScreen extends ConsumerStatefulWidget {
  final CaldavAccount account;
  final CalDAVCapabilities capabilities;

  const CalendarSelectionScreen({
    super.key,
    required this.account,
    required this.capabilities,
  });

  @override
  ConsumerState<CalendarSelectionScreen> createState() => _CalendarSelectionScreenState();
}

class _CalendarSelectionScreenState extends ConsumerState<CalendarSelectionScreen> {
  final Set<TaskCalendar> _selectedCalendars = {};
  bool _isLoading = true; // Start with loading true
  String? _errorMessage;
  CalDAVCapabilities? _discoveredCapabilities;

  @override
  void initState() {
    super.initState();
    _discoverRealCapabilities();
  }

  Future<void> _discoverRealCapabilities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // AppLogger.info('CalendarSelectionScreen: Starting calendar discovery for account: ${widget.account.serverUrl}');
      final caldavService = CalDAVService(account: widget.account);
      final discoveryResult = await caldavService.discoverCapabilities();
      
      await discoveryResult.when(
        success: (capabilities) async {
          // AppLogger.info('CalendarSelectionScreen: Discovery successful - found ${capabilities.taskCalendars.length} calendars');
          for (final calendar in capabilities.taskCalendars) {
            // AppLogger.info('CalendarSelectionScreen: Found calendar: ${calendar.displayName} at ${calendar.path} (supports VTODO: ${calendar.supportsTodos})');
          }
          
          setState(() {
            _discoveredCapabilities = capabilities;
            _isLoading = false;
            
            // Don't pre-select calendars - let user choose
            // AppLogger.info('CalendarSelectionScreen: Discovered ${capabilities.taskCalendars.length} calendars, user can select which ones to sync');
          });
        },
        failure: (failure) {
          AppLogger.error('CalendarSelectionScreen: Discovery failed: ${failure.message}');
          setState(() {
            _errorMessage = 'Failed to discover calendars: ${failure.message}';
            _isLoading = false;
          });
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalendarSelectionScreen: Unexpected error during discovery', e, stackTrace);
      setState(() {
        _errorMessage = 'Unexpected error during discovery: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use discovered capabilities if available, fallback to passed capabilities
    final capabilities = _discoveredCapabilities ?? widget.capabilities;
    final availableCalendars = capabilities.taskCalendars;
    final hasExistingCalendars = availableCalendars.any((cal) => 
      !cal.path.contains('flowit-tasks') && !cal.path.contains('tasks/'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Project Portfolios'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server info
            Container(
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
                        Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Connected Successfully',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Server: ${widget.account.serverUrl}'),
                  Text('User: ${widget.account.username}'),
                  Text('Capabilities: ${capabilities.serverInfo}'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Project Portfolio selection section
            Text(
              hasExistingCalendars 
                ? 'Select project portfolios to sync with FlowIt:'
                : 'No existing project portfolios found.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              hasExistingCalendars
                ? 'Choose which project portfolios you want to synchronize. Only portfolios that support tasks (VTODO) will work with FlowIt.'
                : 'You can create a new project portfolio for your FlowIt tasks, or FlowIt will use a default portfolio.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Project Portfolio list and create option
            Expanded(
              child: _isLoading 
                ? _buildLoadingState()
                : _buildCalendarContent(availableCalendars, hasExistingCalendars),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_rounded, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isLoading ? null : _finishSetup,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(hasExistingCalendars && _selectedCalendars.isNotEmpty 
                          ? 'Start Syncing (${_selectedCalendars.length} portfolios)'
                          : 'Continue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarList(List<TaskCalendar> calendars) {
    return ListView.builder(
      itemCount: calendars.length,
      itemBuilder: (context, index) {
        final calendar = calendars[index];
        final isSelected = _selectedCalendars.contains(calendar);
        
        return Card(
          child: CheckboxListTile(
            value: isSelected,
            onChanged: calendar.supportsTodos ? (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedCalendars.add(calendar);
                } else {
                  _selectedCalendars.remove(calendar);
                }
              });
            } : null,
            title: Text(calendar.displayName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(calendar.description),
                Text(
                  calendar.path,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
            secondary: Icon(
              calendar.supportsTodos ? Icons.task_alt_rounded : Icons.event_rounded,
              color: calendar.supportsTodos 
                ? Theme.of(context).colorScheme.primary 
                : Colors.grey,
            ),
            enabled: calendar.supportsTodos,
          ),
        );
      },
    );
  }

  Widget _buildCalendarContent(List<TaskCalendar> calendars, bool hasExistingCalendars) {
    if (hasExistingCalendars) {
      return Column(
        children: [
          // List of existing calendars
          Expanded(
            child: _buildCalendarList(calendars),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          // Option to create new calendar
          _buildCreateNewCalendarCard(),
        ],
      );
    } else {
      // No existing calendars, show create option
      return _buildCreateCalendarOption();
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Discovering project portfolios...'),
          SizedBox(height: 8),
          Text(
            'This may take a few moments depending on your server.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateNewCalendarCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create New Project Portfolio',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Create a new project portfolio with custom name on your server',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _showCreateCalendarDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCalendarOption() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_circle_outline_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Create Your First Project Portfolio',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first project portfolio with a custom name to store your tasks and projects.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateCalendarDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Portfolio'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateCalendarDialog() async {
    final nameController = TextEditingController(text: 'FlowIt Portfolio');
    final descriptionController = TextEditingController(text: 'Project portfolio created by FlowIt');
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Project Portfolio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Portfolio Name',
                hintText: 'Enter portfolio name',
                prefixIcon: Icon(Icons.work_rounded),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Enter portfolio description',
                prefixIcon: Icon(Icons.description_rounded),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop({
                  'name': name,
                  'description': descriptionController.text.trim(),
                });
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      await _createCalendar(
        name: result['name']!,
        description: result['description']?.isEmpty == true ? null : result['description'],
      );
    }
  }

  Future<void> _createCalendar({required String name, String? description}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final caldavService = CalDAVService(account: widget.account);
      final capabilities = _discoveredCapabilities ?? widget.capabilities;
      
      // Generate a safe path name from the display name
      final safeName = name.toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      
      final calendarPath = '${capabilities.calendarHome}${safeName.isEmpty ? 'flowit-tasks' : safeName}/';
      
      final createResult = await caldavService.createCalendar(
        calendarPath: calendarPath,
        displayName: name,
        description: description ?? 'Project portfolio created by FlowIt',
      );

      await createResult.when(
        success: (newCalendar) async {
          setState(() {
            _selectedCalendars.add(newCalendar);
          });
          await _finishSetup();
        },
        failure: (failure) {
          setState(() {
            _errorMessage = 'Failed to create portfolio: ${failure.message}';
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _finishSetup() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Save the account (without selectedCalendars)
      final accountRepository = ref.read(accountRepositoryProvider);
      final saveResult = await accountRepository.save(widget.account);
      
      await saveResult.when(
        success: (_) async {
          // Clear existing calendars and save only selected ones
          await _saveCalendarsAsProjects();
          
          if (mounted) {
            // Close this screen first - go back to ConnectionScreen
            Navigator.of(context).pop();
            
            // Wait a moment for the pop to complete
            await Future.delayed(const Duration(milliseconds: 100));
            
            // Invalidate providers - this will trigger _AppShell to detect the account
            // and automatically navigate to HomeScreen
            ref.invalidate(hasActiveAccountProvider);
            ref.invalidate(activeAccountProvider);
          }
        },
        failure: (failure) {
          setState(() {
            _errorMessage = 'Failed to save setup: ${failure.message}';
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Clear existing calendars and save selected calendars as local projects/portfolios
  Future<void> _saveCalendarsAsProjects() async {
    final calendarRepository = ref.read(calendarRepositoryProvider);
    
    // First, clear all existing calendars (repository is now source of truth)
    // AppLogger.info('CalendarSelection: Clearing existing calendars from repository');
    final localStorage = ref.read(localStorageServiceProvider);
    final clearResult = await localStorage.clear(LocalStorageService.calendarsBoxName);
    
    clearResult.when(
      success: (_) {
        // AppLogger.info('CalendarSelection: Successfully cleared existing calendars');
      },
      failure: (failure) {
        AppLogger.warning('CalendarSelection: Failed to clear calendars: ${failure.message}');
      },
    );
    
    // Now save only the selected calendars
    // AppLogger.info('CalendarSelection: Saving ${_selectedCalendars.length} selected calendars');
    for (final calendar in _selectedCalendars) {
      final saveResult = await calendarRepository.save(calendar);
      saveResult.when(
        success: (_) {
          // AppLogger.info('CalendarSelection: Saved calendar ${calendar.displayName} as project');
        },
        failure: (failure) {
          AppLogger.error('CalendarSelection: Failed to save calendar as project', failure.exception, failure.stackTrace);
        },
      );
    }
    
    // Invalidate project list provider to refresh the UI
    ref.invalidate(projectListProvider);
  }
} 
