// Account card widget for displaying user account info and settings access
// Shows connection status and provides quick access to settings

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/providers/providers.dart';
import '../../../data/models/caldav_account.dart';
import '../../../data/services/sync_service.dart';

enum SyncIndicatorState {
  offline,     // Hors ligne
  connected,   // Connecté (mais pas de synchronisation à faire)
  syncing,     // En sync
  error,       // Erreur
}

class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAccountAsync = ref.watch(activeAccountProvider);
    
    return activeAccountAsync.when(
      data: (account) {
        if (account == null) {
          return _buildNoAccountState(context, ref);
        }
        return _buildConnectedState(context, ref, account);
      },
      loading: () => _buildLoadingState(context),
      error: (error, _) => _buildErrorState(context, ref),
    );
  }

  Widget _buildConnectedState(BuildContext context, WidgetRef ref, CaldavAccount account) {
    final syncStatus = ref.watch(currentSyncStatusProvider);
    
    return InkWell(
      onTap: () => context.go('/settings'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(
                    Icons.person_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getDisplayName(account),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                      Text(
                        Uri.parse(account.serverUrl).host,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.go('/settings'),
                  icon: Icon(
                    Icons.settings_rounded,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  tooltip: 'Settings',
                ),
              ],
            ),
            // Sync status indicator at bottom left
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSyncIndicator(context, _getSyncIndicatorState(syncStatus)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getSyncStatusText(syncStatus),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAccountState(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.go('/settings'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.error,
                  child: Icon(
                    Icons.person_off_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Not Connected',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      Text(
                        'Setup required',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.go('/settings'),
                  icon: Icon(
                    Icons.settings_rounded,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  tooltip: 'Open Settings',
                ),
              ],
            ),
            // Offline indicator at bottom left
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSyncIndicator(context, SyncIndicatorState.offline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Offline',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Checking connection...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSyncIndicator(context, SyncIndicatorState.syncing),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Connecting...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.go('/settings'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connection Error',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      Text(
                        'Check settings',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.go('/settings'),
                  icon: Icon(
                    Icons.settings_rounded,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  tooltip: 'Open Settings',
                ),
              ],
            ),
            // Error indicator at bottom left
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSyncIndicator(context, SyncIndicatorState.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Connection Error',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncIndicator(BuildContext context, SyncIndicatorState state) {
    switch (state) {
      case SyncIndicatorState.offline:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey,
            shape: BoxShape.circle,
          ),
        );
      case SyncIndicatorState.connected:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        );
      case SyncIndicatorState.syncing:
        return SizedBox(
          width: 8,
          height: 8,
          child: CircularProgressIndicator(
            strokeWidth: 1,
            color: Colors.blue,
          ),
        );
      case SyncIndicatorState.error:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        );
    }
  }

  SyncIndicatorState _getSyncIndicatorState(SyncStatus syncStatus) {
    switch (syncStatus) {
      case SyncStatus.idle:
        return SyncIndicatorState.connected;
      case SyncStatus.syncing:
        return SyncIndicatorState.syncing;
      case SyncStatus.error:
        return SyncIndicatorState.error;
      case SyncStatus.offline:
        return SyncIndicatorState.offline;
    }
  }

  String _getSyncStatusText(SyncStatus syncStatus) {
    switch (syncStatus) {
      case SyncStatus.idle:
        return 'Connected';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.error:
        return 'Sync Error';
      case SyncStatus.offline:
        return 'Offline';
    }
  }

  String _getDisplayName(CaldavAccount account) {
    // If both first and last names are available, use them
    if (account.firstName != null && account.lastName != null) {
      final firstName = account.firstName!.trim();
      final lastName = account.lastName!.trim();
      if (firstName.isNotEmpty && lastName.isNotEmpty) {
        return '$firstName $lastName';
      }
    }
    
    // If only first name is available
    if (account.firstName != null && account.firstName!.trim().isNotEmpty) {
      return account.firstName!.trim();
    }
    
    // If only last name is available
    if (account.lastName != null && account.lastName!.trim().isNotEmpty) {
      return account.lastName!.trim();
    }
    
    // Fallback to username
    return account.username;
  }
} 
