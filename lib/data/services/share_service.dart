// Project sharing service for TowDow API integration
// Handles project member management and sharing operations

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/caldav_account.dart';
import '../models/shared_project_member.dart';
import 'webdav_client.dart';

/// Service for managing project sharing through TowDow API
class ShareService {
  final CaldavAccount account;
  late final WebDAVClient _client;
  late final String _baseUrl;

  ShareService({required this.account}) {
    _client = WebDAVClient.fromAccount(account);
    // Extract base URL from serverUrl (remove CalDAV path)
    final serverUri = Uri.parse(account.serverUrl);
    _baseUrl = '${serverUri.scheme}://${serverUri.host}${serverUri.hasPort ? ':${serverUri.port}' : ''}';
  }

  /// Extract UID from path (last non-empty segment after splitting on /)
  String _extractUidFromPath(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isNotEmpty ? segments.last : path;
  }

  /// Get project members from sharing API
  Future<Result<List<SharedProjectMember>>> getProjectMembers(String projectPath) async {
    AppLogger.debug('ShareService: Getting project members for path: $projectPath');
    AppLogger.debug('ShareService: Base URL: $_baseUrl');
    AppLogger.debug('ShareService: Account: ${account.username}@${account.serverUrl}');
    
    try {
      // For sharing API, we need to use direct HTTP client since it's not CalDAV
      final url = '$_baseUrl/share/$_extractUidFromPath(projectPath)';
      AppLogger.debug('ShareService: Making GET request to: $url');
      
      // Get auth headers from WebDAV client
      final authHeaders = await _client.getAuthHeaders();
      
      final response = await http.get(
        Uri.parse(url),
        headers: authHeaders,
      );
      
      AppLogger.debug('ShareService: GET response status: ${response.statusCode}');
      AppLogger.debug('ShareService: GET response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final members = jsonList.map((json) => SharedProjectMember.fromJson(json)).toList();
        AppLogger.info('ShareService: Successfully fetched ${members.length} members');
        return Result.success(members);
      } else {
        AppLogger.warning('ShareService: GET failed with status ${response.statusCode}: ${response.body}');
        return Result.failure(Failure(
          message: 'Failed to get project members: ${response.statusCode}',
          exception: Exception('HTTP ${response.statusCode}: ${response.body}'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('ShareService: Exception getting project members', e, stackTrace);
      return Result.failure(Failure(
        message: 'Exception getting project members: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Set project member list (PUT /share/{project_path})
  Future<Result<void>> setProjectMembers({
    required String projectPath,
    required List<String> memberEmails,
  }) async {
    AppLogger.debug('ShareService: Setting project members for path: $projectPath');
    AppLogger.debug('ShareService: Member emails: $memberEmails');
    AppLogger.debug('ShareService: Base URL: $_baseUrl');
    
    try {
      // For sharing API, we need to use direct HTTP client since it's not CalDAV
      final url = '$_baseUrl/share/$_extractUidFromPath(projectPath)';
      final requestBody = jsonEncode(memberEmails);
      AppLogger.debug('ShareService: Making PUT request to: $url');
      AppLogger.debug('ShareService: PUT request body: $requestBody');
      
      // Get auth headers from WebDAV client
      final authHeaders = await _client.getAuthHeaders();
      final headers = {
        ...authHeaders,
        'Content-Type': 'application/json',
      };
      
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: requestBody,
      );
      
      AppLogger.debug('ShareService: PUT response status: ${response.statusCode}');
      AppLogger.debug('ShareService: PUT response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        AppLogger.info('ShareService: Successfully set project members');
        return Result.success(null);
      } else {
        AppLogger.warning('ShareService: PUT failed with status ${response.statusCode}: ${response.body}');
        return Result.failure(Failure(
          message: 'Failed to set project members: ${response.statusCode}',
          exception: Exception('HTTP ${response.statusCode}: ${response.body}'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('ShareService: Exception setting project members', e, stackTrace);
      return Result.failure(Failure(
        message: 'Exception setting project members: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Add a project member (POST /share/{project_path})
  Future<Result<void>> addProjectMember({
    required String projectPath,
    required String targetUserEmail,
    bool allTasks = true,
    String projectRight = 'W',
  }) async {
    try {
      AppLogger.info('ShareService: Adding member $targetUserEmail to project $projectPath');
      
      final url = Uri.parse('$_baseUrl/share/$_extractUidFromPath(projectPath)');
      final headers = await _client.getAuthHeaders();
      headers['Content-Type'] = 'application/json';
      
      final requestBody = {
        'targetUserEmail': targetUserEmail,
        'allTasks': allTasks,
        'projectRight': projectRight,
      };
      
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        AppLogger.info('ShareService: Successfully added member to project');
        return const Result.success(null);
      } else {
        AppLogger.error('ShareService: Failed to add member: ${response.statusCode} ${response.body}');
        return Result.failure(Failure(
          message: 'Failed to add project member: ${response.statusCode}',
          exception: Exception('HTTP ${response.statusCode}: ${response.body}'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('ShareService: Error adding project member', e, stackTrace);
      return Result.failure(Failure(
        message: 'Error adding project member: $e',
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
      AppLogger.info('ShareService: Removing member $targetUserEmail from project $projectPath');
      
      final url = Uri.parse('$_baseUrl/share/$_extractUidFromPath(projectPath)}?targetUserEmail=${Uri.encodeComponent(targetUserEmail)}');
      final headers = await _client.getAuthHeaders();
      
      final response = await http.delete(url, headers: headers);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        AppLogger.info('ShareService: Successfully removed member from project');
        return const Result.success(null);
      } else {
        AppLogger.error('ShareService: Failed to remove member: ${response.statusCode} ${response.body}');
        return Result.failure(Failure(
          message: 'Failed to remove project member: ${response.statusCode}',
          exception: Exception('HTTP ${response.statusCode}: ${response.body}'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('ShareService: Error removing project member', e, stackTrace);
      return Result.failure(Failure(
        message: 'Error removing project member: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Check if project is shared with me (GET /shared_with_me)
  Future<bool> isSharedWithMe(String projectPath) async {
    final projectId = _extractUidFromPath(projectPath);
    final projects = await getProjectsSharedWithMe();
    return projects.when(success: (projects) => projects.any((p) => p.projectPath == projectId), failure: (failure) => false);
  }

  /// Get projects shared with me (GET /shared_with_me)
  Future<Result<List<SharedProjectMember>>> getProjectsSharedWithMe() async {
    try {
      AppLogger.info('ShareService: Getting projects shared with me');
      
      final url = Uri.parse('$_baseUrl/shared_with_me');
      final headers = await _client.getAuthHeaders();
      
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final members = jsonList.map((json) => SharedProjectMember.fromJson(json)).toList();
        
        AppLogger.info('ShareService: Found ${members.length} projects shared with me');
        return Result.success(members);
      } else {
        AppLogger.error('ShareService: Failed to get shared projects: ${response.statusCode} ${response.body}');
        return Result.failure(Failure(
          message: 'Failed to get shared projects: ${response.statusCode}',
          exception: Exception('HTTP ${response.statusCode}: ${response.body}'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('ShareService: Error getting shared projects', e, stackTrace);
      return Result.failure(Failure(
        message: 'Error getting shared projects: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Exit share from project (POST /exitShare/{project_uid})
  Future<Result<void>> exitShare(String projectPath) async {
    try {
      final projectUid = _extractUidFromPath(projectPath);
      
      final url = Uri.parse('$_baseUrl/exitShare/$projectUid');
      AppLogger.info('ShareService: Full exit share URL: $url');
      
      final headers = await _client.getAuthHeaders();
   
      AppLogger.info('ShareService: Making POST request to exit share...');
      final response = await http.post(url, headers: headers);
      AppLogger.info('ShareService: Exit share response status: ${response.statusCode}');
      AppLogger.info('ShareService: Exit share response body: ${response.body}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        AppLogger.info('ShareService: ✅ Successfully exited share');
        return const Result.success(null);
      } else {
        AppLogger.error('ShareService: ❌ Failed to exit share: ${response.statusCode} ${response.body}');
        return Result.failure(Failure(
          message: 'Failed to exit share: ${response.statusCode}',
          exception: Exception('HTTP ${response.statusCode}: ${response.body}'),
        ));
      }
    } catch (e, stackTrace) {
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