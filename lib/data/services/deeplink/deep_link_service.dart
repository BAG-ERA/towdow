// Deep link service
// Unifies platform sources into a single initial-link and stream API

import 'dart:async';
import 'package:app_links/app_links.dart' as app_links;

import 'deep_link_models.dart';
import 'deep_link_parser.dart';
import '../../../core/logger.dart';

/// Abstraction for deep link delivery
abstract class DeepLinkService {
  Future<DeepLinkTarget?> getInitialLink();
  Stream<DeepLinkTarget> get linkStream;
  void dispose();
}

class PlatformDeepLinkService implements DeepLinkService {
  final DeepLinkParser _parser;

  // We keep a single controller to multicast parsed targets
  final StreamController<DeepLinkTarget> _controller = StreamController.broadcast();
  StreamSubscription? _appLinksSub;

  PlatformDeepLinkService({DeepLinkParser? parser}) : _parser = parser ?? const DeepLinkParser() {
    _initializeListeners();
  }

  void _initializeListeners() {
    try {
      _appLinksSub = _AppLinksBridge.instance.uriLinkStream.listen((uri) {
        _onIncomingUri(uri);
      });
    } catch (e) {
      AppLogger.warning('DeepLinkService: app links listener not initialized: $e');
    }
  }

  @override
  Future<DeepLinkTarget?> getInitialLink() async {
    // app_links emits the initial link as the first event on uriLinkStream.
    // We rely on the stream subscription in _initializeListeners; no separate initial fetch.
    return null;
  }

  @override
  Stream<DeepLinkTarget> get linkStream => _controller.stream;

  @override
  void dispose() {
    _appLinksSub?.cancel();
    _controller.close();
  }

  // region helpers
  // Reserved for future direct calls if needed (kept for API symmetry)
  // ignore: unused_element
  dynamic _getAppLinksInstance() => _AppLinksBridge.instance;

  void _onIncomingUri(Uri uri) {
    final parsed = _parser.parse(uri.toString());
    if (parsed != null) {
      AppLogger.info('DeepLinkService: incoming link: $uri');
      _controller.add(parsed);
    } else {
      AppLogger.warning('DeepLinkService: unsupported link: $uri');
    }
  }
  // endregion
}

// A tiny bridge to isolate direct imports to one place
// This keeps the rest of the file testable by faking _AppLinksBridge
class _AppLinksBridge {
  _AppLinksBridge._();
  static final _AppLinksBridge instance = _AppLinksBridge._();

  // ignore: library_prefixes
  late final dynamic _appLinks = _createAppLinks();

  dynamic _createAppLinks() {
    // Use actual package import
    // Using a factory to avoid top-level initializers depending on Flutter
    return _RealAppLinks();
  }

  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;
}

// Wrapper around package:app_links to keep surface tiny
// Separated to allow stubbing in tests
class _RealAppLinks {
  // ignore: library_prefixes
  late final app_links.AppLinks _inner;

  _RealAppLinks() {
    _inner = app_links.AppLinks();
  }

  Stream<Uri> get uriLinkStream => _inner.uriLinkStream;
}

 