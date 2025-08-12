@JS()
library web_storage_interop;

import 'package:js/js.dart';
import 'package:js/js_util.dart';

@JS('localStorage.clear')
external void _clearLocalStorage();

Future<void> clearLocalStorage() async {
  _clearLocalStorage();
}

