// Shared body component for list screens
// Handles loading, error, empty states and provides consistent list structure

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:towdow_app/l10n/app_localizations.dart';

class ListScreenBody extends ConsumerWidget {
  final bool isLoading;
  final String? error;
  final bool isEmpty;
  final String emptyTitle;
  final String emptyDescription;
  final IconData emptyIcon;
  final Future<void> Function() onRefresh;
  final Widget child;
  final Widget? explanationHeader;

  const ListScreenBody({
    super.key,
    required this.isLoading,
    this.error,
    required this.isEmpty,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.emptyIcon,
    required this.onRefresh,
    required this.child,
    this.explanationHeader,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded, 
              size: 64, 
              color: Theme.of(context).colorScheme.error
            ),
            const SizedBox(height: 16),
            Text(
              '${AppLocalizations.of(context)!.failedToLoad} $emptyTitle', 
              style: Theme.of(context).textTheme.headlineSmall
            ),
            const SizedBox(height: 8),
            Text(
              error!, 
              style: Theme.of(context).textTheme.bodyMedium, 
              textAlign: TextAlign.center
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRefresh,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      );
    }

    if (isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon, 
              size: 64, 
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noneFound(emptyTitle.toLowerCase()), 
              style: Theme.of(context).textTheme.headlineSmall
            ),
            const SizedBox(height: 8),
            Text(
              emptyDescription,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          child,
          if (explanationHeader != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: explanationHeader!,
            ),
          ],
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}
