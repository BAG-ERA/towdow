// TowDow sharing service for project sharing API operations
// Handles sharing projects with other users via TowDow API endpoints
// Supports TowDow Cloud and TowDow self-hosted servers

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/caldav_account.dart';
import 'webdav_client.dart';

/// Model for shared project member information
class SharedProjectMember {
  final String projectPath;
  final bool allTasks;
  final String projectRight;
  final String sourceUserEmail;
  final String targetUserEmail;

  const SharedProjectMember({
    required this.projectPath,
    required this.allTasks,
    required this.projectRight,
    required this.sourceUserEmail,
    required this.targetUserEmail,
  });

  factory SharedProjectMember.fromJson(Map<String, dynamic> json) {
    return SharedProjectMember(
      projectPath: json['projectPath'] as String,
      allTasks: json['allTasks'] as bool,
      projectRight: json['projectRight'] as String,
      sourceUserEmail: json['sourceUserEmail'] as String,
      targetUserEmail: json['targetUserEmail'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projectPath': projectPath,
      'allTasks': allTasks,
      'projectRight': projectRight,
      'sourceUserEmail': sourceUserEmail,
      'targetUserEmail': targetUserEmail,
    };
  }
}

/// Service for managing project sharing via TowDow API
class TowDowSharingService {
  final CaldavAccount account;
  late final WebDAVClient _client;
  late final String _baseUrl;

  TowDowSharingService({required this.account}) {
    _client = WebDAVClient.fromAccount(account);
    // Extract base URL from serverUrl (remove CalDAV path)
    final serverUri = Uri.parse(account.serverUrl);
    _baseUrl = '${serverUri.scheme}://${serverUri.host}${serverUri.hasPort ? ':${serverUri.port}' : ''}';
  }

