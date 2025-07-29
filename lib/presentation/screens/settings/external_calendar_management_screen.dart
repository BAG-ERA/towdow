// External calendar management screen
// Allows users to add, remove, and manage external CalDAV calendars
// Part of the Integration section in settings

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logger.dart';
import '../../../core/theme/chart_theme.dart';
import '../../../data/models/external_caldav_account.dart';
import '../../../data/models/external_calendar.dart';
import '../../../data/providers/providers.dart';
import '../../widgets/utils/popup/external_calendar_setup_dialog.dart';

class ExternalCalendarManagementScreen extends ConsumerStatefulWidget {
  const ExternalCalendarManagementScreen({super.key});

  @override
  ConsumerState<ExternalCalendarManagementScreen> createState() => _ExternalCalendarManagementScreenState();
}

class _ExternalCalendarManagementScreenState extends ConsumerState<ExternalCalendarManagementScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('External Calendars'),
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCalendarDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Calendar'),
      ),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<void>(
      future: _loadData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading external calendars',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        return _buildAccountsList();
      },
    );
  }

  Widget _buildAccountsList() {
    return StreamBuilder<List<ExternalCaldavAccount>>(
      stream: _watchExternalAccounts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final accounts = snapshot.data!;
        
        if (accounts.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final account = accounts[index];
            return _buildAccountCard(account);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_view_month_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No External Calendars',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add external CalDAV calendars to sync your events',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddCalendarDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Calendar'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(ExternalCaldavAccount account) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(
          account.isActive ? Icons.cloud_done : Icons.cloud_off,
          color: account.isActive ? Colors.green : Colors.grey,
        ),
        title: Text(
          account.displayName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(account.serverUrl),
            if (account.lastSyncError != null) ...[
              const SizedBox(height: 4),
              Text(
                'Error: ${account.lastSyncError}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleAccountAction(account, value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(account.isActive ? Icons.pause : Icons.play_arrow),
                  const SizedBox(width: 8),
                  Text(account.isActive ? 'Disable' : 'Enable'),
                ],
              ),
            ),

            const PopupMenuItem(
              value: 'sync',
              child: Row(
                children: [
                  Icon(Icons.sync),
                  SizedBox(width: 8),
                  Text('Sync Now'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        children: [
          _buildAccountDetails(account),
        ],
      ),
    );
  }

  Widget _buildAccountDetails(ExternalCaldavAccount account) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Server', account.serverUrl),
          _buildDetailRow('Username', account.username),
          _buildDetailRow('Auth Type', account.authType.name),
          if (account.lastSyncAt != null)
            _buildDetailRow('Last Sync', _formatDateTime(account.lastSyncAt!)),
          if (account.lastSuccessfulSync != null)
            _buildDetailRow('Last Success', _formatDateTime(account.lastSuccessfulSync!)),
          _buildDetailRow('Total Calendars', account.totalCalendars?.toString() ?? '0'),
          _buildDetailRow('Total Events', account.totalEvents?.toString() ?? '0'),
          const SizedBox(height: 16),
          _buildCalendarsList(account),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarsList(ExternalCaldavAccount account) {
    return FutureBuilder<List<ExternalCalendar>>(
      future: _getCalendarsForAccount(account.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final calendars = snapshot.data!;
        
        if (calendars.isEmpty) {
          return const Text('No calendars found');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calendars:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...calendars.map((calendar) => _buildCalendarRow(calendar)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildCalendarRow(ExternalCalendar calendar) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: calendar.color != null 
                ? Color(int.parse(calendar.color!.replaceFirst('#', '0xFF')))
                : Colors.grey.shade300,
            border: Border.all(
              color: calendar.isEnabled ? Colors.black26 : Colors.grey.shade400,
              width: 1,
            ),
          ),
          child: calendar.isEnabled 
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
        title: Text(calendar.displayName),
        subtitle: Text(calendar.color != null ? 'Color: ${calendar.color}' : 'No color set'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.color_lens, size: 20),
              onPressed: () => _showColorPicker(calendar),
              tooltip: 'Change color',
            ),
            Switch(
              value: calendar.isEnabled,
              onChanged: (value) => _toggleCalendar(calendar, value),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    // This is called by FutureBuilder to ensure data is loaded
    // The actual data loading is handled by the stream builders
  }

  Stream<List<ExternalCaldavAccount>> _watchExternalAccounts() {
    try {
      final repository = ref.read(externalAccountRepositoryProvider);
      return repository.watchAccounts();
    } catch (e) {
      AppLogger.error('ExternalCalendarManagementScreen: Error watching accounts: $e');
      return Stream.value([]);
    }
  }

  Future<List<ExternalCalendar>> _getCalendarsForAccount(String accountId) async {
    try {
      final repository = ref.read(externalCalendarRepositoryProvider);
      final result = await repository.getCalendarsByAccount(accountId);
      return result.when(
        success: (calendars) => calendars,
        failure: (failure) {
          AppLogger.error('ExternalCalendarManagementScreen: Error getting calendars: ${failure.message}');
          return [];
        },
      );
    } catch (e) {
      AppLogger.error('ExternalCalendarManagementScreen: Error getting calendars: $e');
      return [];
    }
  }

  Future<void> _showAddCalendarDialog() async {
    final result = await showDialog<ExternalCaldavAccount>(
      context: context,
      builder: (context) => const ExternalCalendarSetupDialog(),
    );

    if (result != null && mounted) {
      
      // Refresh the data
      setState(() {});
    }
  }

  Future<void> _handleAccountAction(ExternalCaldavAccount account, String action) async {
    switch (action) {
      case 'toggle':
        await _toggleAccount(account);
        break;

      case 'sync':
        await _syncAccount(account);
        break;
      case 'delete':
        await _deleteAccount(account);
        break;
    }
  }

  Future<void> _toggleAccount(ExternalCaldavAccount account) async {
    setState(() => _isLoading = true);
    
    try {
      final repository = ref.read(externalAccountRepositoryProvider);
      final result = await repository.setActive(account.id, !account.isActive);
      
      result.when(
        success: (_) async {
        },
        failure: (failure) {
          AppLogger.error('Failed to toggle account: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('Failed to toggle account: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _syncAccount(ExternalCaldavAccount account) async {
    setState(() => _isLoading = true);
    
    try {
      final syncService = ref.read(externalCalendarSyncServiceProvider);
      final result = await syncService.syncAccount(account.id);
      
      result.when(
        success: (_) {
          // Sync completed successfully - no notification needed
        },
        failure: (failure) {
          AppLogger.error('Sync failed: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('Sync error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount(ExternalCaldavAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete External Calendar'),
        content: Text(
          'Are you sure you want to delete "${account.displayName}"?\n\n'
          'This will remove all associated calendars and events.',
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

    if (!confirmed) return;

    setState(() => _isLoading = true);
    
    try {
      // Perform cascading deletion to clean up all associated data
      final accountRepository = ref.read(externalAccountRepositoryProvider);
      final calendarRepository = ref.read(externalCalendarRepositoryProvider);
      final eventRepository = ref.read(externalEventRepositoryProvider);
      
      AppLogger.info('ExternalCalendarManagement: Starting cascading deletion for account ${account.id}');
      
      // Step 1: Delete all events for this account
      final deleteEventsResult = await eventRepository.deleteByAccount(account.id);
      deleteEventsResult.when(
        success: (_) => AppLogger.info('ExternalCalendarManagement: Deleted events for account ${account.id}'),
        failure: (failure) => throw Exception('Failed to delete events: ${failure.message}'),
      );
      
      // Step 2: Delete all calendars for this account  
      final deleteCalendarsResult = await calendarRepository.deleteCalendarsByAccount(account.id);
      deleteCalendarsResult.when(
        success: (_) => AppLogger.info('ExternalCalendarManagement: Deleted calendars for account ${account.id}'),
        failure: (failure) => throw Exception('Failed to delete calendars: ${failure.message}'),
      );
      
      // Step 3: Delete the account itself
      final deleteAccountResult = await accountRepository.delete(account.id);
      deleteAccountResult.when(
        success: (_) => AppLogger.info('ExternalCalendarManagement: Deleted account ${account.id}'),
        failure: (failure) => throw Exception('Failed to delete account: ${failure.message}'),
      );
      
      // Note: User data upload is handled by queue system during background sync
      // No need to upload here as it will be handled automatically
      
      // Success
      if (mounted) {
      }
      
    } catch (e) {
      AppLogger.error('ExternalCalendarManagement: Failed to delete account ${account.id}', e, StackTrace.current);
      if (mounted) {
        AppLogger.error('Error deleting calendar: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleCalendar(ExternalCalendar calendar, bool enabled) async {
    try {
      final repository = ref.read(externalCalendarRepositoryProvider);
      final result = await repository.setEnabled(calendar.id, enabled);
      
      result.when(
        success: (_) {
        },
        failure: (failure) {
          AppLogger.error('Failed to toggle calendar: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('Failed to toggle calendar: $e');
    }
  }

  Future<void> _showColorPicker(ExternalCalendar calendar) async {
    // FlowIt brand color palette from chart theme
    final colors = [
      // Blue family
      FlowItColors.blueDark,
      FlowItColors.blue,
      FlowItColors.blueMedium, // Primary
      FlowItColors.blueLight,
      
      // Water Green family
      FlowItColors.waterGreen,
      FlowItColors.waterGreenLight,
      
      // Violet family
      FlowItColors.violetDark,
      FlowItColors.violet,
      FlowItColors.violetLight,
      
      // Green family
      FlowItColors.greenApple,
      FlowItColors.greenAnis,
      FlowItColors.greenLight,
      
      // Red/Pink family
      FlowItColors.pink,
      FlowItColors.pinkLight,
      FlowItColors.coral,
      
      // Yellow family
      FlowItColors.yellowDark,
      FlowItColors.yellow,
      FlowItColors.yellowLight,
      
      // Additional Material colors for variety
      const Color(0xFFE57373), // Material Red
      const Color(0xFFF06292), // Material Pink
      const Color(0xFFBA68C8), // Material Purple
      const Color(0xFF9575CD), // Material Deep Purple
      const Color(0xFF4DD0E1), // Material Cyan
      const Color(0xFF4DB6AC), // Material Teal
      const Color(0xFFA1887F), // Material Brown
      const Color(0xFF90A4AE), // Material Blue Grey
    ];

    final selectedColor = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choose color for "${calendar.displayName}"'),
        content: SizedBox(
          width: 300,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: colors.length,
            itemBuilder: (context, index) {
              final color = colors[index];
              final colorHex = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
              final isSelected = calendar.color == colorHex;
              
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(colorHex),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected 
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (calendar.color != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop('remove'),
              child: const Text('Remove Color'),
            ),
        ],
      ),
    );

    if (selectedColor != null && mounted) {
      await _updateCalendarColor(calendar, selectedColor == 'remove' ? null : selectedColor);
    }
  }

  Future<void> _updateCalendarColor(ExternalCalendar calendar, String? color) async {
    try {
      final repository = ref.read(externalCalendarRepositoryProvider);
      final updatedCalendar = calendar.copyWith(
        color: color,
        lastModified: DateTime.now(),
      );
      
      final result = await repository.save(updatedCalendar);
      
      result.when(
        success: (_) {
          // Color updated successfully - no notification needed
          // Refresh the UI
          setState(() {});
        },
        failure: (failure) {
          AppLogger.error('Failed to update color: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('Failed to update color: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 