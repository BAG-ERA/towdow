// Users API service for TowDow API integration
// Handles user information retrieval operations

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/caldav_account.dart';
import '../models/user.dart';
import 'webdav_client.dart';

/// Service for managing user information through TowDow API
class UsersApiService {
  final CaldavAccount account;
  late final WebDAVClient _client;
  late final String _baseUrl;

  UsersApiService({required this.account}) {
    _client = WebDAVClient.fromAccount(account);
    // Extract base URL from serverUrl (remove CalDAV path)
    final serverUri = Uri.parse(account.serverUrl);
    _baseUrl = '${serverUri.scheme}://${serverUri.host}${serverUri.hasPort ? ':${serverUri.port}' : ''}';
  }

  /// Get current user information (GET /current_user)
  Future<Result<CurrentUser>> getCurrentUser() async {
    AppLogger.debug('UsersApiService: Getting current user information');
    AppLogger.debug('UsersApiService: Base URL: $_baseUrl');
    AppLogger.debug('UsersApiService: Account: ${account.username}@${account.serverUrl}');
    
    try {
      final url = '$_baseUrl/current_user';
      AppLogger.debug('UsersApiService: Making GET request to: $url');
      
      // Get auth headers from WebDAV client
      final authHeaders = await _client.getAuthHeaders();
      
      final response = await http.get(
        Uri.parse(url),
        headers: authHeaders,
      );
      
      AppLogger.debug('UsersApiService: GET response status: ${response.statusCode}');
      AppLogger.debug('UsersApiService: GET response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final currentUser = CurrentUser.fromJson(json);
        AppLogger.info('UsersApiService: Successfully fetched current user: ${currentUser.email}');
        return Result.success(currentUser);
      } else {
        AppLogger.warning('UsersApiService: GET failed with status ${response.statusCode}: ${response.body}');
        return Result.failure(Failure(
          message: 'Failed to get current user: ${response.statusCode}',
          exception: Exception('HTTP ${response.statusCode}: ${response.body}'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('UsersApiService: Exception getting current user', e, stackTrace);
      return Result.failure(Failure(
        message: 'Exception getting current user: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get user information by email (GET /user/{email})
  Future<Result<UserInfo>> getUserByEmail(String email) async {
    AppLogger.debug('UsersApiService: Getting user information for email: $email');
    AppLogger.debug('UsersApiService: Base URL: $_baseUrl');
    
    try {
      final url = '$_baseUrl/user/${Uri.encodeComponent(email)}';
      AppLogger.debug('UsersApiService: Making GET request to: $url');
      
      // Get auth headers from WebDAV client
      final authHeaders = await _client.getAuthHeaders();
      
      final response = await http.get(
        Uri.parse(url),
        headers: authHeaders,
      );
      
      AppLogger.debug('UsersApiService: GET response status: ${response.statusCode}');
      AppLogger.debug('UsersApiService: GET response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final userInfo = UserInfo.fromJson(json);
        AppLogger.info('UsersApiService: Successfully fetched user info for: ${userInfo.email}');
        return Result.success(userInfo);
      } else if (response.statusCode == 404) {
        AppLogger.warning('UsersApiService: User not found: $email');
        return Result.failure(Failure(
          message: 'User not found: $email',
          exception: Exception('User not found: $email'),
        ));
      } else {
        AppLogger.warning('UsersApiService: GET failed with status ${response.statusCode}: ${response.body}');
        return Result.failure(Failure(
          message: 'Failed to get user info: ${response.statusCode}',
          exception: Exception('HTTP ${response.statusCode}: ${response.body}'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('UsersApiService: Exception getting user info', e, stackTrace);
      return Result.failure(Failure(
        message: 'Exception getting user info: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Check if account supports users API (TowDow Cloud or self-hosted)
  bool get supportsUsersApi {
    return account.providerType == 'towdow_cloud' || 
           account.providerType == 'towdow_selfhosted';
  }
} 