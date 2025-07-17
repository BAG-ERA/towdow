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
import '../../../data/models/task_calendar.dart';
import '../../../core/logger.dart';

class CalDAVManagementScreen extends ConsumerStatefulWidget {
  const CalDAVManagementScreen({super.key});

  @override
  ConsumerState<CalDAVManagementScreen> createState() => _CalDAVManagementScreenState();
}

class _CalDAVManagementScreenState extends ConsumerState<CalDAVManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize the ViewModel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(caldavManagementViewModelProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    return Column(
      children: [
        // Select All / Deselect All buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  viewModel.selectAllCalendars();
                },
                icon: const Icon(Icons.select_all_rounded),
                label: const Text('Select All'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  viewModel.deselectAllCalendars();
                },
                icon: const Icon(Icons.deselect_rounded),
                label: const Text('Deselect All'),
              ),
            ],
          ),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => viewModel.updateSearchQuery(value),
            decoration: InputDecoration(
              hintText: 'Search calendars...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: state.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        viewModel.updateSearchQuery('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        // Calendar list
        Expanded(
          child: viewModel.filteredCalendars.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No calendars found',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search term',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: viewModel.filteredCalendars.length,
                  itemBuilder: (context, index) {
                    final calendar = viewModel.filteredCalendars[index];
              final isSelected = viewModel.isCalendarSelected(calendar);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: (_) => viewModel.toggleCalendarSelection(calendar),
                  ),
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
                      // Domain and State information
                      if (calendar.flowitDomain != null || calendar.flowitStatus != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (calendar.flowitDomain != null) ...[
                              Icon(Icons.domain_rounded, size: 14, color: Colors.blue[600]),
                              const SizedBox(width: 4),
                              Text(
                                'Domain: ${calendar.flowitDomain}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (calendar.flowitStatus != null) const SizedBox(width: 12),
                            ],
                            if (calendar.flowitStatus != null) ...[
                              Icon(Icons.flag_rounded, size: 14, color: Colors.purple[600]),
                              const SizedBox(width: 4),
                              Text(
                                'State: ${calendar.flowitStatus}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.purple[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCalendarStatusChip(calendar),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.archive_rounded, color: Colors.grey[600]),
                        onPressed: () => _showArchiveConfirmation(context, calendar, viewModel),
                        tooltip: 'Archive calendar',
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                        onPressed: () => _showDeleteConfirmation(context, calendar, viewModel),
                        tooltip: 'Delete calendar permanently',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarStatusChip(TaskCalendar calendar) {
    // Determine calendar status - prioritize archived status first
    String statusText;
    Color statusColor;
    IconData statusIcon;



    // More robust archived detection
    bool isArchivedStatus = calendar.isArchived || 
                           (calendar.flowitStatus?.toLowerCase().contains('archive') == true) ||
                           (calendar.flowitStatus?.toLowerCase() == 'archived');

    if (isArchivedStatus) {
      statusText = 'Archived';
      statusColor = Colors.grey;
      statusIcon = Icons.archive_rounded;
    } else if (_isCalendarOnline(calendar)) {
      statusText = 'Online';
      statusColor = Colors.green;
      statusIcon = Icons.cloud_sync_rounded;
    } else {
      statusText = 'Local Only';
      statusColor = Colors.orange;
      statusIcon = Icons.computer_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 14,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Determine if a calendar is online (synchronized with CalDAV server)
  bool _isCalendarOnline(TaskCalendar calendar) {
    // In the CalDAV management screen context, all calendars are discovered
    // from the server via CalDAV discovery, so they should be considered "Online"
    // 
    // The only exception would be if this is a calendar that needs to be created
    // (indicated by specific patterns in the description or path)
    
    // Check if this is a "to be created" calendar
    final isToBeCreated = calendar.description.contains('to be created') ||
                         calendar.path.contains('flowit-tasks') && 
                         calendar.description.contains('Default task calendar');
    
    // If it's marked as "to be created", it's local only until created
    if (isToBeCreated) {
      return false;
    }
    
    // All other calendars in this context are from server discovery
    return true;
  }

  Future<void> _showArchiveConfirmation(BuildContext context, TaskCalendar calendar, CalDAVManagementViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Calendar'),
        content: Text(
          'Are you sure you want to archive "${calendar.displayName}"?\n\n'
          'This will move the calendar to the archived projects section. '
          'You can unarchive it later from the archived projects screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed && mounted) {
      await viewModel.archiveCalendar(calendar);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Archived calendar "${calendar.displayName}"'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context, TaskCalendar calendar, CalDAVManagementViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Calendar'),
        content: Text(
          'Are you sure you want to delete "${calendar.displayName}"?\n\n'
          'This will permanently delete the calendar from both the server and local storage. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed && mounted) {
      await viewModel.deleteCalendar(calendar);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Deleted calendar "${calendar.displayName}"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
