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
import 'package:towdow_app/l10n/app_localizations.dart';

class ExternalCalendarManagementScreen extends ConsumerStatefulWidget {
  const ExternalCalendarManagementScreen({super.key});

  @override
  ConsumerState<ExternalCalendarManagementScreen> createState() => _ExternalCalendarManagementScreenState();
}

class _ExternalCalendarManagementScreenState extends ConsumerState<ExternalCalendarManagementScreen> {
  // Local progress indicator for dialog actions
  // ignore: unused_field
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.externalCalendars),
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCalendarDialog,
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.addCalendar),
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
                  AppLocalizations.of(context)!.errorLoadingExternalCalendars,
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
                  child: Text(AppLocalizations.of(context)!.retry),
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
    ref.watch(externalCalendarViewModelProvider);
    return StreamBuilder<List<ExternalCaldavAccount>>(
      stream: ref.read(externalCalendarViewModelProvider.notifier).accountsStream,
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
            AppLocalizations.of(context)!.noExternalCalendars,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.externalCalendarsExplainer,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddCalendarDialog,
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.addCalendar),
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
                  Text(account.isActive ? AppLocalizations.of(context)!.disable : AppLocalizations.of(context)!.enable),
                ],
              ),
            ),

            PopupMenuItem(
              value: 'sync',
              child: Row(
                children: [
                  Icon(Icons.sync),
                  SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.syncNow),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.delete, style: TextStyle(color: Colors.red)),
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
          _buildDetailRow(AppLocalizations.of(context)!.server, account.serverUrl),
          _buildDetailRow(AppLocalizations.of(context)!.username, account.username),
          _buildDetailRow(AppLocalizations.of(context)!.authType, account.authType.name),
          if (account.lastSyncAt != null)
            _buildDetailRow(AppLocalizations.of(context)!.lastSync, _formatDateTime(account.lastSyncAt!)),
          if (account.lastSuccessfulSync != null)
            _buildDetailRow(AppLocalizations.of(context)!.lastSuccess, _formatDateTime(account.lastSuccessfulSync!)),
          _buildDetailRow(AppLocalizations.of(context)!.totalCalendars, account.totalCalendars.toString()),
          _buildDetailRow(AppLocalizations.of(context)!.totalEvents, account.totalEvents.toString()),
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
          return Text(AppLocalizations.of(context)!.noCalendarsFound);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppLocalizations.of(context)!.calendars}:',
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
        subtitle: Text(calendar.color != null ? '${AppLocalizations.of(context)!.color}: ${calendar.color}' : AppLocalizations.of(context)!.noColorSet),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.color_lens, size: 20),
              onPressed: () => _showColorPicker(calendar),
              tooltip: AppLocalizations.of(context)!.changeColor,
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

  // Removed: _watchExternalAccounts is now unused; StreamBuilder reads directly from VM

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
    await ref.read(externalCalendarViewModelProvider.notifier).toggleAccount(account);
    setState(() => _isLoading = false);
  }


  Future<void> _syncAccount(ExternalCaldavAccount account) async {
    setState(() => _isLoading = true);
    await ref.read(externalCalendarViewModelProvider.notifier).syncAccount(account.id);
    setState(() => _isLoading = false);
  }

  Future<void> _deleteAccount(ExternalCaldavAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteExternalCalendar),
        content: Text(AppLocalizations.of(context)!.areYouSureDeleteExternalCalendar(account.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() => _isLoading = true);
    await ref.read(externalCalendarViewModelProvider.notifier).deleteAccount(account);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleCalendar(ExternalCalendar calendar, bool enabled) async {
    await ref.read(externalCalendarViewModelProvider.notifier).toggleCalendar(calendar, enabled);
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
        title: Text(AppLocalizations.of(context)!.chooseColorFor(calendar.displayName)),
        content: SizedBox(
          width: 300,
          child: GridView.builder(
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
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          if (calendar.color != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop('remove'),
              child: Text(AppLocalizations.of(context)!.removeColor),
            ),
        ],
      ),
    );

    if (selectedColor != null && mounted) {
      await _updateCalendarColor(calendar, selectedColor == 'remove' ? null : selectedColor);
    }
  }

  Future<void> _updateCalendarColor(ExternalCalendar calendar, String? color) async {
    await ref.read(externalCalendarViewModelProvider.notifier).updateCalendarColor(calendar, color);
    if (mounted) setState(() {});
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 