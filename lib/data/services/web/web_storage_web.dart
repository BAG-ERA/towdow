import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> clearLocalStorage() async {
  try {
    web.window.localStorage.clear();
  } catch (_) {}
  try {
    web.window.sessionStorage.clear();
  } catch (_) {}
}

