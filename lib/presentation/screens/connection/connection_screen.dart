// Connection screen for CalDAV account setup
// Onboarding screen for configuring server connections

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/custom_caldav_dialog.dart';
import 'widgets/towdow_cloud_dialog.dart';
import 'widgets/towdow_self_hosted_dialog.dart';

class ConnectionScreen extends ConsumerWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to CalDAV')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Connect your CalDAV Account',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a provider to sync your tasks and projects',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _ConnectionOptionCard(
              title: 'TowDow Cloud',
              subtitle: 'Official TowDow hosting',
              icon: Icons.cloud_rounded,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const TowdowCloudDialog(),
                );
              },
            ),
            const SizedBox(height: 16),
            _ConnectionOptionCard(
              title: 'TowDow self hosted',
              subtitle: 'Bring your own TowDow',
              icon: Icons.account_circle_rounded,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const TowdowSelfHostedDialog(),
                );
              },
            ),
            const SizedBox(height: 16),
            _ConnectionOptionCard(
              title: 'Custom CalDAV',
              subtitle: 'Any CalDAV server',
              icon: Icons.settings_rounded,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const CustomCaldavDialog(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ConnectionOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded),
        onTap: onTap,
      ),
    );
  }
}
