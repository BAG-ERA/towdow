// SharingSyncService centralizes all interactions with the external sharing API
// It is responsible for synchronizing project members after calendar property
// updates, and any other sharing-related operations. Keeping this logic here
// avoids coupling CalDAV/WebDAV code with TowDow sharing API specifics.

import '../../../core/logger.dart';
import '../../../core/result.dart';
import '../../models/caldav_account.dart';
import '../../models/task_calendar.dart';
import 'share_service.dart';

class SharingSyncService {
  const SharingSyncService();

  /// Synchronize sharing data of a calendar (project) to the TowDow sharing API.
  ///
  /// Returns Result.success on success, Result.failure on explicit API error.
  /// Calling code may choose to ignore failures to keep CalDAV operations
  /// resilient (do not block property updates due to sharing issues).
  Future<Result<void>> syncCalendarSharing({
    required TaskCalendar calendar,
    required CaldavAccount account,
  }) async {
    try {
      // Only sync sharing for supported providers
      if (account.providerType != 'towdow_cloud' &&
          account.providerType != 'towdow_selfhosted') {
        AppLogger.debug(
          'SharingSyncService: Skipping sharing sync - providerType=' +
              account.providerType,
        );
        return const Result.success(null);
      }


      final sharingService = ShareService(account: account);

      // Project identifier for the sharing API. We rely on calendar UID
      // (extracted from path elsewhere during discovery/creation).
      final projectId = calendar.uid;
      if (projectId.isEmpty) {
        AppLogger.warning(
          'SharingSyncService: Missing calendar UID for ${calendar.path}; cannot sync sharing',
        );
        return const Result.success(null);
      }

      final memberEmails = calendar.sharedWithMembers
          .map((member) => member['targetUserEmail'] as String)
          .toList();

      AppLogger.info(
        'SharingSyncService: Syncing ${memberEmails.length} members for project $projectId',
      );

      final result = await sharingService.setProjectMembers(
        projectPath: projectId,
        memberEmails: memberEmails,
      );

      return await result.when(
        success: (_) async {
          AppLogger.info(
            'SharingSyncService: Sharing synced successfully for ${calendar.path}',
          );
          return const Result.success(null);
        },
        failure: (f) async {
          AppLogger.error(
            'SharingSyncService: Failed to sync members for ${calendar.path}: ${f.message}',
            f.exception,
            f.stackTrace,
          );
          return Result.failure(f);
        },
      );
    } catch (e, st) {
      AppLogger.error('SharingSyncService: Exception during sharing sync', e, st);
      return Result.failure(Failure(message: 'Sharing sync exception: $e'));
    }
  }
}


