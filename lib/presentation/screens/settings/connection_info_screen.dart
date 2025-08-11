// Connection Information Screen
// Display user's CalDAV account details and connection status

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/caldav_account.dart';
import '../../../data/providers/providers.dart';

class ConnectionInfoScreen extends ConsumerWidget {
  const ConnectionInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(activeAccountProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Information'),
      ),
      body: accountAsync.when(
        data: (account) {
          if (account == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No CalDAV account connected',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return _buildAccountInfo(context, account);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_rounded,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading account: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountInfo(BuildContext context, CaldavAccount account) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // User Information Section
        _InfoSection(
          title: 'User Information',
          icon: Icons.person_rounded,
          children: [
            if (account.firstName != null || account.lastName != null)
              _InfoItem(
                label: 'Full Name (CN)',
                value: '${account.firstName ?? ''} ${account.lastName ?? ''}'.trim(),
                icon: Icons.badge_rounded,
              ),
            if (account.email != null)
              _InfoItem(
                label: 'Email Address',
                value: account.email!,
                icon: Icons.email_rounded,
                copyable: true,
              ),
            _InfoItem(
              label: 'Username',
              value: account.username,
              icon: Icons.account_circle_rounded,
              copyable: true,
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Server Information Section
        _InfoSection(
          title: 'Server Information',
          icon: Icons.dns_rounded,
          children: [
            _InfoItem(
              label: 'Server URL',
              value: account.serverUrl,
              icon: Icons.link_rounded,
              copyable: true,
            ),
            _InfoItem(
              label: 'Provider Type',
              value: _formatProviderType(account.providerType, account.serverUrl),
              icon: Icons.category_rounded,
            ),
            _InfoItem(
              label: 'Authentication',
              value: _getAuthType(account),
              icon: Icons.security_rounded,
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Connection Status Section
        _InfoSection(
          title: 'Connection Status',
          icon: Icons.wifi_rounded,
          children: [
            _InfoItem(
              label: 'Status',
              value: account.isActive ? 'Active' : 'Inactive',
              icon: account.isActive ? Icons.check_circle_rounded : Icons.error_rounded,
              valueColor: account.isActive ? Colors.green : Colors.red,
            ),
            _InfoItem(
              label: 'Account Created',
              value: DateFormat('MMM dd, yyyy - HH:mm').format(account.createdAt),
              icon: Icons.event_rounded,
            ),
            _InfoItem(
              label: 'Last Sync',
              value: DateFormat('MMM dd, yyyy - HH:mm').format(account.lastSyncAt),
              icon: Icons.sync_rounded,
            ),
            if (account.tokenExpiry != null)
              _InfoItem(
                label: 'Token Expires',
                value: DateFormat('MMM dd, yyyy - HH:mm').format(account.tokenExpiry!),
                icon: Icons.schedule_rounded,
                valueColor: account.tokenExpiry!.isBefore(DateTime.now()) ? Colors.red : null,
              ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Account ID (for debugging)
        _InfoSection(
          title: 'Technical Details',
          icon: Icons.info_rounded,
          children: [
            _InfoItem(
              label: 'Account ID',
              value: account.id,
              icon: Icons.fingerprint_rounded,
              copyable: true,
            ),
          ],
        ),
      ],
    );
  }

  String _formatProviderType(String providerType, String serverUrl) {
    // Detect offline-only via localhost URL hint
    if (serverUrl.startsWith('https://localhost') || serverUrl.startsWith('http://localhost')) {
      return 'Offline only';
    }
    switch (providerType.toLowerCase()) {
      case 'towdow_cloud':
        return 'TowDow Cloud';
      case 'google':
        return 'Google Calendar';
      case 'nextcloud':
        return 'Nextcloud';
      case 'custom':
        return 'Custom CalDAV';
      default:
        return providerType;
    }
  }

  String _getAuthType(CaldavAccount account) {
    if (account.serverUrl.startsWith('https://localhost') || account.serverUrl.startsWith('http://localhost')) {
      return 'None (offline mode)';
    }
    if (account.accessToken != null) {
      return 'OAuth 2.0';
    } else if (account.password != null) {
      return 'Basic Authentication';
    } else {
      return 'Unknown';
    }
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _InfoSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool copyable;
  final Color? valueColor;

  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
    this.copyable = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (copyable)
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              iconSize: 20,
              onPressed: () => _copyToClipboard(context, value),
              tooltip: 'Copy to clipboard',
            ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "$text" to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
