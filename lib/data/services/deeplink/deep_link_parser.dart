// Deep link parser
// Converts incoming URIs (towdow://, https://towdow.app, and https://web.towdow.app) into DeepLinkTarget

import 'package:equatable/equatable.dart';
import '../../services/deeplink/deep_link_models.dart';
import '../../../core/logger.dart';

class DeepLinkParser extends Equatable {
  const DeepLinkParser();

  /// Parse a raw URI string into a DeepLinkTarget. Returns null if unsupported.
  DeepLinkTarget? parse(String raw) {
    if (raw.isEmpty) return null;
    Uri? uri;
    try {
      uri = Uri.parse(raw);
    } catch (e) {
      AppLogger.warning('DeepLinkParser: invalid URI: $raw');
      return null;
    }

    // Accept custom scheme towdow:// and web https://towdow.app and https://web.towdow.app
    if (uri.scheme == 'towdow') {
      return _parseTowdowScheme(uri);
    }
    if (uri.scheme == 'https' && (uri.host == 'towdow.app' || uri.host == 'www.towdow.app' || uri.host == 'web.towdow.app')) {
      // Map https://towdow.app/<path> and https://web.towdow.app/<path> to same route segments
      return _parsePath(uri.pathSegments, uri.queryParameters);
    }
    return null;
  }

  DeepLinkTarget? _parseTowdowScheme(Uri uri) {
    // Support canonical: towdow://app/<route>
    // and shortcuts: towdow://<route>
    final segments = <String>[];
    if (uri.host.isNotEmpty && uri.host != 'app') {
      // Treat host as first segment for shortcut like towdow://projects
      segments.add(uri.host);
      segments.addAll(uri.pathSegments);
    } else {
      // host empty or 'app'
      segments.addAll(uri.pathSegments);
    }
    return _parsePath(segments, uri.queryParameters);
  }

  DeepLinkTarget? _parsePath(List<String> segments, Map<String, String> query) {
    if (segments.isEmpty) return null;
    final head = segments.first;

    switch (head) {
      case 'projects':
        return DeepLinkTarget(kind: DeepLinkKind.projects, query: query);
      case 'project':
        if (segments.length >= 2) {
          // path portion might be encoded by the producer; we preserve as-is
          final encodedPath = segments.sublist(1).join('/');
          return DeepLinkTarget(kind: DeepLinkKind.project, path: Uri.decodeComponent(encodedPath), query: query);
        }
        return null;
      case 'workflows':
        return DeepLinkTarget(kind: DeepLinkKind.workflows, query: query);
      case 'workflow':
        if (segments.length >= 2) {
          final encodedPath = segments.sublist(1).join('/');
          return DeepLinkTarget(kind: DeepLinkKind.workflow, path: Uri.decodeComponent(encodedPath), query: query);
        }
        return null;
      case 'today':
        return DeepLinkTarget(kind: DeepLinkKind.today, query: query);
      case 'soon':
        return DeepLinkTarget(kind: DeepLinkKind.soon, query: query);
      case 'anytime':
        return DeepLinkTarget(kind: DeepLinkKind.anytime, query: query);
      case 'next-week':
        return DeepLinkTarget(kind: DeepLinkKind.nextWeek, query: query);
      case 'later':
        return DeepLinkTarget(kind: DeepLinkKind.later, query: query);
      case 'settings':
        return DeepLinkTarget(kind: DeepLinkKind.settings, query: query);
      case 'connect':
        return DeepLinkTarget(kind: DeepLinkKind.connect, query: query);
      default:
        AppLogger.warning('DeepLinkParser: unknown route head="$head" segments=$segments');
        return null;
    }
  }

  @override
  List<Object?> get props => [];
}


