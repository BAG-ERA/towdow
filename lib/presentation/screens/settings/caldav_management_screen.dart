// CalDAV Management Screen
// Discover and manage calendar selections for synchronization
//
// This screen uses CalDAVManagementViewModel to handle:
// - Calendar discovery and display
// - Calendar selection state management
// - Project creation from selected calendars
// - User sync upload for cloud accounts
// - Error handling and refresh functionality

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/providers.dart';
import '../../viewmodels/caldav_management_viewmodel.dart';
import '../../../data/services/webdav_client.dart';

class CalDAVManagementScreen extends ConsumerStatefulWidget {
  const CalDAVManagementScreen({super.key});

  @override
  ConsumerState<CalDAVManagementScreen> createState() => _CalDAVManagementScreenState();
}

class _CalDAVManagementScreenState extends ConsumerState<CalDAVManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize the ViewModel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(caldavManagementViewModelProvider.notifier).initialize();
    });
  }

  void _handleRefreshTokenExpired() {
    handleSessionExpired();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(caldavManagementViewModelProvider);
        final viewModel = ref.read(caldavManagementViewModelProvider.notifier);
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('CalDAV Calendar Management'),
            actions: [
              if (state.capabilities != null && !state.isLoading)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    try {
                      viewModel.refreshCalendars();
                    } on RefreshTokenExpiredException catch (_) {
                      _handleRefreshTokenExpired();
                    }
                  },
                  tooltip: 'Refresh calendar list',
                ),
            ],
          ),
          body: Column(
            children: [
              // Account info
              if (state.currentAccount != null)
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
                      Text('Server: ${state.currentAccount!.serverUrl}'),
                      Text('User: ${state.currentAccount!.username}'),
                      if (state.capabilities != null) ...[
                        const SizedBox(height: 4),
                        Text('Capabilities: ${state.capabilities!.serverInfo}'),
                      ],
                    ],
                  ),
                ),

              // Calendar list
              Expanded(
                child: _buildCalendarList(state, viewModel),
              ),

              // Action buttons
              if (state.hasChanges && !state.isLoading)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          await viewModel.resetChanges();
                        },
                        child: const Text('Reset'),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await viewModel.saveChanges();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✅ Saved ${state.selectedCalendars.length} calendar selections and created projects'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.save_rounded),
                        label: Text('Save ${state.selectedCalendars.length} selections'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarList(CalDAVManagementState state, CalDAVManagementViewModel viewModel) {
    if (state.isLoading) {
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

    if (state.error != null) {
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
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => viewModel.initialize(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.capabilities == null || state.capabilities!.taskCalendars.isEmpty) {
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
                state.capabilities == null ? 'No calendars discovered' : 'No task calendars found',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.capabilities == null 
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
      itemCount: state.capabilities!.taskCalendars.length,
      itemBuilder: (context, index) {
        final calendar = state.capabilities!.taskCalendars[index];
        final isSelected = viewModel.isCalendarSelected(calendar);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (_) => viewModel.toggleCalendarSelection(calendar),
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
