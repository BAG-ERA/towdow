// Web utilities for the application with conditional exports
// This file ensures web-specific code is only imported on web platform

import 'web_utils_stub.dart'
    if (dart.library.js) 'web_utils_web.dart';

// Re-export all utilities
export 'web_utils_stub.dart'
    if (dart.library.js) 'web_utils_web.dart';
