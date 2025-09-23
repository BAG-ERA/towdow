// Main entry point for FlowIt application
// Sets up ProviderScope, Hive initialization, timezone database, and app routing

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app.dart';

// Import all the adapters for Hive
import 'data/models/task.dart';
import 'data/models/caldav_account.dart';
import 'data/models/task_calendar.dart';
import 'data/models/automated_task.dart';
import 'data/models/attendee.dart';
import 'data/models/user_preferences.dart';
import 'data/models/shared_with_me_project.dart';
import 'data/models/external_calendar.dart';
import 'data/models/external_caldav_account.dart';
import 'data/models/calendar_event.dart';
import 'data/models/offline_file.dart';
import 'data/models/validator.dart';
import 'data/models/category.dart';
import 'data/models/journal.dart';
import 'data/services/user/user_preferences_queue_service.dart';

// Import services and providers
import 'core/logger.dart';
import 'core/result.dart';
import 'data/services/storage/local_storage_service.dart';
import 'data/providers/providers.dart';
// Import conditional web utilities
import 'web/web_utils.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web-specific code for handling authentication and project paths
  // This section only runs on web platforms because the underlying
  // implementations are conditionally imported
  try {
    AppLogger.info("main check KeyCloak code");
    final currentUri = parseCurrentUri();
    AppLogger.info("uri parameters: ${currentUri.queryParameters}");

    // Save sanitized redirect URL (only app URL + optional project) for token exchange
    try {
      final sanitizedRedirect = getRedirectUri();
      WebLocalStorage.setItem('redirectUri', sanitizedRedirect);
      AppLogger.info("Saved redirectUri in localStorage: $sanitizedRedirect");
    } catch (e) {
      AppLogger.error('Failed to save redirectUri in localStorage: $e');
    }

    final authCode = currentUri.queryParameters['code'];
    if (authCode != null) {
      try {
        WebLocalStorage.setItem('authCode', authCode);
        AppLogger.info("authCode saved in localStorage: $authCode");
      } catch (e) {
        AppLogger.error('Magik link, error getting auth code: $e');
      }
    }

    final targetProjectPath = currentUri.queryParameters['project'];
    if (targetProjectPath != null) {
      try {
        WebLocalStorage.setItem('targetProjectPath', targetProjectPath);
        AppLogger.info(
          "targetProjectPath saved in localStorage: $targetProjectPath",
        );
        clearUrl(); // remove the sensitive code from URL
      } catch (e) {
        AppLogger.error('Magik link, error getting target project: $e');
      }
    }

    try {
      clearUrl(); // remove the sensitive code from URL
    } catch (e) {
      AppLogger.error('Magik link, failed to clear url: $e');
    }
  } catch (e) {
    // Ignore errors on non-web platforms
    AppLogger.info('Non-web platform, skipping web-specific initialization');
  }
  
  // Initialize timezone database for proper timezone conversions
  tz.initializeTimeZones();
  AppLogger.info('Main: Timezone database initialized');
  
  // Initialize Hive (boxes will be opened with platform-specific path in LocalStorageService)
  await Hive.initFlutter();
  
  // Register Hive adapters for all models
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(AutomatedTaskAdapter());
  Hive.registerAdapter(CaldavAccountAdapter());
  Hive.registerAdapter(FormQuestionAdapter());
  Hive.registerAdapter(FormQuestionTypeAdapter());
  Hive.registerAdapter(TaskCalendarAdapter());
  
  // Register Attendee-related adapters
  Hive.registerAdapter(AttendeeAdapter());
  Hive.registerAdapter(AttendeeStatusAdapter());
  Hive.registerAdapter(AttendeeRoleAdapter());
  Hive.registerAdapter(CalendarUserTypeAdapter());
  
  // Register User Preferences adapter
  Hive.registerAdapter(UserPreferencesAdapter());
  
  // Register SharedWithMeProject adapter
  Hive.registerAdapter(SharedWithMeProjectAdapter());
  
  // Register External Calendar adapters
  Hive.registerAdapter(ExternalCalendarAdapter());
  Hive.registerAdapter(ExternalCalendarAuthTypeAdapter());
  Hive.registerAdapter(ExternalCaldavAccountAdapter());
  Hive.registerAdapter(CalendarEventAdapter());
  
  // Register Offline File adapters
  Hive.registerAdapter(OfflineFileStatusAdapter());
  Hive.registerAdapter(OfflineFileAdapter());
  // Register File Upload Queue item adapter
  Hive.registerAdapter(FileUploadQueueItemAdapter());
  
  // Register Category adapter
  Hive.registerAdapter(CategoryAdapter());
  // Register Journal adapter
  Hive.registerAdapter(JournalAdapter());
  
  // Register User Preferences Queue adapters
  Hive.registerAdapter(UserPreferencesOperationAdapter());
  Hive.registerAdapter(UserPreferencesQueueItemAdapter());
  
  AppLogger.info('Main: Hive adapters registered successfully');
  
  // Initialize local storage service
  final storageService = LocalStorageService();
  final initResult = await storageService.initialize();
  
  // Ensure storage initialization succeeded before starting the app
  await initResult.when(
    success: (_) async {
      AppLogger.info('Main: Local storage initialized successfully');
      
      runApp(
        ProviderScope(
          overrides: [
            // Provide the initialized storage service instance
            localStorageServiceProvider.overrideWithValue(storageService),
          ],
          child: const FlowItApp(),
        ),
      );
    },
    failure: (failure) async {
      AppLogger.error('Main: Failed to initialize storage - app cannot start', failure.exception, failure.stackTrace);
      // Show error and exit gracefully
      runApp(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to initialize local storage',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    failure.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
} 
