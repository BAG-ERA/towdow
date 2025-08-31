// Deep link command
// Consumes DeepLinkTarget and performs navigation with GoRouter

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/providers.dart';
import '../../../data/services/deeplink/deep_link_models.dart';
import '../../../core/logger.dart';
import '../../../app.dart';

final pendingDeepLinkProvider = StateProvider<DeepLinkTarget?>((ref) => null);

class HandleDeepLinkCommand {
  HandleDeepLinkCommand(this._ref);
  final Ref _ref;

  Future<void> handle(DeepLinkTarget target) async {
    try {
      final hasAccount = await _ref.read(hasActiveAccountProvider.future).catchError((_) => false);
      final router = _ref.read(routerProvider);

      final destination = _mapTargetToRoute(target);

      if (!hasAccount && destination != '/connect') {
        _ref.read(pendingDeepLinkProvider.notifier).state = target;
        AppLogger.info('DeepLinkCommand: No account, redirecting to /connect and storing pending target');
        router.go('/connect');
        return;
      }

      AppLogger.info('DeepLinkCommand: Navigating to $destination');
      router.go(destination);
    } catch (e) {
      AppLogger.warning('DeepLinkCommand: failed to handle deep link: $e');
    }
  }

  String _mapTargetToRoute(DeepLinkTarget t) {
    switch (t.kind) {
      case DeepLinkKind.projects:
        return '/projects';
      case DeepLinkKind.project: {
        final enc = Uri.encodeComponent(t.path ?? '');
        final qp = _queryString(t.query);
        return '/project/$enc$qp';
      }
      case DeepLinkKind.workflows:
        return '/workflows';
      case DeepLinkKind.workflow: {
        final enc = Uri.encodeComponent(t.path ?? '');
        final qp = _queryString(t.query);
        return '/workflow/$enc$qp';
      }
      case DeepLinkKind.today:
        return '/today';
      case DeepLinkKind.soon:
        return '/soon';
      case DeepLinkKind.anytime:
        return '/anytime';
      case DeepLinkKind.nextWeek:
        return '/next-week';
      case DeepLinkKind.later:
        return '/later';
      case DeepLinkKind.settings:
        return '/settings';
      case DeepLinkKind.connect:
        return '/connect';
    }
  }

  String _queryString(Map<String, String> query) {
    if (query.isEmpty) return '';
    final params = query.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
    return '?$params';
  }
}


