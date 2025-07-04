// Main entry point for FlowIt application
// Sets up ProviderScope, Hive initialization, timezone database, and app routing

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'app.dart';
import 'core/logger.dart';
import 'data/models/task.dart';
import 'data/models/attendee.dart';

import 'data/models/automated_task.dart';
import 'data/models/caldav_account.dart';
import 'data/models/validator.dart';
import 'data/models/task_calendar.dart';
import 'data/models/user_preferences.dart';

// External calendar models
import 'data/models/external_calendar.dart';
import 'data/models/external_caldav_account.dart';
import 'data/models/calendar_event.dart';
import 'data/services/local_storage_service.dart';
import 'data/providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
<<<<<<< HEAD
  
=======
  // Initialize timezone database for proper timezone conversions
  tz.initializeTimeZones();
  AppLogger.info('Main: Timezone database initialized');
  
  // Initialize Hive
  await Hive.initFlutter();
>>>>>>> ea1e158 (timezone fix)
  
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
  
  // Register External Calendar adapters
  Hive.registerAdapter(ExternalCalendarAdapter());
  Hive.registerAdapter(ExternalCalendarAuthTypeAdapter());
  Hive.registerAdapter(ExternalCaldavAccountAdapter());
  Hive.registerAdapter(CalendarEventAdapter());
  
  // Initialize local storage service
  final storageService = LocalStorageService();
  final initResult = await storageService.initialize();
  
  // Ensure storage initialization succeeded before starting the app
  await initResult.when(
    success: (_) async {
      // AppLogger.info('Main: Local storage initialized successfully');
      
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
