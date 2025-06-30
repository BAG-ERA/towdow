/// Migration service for handling data model changes
/// 
/// This service manages the transition from string-based attendees 
/// to structured Attendee objects across different model versions.

library;

import '../../core/logger.dart';
import '../../core/result.dart';
import '../models/attendee.dart';
import 'local_storage_service.dart';

class MigrationService {
  final LocalStorageService _storageService;
  
  MigrationService(this._storageService);
  
  /// Run all necessary migrations
  Future<Result<void>> runMigrations() async {
    try {
      // AppLogger.info('MigrationService: Starting data migrations...');
      
      // Check if migration is needed
      final needsMigration = await _checkIfMigrationNeeded();
      if (!needsMigration) {
        // AppLogger.info('MigrationService: No migration needed');
        return Result.success(null);
      }
      
      // Run calendar attendee migration
      await _migrateCalendarAttendees();
      
      // Mark migration as complete
      await _markMigrationComplete();
      
      // AppLogger.info('MigrationService: All migrations completed successfully');
      return Result.success(null);
    } catch (e, stackTrace) {
      AppLogger.error('MigrationService: Migration failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'Migration failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }
  
  /// Check if migration is needed by looking for legacy data
  Future<bool> _checkIfMigrationNeeded() async {
    try {
      // Check if we have the migration marker
      final migrationResult = await _storageService.get<bool>('migration', 'attendee_model_v1');
      final isComplete = migrationResult.when(
        success: (completed) => completed ?? false,
        failure: (_) => false,
      );
      
      return !isComplete;
    } catch (e) {
              // AppLogger.debug('MigrationService: Error checking migration status, assuming needed: $e');
      return true;
    }
  }
  
  /// Migrate TaskCalendar attendees from `List<String>` to `List<Attendee>`
  Future<void> _migrateCalendarAttendees() async {
    // AppLogger.info('MigrationService: Migrating calendar attendees...');
    
    // This would be needed if we had legacy data, but since we're changing the model
    // and regenerating, the build_runner should handle the type conversion.
    // If needed in the future, we could implement specific migration logic here.
    
    // AppLogger.info('MigrationService: Calendar attendee migration completed');
  }
  
  /// Mark migration as complete
  Future<void> _markMigrationComplete() async {
    await _storageService.put('migration', 'attendee_model_v1', true);
  }
  
  /// Helper method to convert string attendees to Attendee objects
  static List<Attendee> convertStringAttendeesToObjects(List<String> stringAttendees) {
    return stringAttendees.map((email) => AttendeeFactory.fromEmail(email)).toList();
  }
  
  /// Helper method to extract emails from Attendee objects
  static List<String> extractEmailsFromAttendees(List<Attendee> attendees) {
    return attendees.map((attendee) => attendee.email).toList();
  }
} 
