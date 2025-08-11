// User account badge shown at the top of the navbar
// Displays the active account's avatar (initials), name and email

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/caldav_account.dart';
import '../../../data/providers/providers.dart';
import '../adaptive_app_layout.dart';

class UserAccountBadge extends ConsumerWidget {
  const UserAccountBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(activeAccountProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;

    return accountAsync.when(
      data: (account) {
        if (account == null) return const SizedBox.shrink();
        if (!isDesktop) {
          return _buildMobileGear(context, ref);
        }
        return _buildBadge(context, ref, account);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBadge(BuildContext context, WidgetRef ref, CaldavAccount account) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = _displayName(account);
    final email = account.email ?? account.username;
    final initials = _initialsFromName(name.isNotEmpty ? name : email);

    final borderRadius = BorderRadius.circular(12);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () {
            context.go('/settings');
            _closeDrawerIfMobile(context, ref);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: borderRadius,
            ),
            child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                initials,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name.isNotEmpty ? name : email,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (name.isNotEmpty && email.isNotEmpty)
                    Text(
                      email,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Settings',
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () {
                    context.go('/settings');
                    _closeDrawerIfMobile(context, ref);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.settings_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileGear(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Tooltip(
          message: 'Settings',
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () {
                context.go('/settings');
                _closeDrawerIfMobile(context, ref);
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  Icons.settings_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _displayName(CaldavAccount account) {
    final parts = [account.firstName, account.lastName]
        .where((e) => e != null && e.trim().isNotEmpty)
        .map((e) => e!.trim())
        .toList();
    return parts.join(' ');
  }

  String _initialsFromName(String input) {
    final words = input.trim().split(RegExp(r"\s+"));
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.isNotEmpty ? words.first.substring(0, 1).toUpperCase() : '?';
    }
    final first = words.first.isNotEmpty ? words.first.substring(0, 1) : '';
    final last = words.last.isNotEmpty ? words.last.substring(0, 1) : '';
    final combined = (first + last).toUpperCase();
    return combined.isNotEmpty ? combined : '?';
  }

  void _closeDrawerIfMobile(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;
    if (!isDesktop) {
      final closeDrawer = ref.read(drawerControllerProvider);
      closeDrawer?.call();
    }
  }
}