  /// Add a project member (PUT /share/{project_path})
  Future<Result<void>> addProjectMember({
    required String projectPath,
    required String targetUserEmail,
    bool allTasks = true,
    String projectRight = 'W',
  }) async {
    try {
      AppLogger.info('TowDowSharingService: Adding member $targetUserEmail to project $projectPath');
      
      final url = Uri.parse('$_baseUrl/share/${Uri.encodeComponent(projectPath)}');
      final headers = await _client.getAuthHeaders();
      headers['Content-Type'] = 'application/json';
      
      final requestBody = {
        'projectPath': projectPath,
        'allTasks': allTasks,
        'projectRight': projectRight,
        'targetUserEmail': targetUserEmail,
      };
      
      // Debug logging
      AppLogger.info('TowDowSharingService: Request URL: $url');
      AppLogger.info('TowDowSharingService: Request body: ${jsonEncode(requestBody)}');
      AppLogger.info('TowDowSharingService: Request headers: $headers');
      
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        AppLogger.info('TowDowSharingService: Successfully added member to project');
        return const Result.success(null);
      } else {
        AppLogger.error('TowDowSharingService: Failed to add member: ${response.statusCode} ${response.body}');
        return Result.failure(Failure(
          message: 'Failed to add project member: ${response.statusCode}',
          exception: Exception('HTTP ${response.statusCode}: ${response.body}'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('TowDowSharingService: Error adding project member', e, stackTrace);
      return Result.failure(Failure(
        message: 'Error adding project member: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Set project member list (PUT /share/{project_path})
  Future<Result<void>> setProjectMembers({
    required String projectPath,
    required List<SharedProjectMember> members,
  }) async {
    try {
      AppLogger.info('TowDowSharingService: Setting ${members.length} members for project $projectPath');
      
      final url = Uri.parse('$_baseUrl/share/${Uri.encodeComponent(projectPath)}');
      final headers = await _client.getAuthHeaders();
      headers['Content-Type'] = 'application/json';
      
      final requestBody = members.map((m) => m.toJson()).toList();
      
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        AppLogger.info('TowDowSharingService: Successfully set project members');
        return const Result.success(null);
      } else {
        AppLogger.error('TowDowSharingService: Failed to set members: ${response.statusCode} ${response.body}');
        return Result.failure(Failure(
          message: 'Failed to set project members: ${response.statusCode}',
          exception: Exception('HTTP ${response.statusCode}: ${response.body}'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('TowDowSharingService: Error setting project members', e, stackTrace);
      return Result.failure(Failure(
        message: 'Error setting project members: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Remove a member from project (DELETE /share/{project_path})
  Future<Result<void>> removeProjectMember({
    required String projectPath,
    required String targetUserEmail,
  }) async {
    try {
      AppLogger.info('TowDowSharingService: Removing member $targetUserEmail from project $projectPath');
      
      final url = Uri.parse('$_baseUrl/share/${Uri.encodeComponent(projectPath)}?targetUserEmail=${Uri.encodeComponent(targetUserEmail)}');
      final headers = await _client.getAuthHeaders();
      
      final response = await http.delete(url, headers: headers);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        AppLogger.info('TowDowSharingService: Successfully removed member from project');
        return const Result.success(null);
      } else {
        AppLogger.error('TowDowSharingService: Failed to remove member: ${response.statusCode} ${response.body}');
        return Result.failure(Failure(
          message: 'Failed to remove project member: ${response.statusCode}',
          exception: Exception('HTTP ${response.statusCode}: ${response.body}'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('TowDowSharingService: Error removing project member', e, stackTrace);
      return Result.failure(Failure(
        message: 'Error removing project member: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get project members (GET /share/{project_path})
  Future<Result<List<SharedProjectMember>>> getProjectMembers(String projectPath) async {
    try {
      AppLogger.info('TowDowSharingService: Getting members for project $projectPath');
      
      final url = Uri.parse('$_baseUrl/share/${Uri.encodeComponent(projectPath)}');
      final headers = await _client.getAuthHeaders();
      
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final members = jsonList.map((json) => SharedProjectMember.fromJson(json)).toList();
        
        AppLogger.info('TowDowSharingService: Found ${members.length} members for project');
        return Result.success(members);
      } else {
        AppLogger.error('TowDowSharingService: Failed to get members: ${response.statusCode} ${response.body}');
        return Result.failure(Failure(
          message: 'Failed to get project members: ${response.statusCode}',
          exception: Exception('HTTP ${response.statusCode}: ${response.body}'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('TowDowSharingService: Error getting project members', e, stackTrace);
      return Result.failure(Failure(
        message: 'Error getting project members: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get projects shared with me (GET /shared_with_me)
  Future<Result<List<SharedProjectMember>>> getProjectsSharedWithMe() async {
    try {
      AppLogger.info('TowDowSharingService: Getting projects shared with me');
      
      final url = Uri.parse('$_baseUrl/shared_with_me');
      final headers = await _client.getAuthHeaders();
      
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final members = jsonList.map((json) => SharedProjectMember.fromJson(json)).toList();
        
        AppLogger.info('TowDowSharingService: Found ${members.length} projects shared with me');
        return Result.success(members);
      } else {
        AppLogger.error('TowDowSharingService: Failed to get shared projects: ${response.statusCode} ${response.body}');
        return Result.failure(Failure(
          message: 'Failed to get shared projects: ${response.statusCode}',
          exception: Exception('HTTP ${response.statusCode}: ${response.body}'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('TowDowSharingService: Error getting shared projects', e, stackTrace);
      return Result.failure(Failure(
        message: 'Error getting shared projects: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Exit share from project (POST /exitShare/{project_path})
  Future<Result<void>> exitShare(String projectPath) async {
    try {
      AppLogger.info('TowDowSharingService: Exiting share for project $projectPath');
      
      final url = Uri.parse('$_baseUrl/exitShare/${Uri.encodeComponent(projectPath)}');
      final headers = await _client.getAuthHeaders();
      
      final response = await http.post(url, headers: headers);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        AppLogger.info('TowDowSharingService: Successfully exited share');
        return const Result.success(null);
      } else {
        AppLogger.error('TowDowSharingService: Failed to exit share: ${response.statusCode} ${response.body}');
        return Result.failure(Failure(
          message: 'Failed to exit share: ${response.statusCode}',
          exception: Exception('HTTP ${response.statusCode}: ${response.body}'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('TowDowSharingService: Error exiting share', e, stackTrace);
      return Result.failure(Failure(
        message: 'Error exiting share: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Check if account supports sharing (TowDow Cloud or self-hosted)
  bool get supportsSharing {
    return account.providerType == 'towdow_cloud' || 
           account.providerType == 'towdow_selfhosted';
  }
} 