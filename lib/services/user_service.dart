// lib/services/user_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import '../utils/logger.dart';

class UserService {
  final AuthService _authService;
  final Logger _logger = Logger();

  UserService(this._authService);

  // Search for users
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      if (query.length < 3) return [];

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/search?q=$query'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => UserModel.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      _logger.e('Error searching users', error: e, tag: 'UserService');
      return [];
    }
  }

  // Get user profile by username
  Future<UserModel?> getUserProfile(String username) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/$username'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        return UserModel.fromJson(userData);
      }

      return null;
    } catch (e) {
      _logger.e('Error getting user profile', error: e, tag: 'UserService');
      return null;
    }
  }

  // Get all friends
  Future<List<UserModel>> getFriends() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/friends'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => UserModel.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      _logger.e('Error getting friends', error: e, tag: 'UserService');
      return [];
    }
  }

  // Send friend request
  Future<bool> sendFriendRequest(String username) async {
    final token = _authService.token;
    if (token == null) {
      _logger.w('Attempted to send friend request without auth token', tag: 'UserService');
      throw Exception('Not authenticated');
    }
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/friends/request'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'username': username}),
      );

      if (response.statusCode == 200) {
        _logger.i('Friend request sent successfully to $username', tag: 'UserService');
        return true;
      } else {
        String errorMessage = 'Failed to send friend request (Code: ${response.statusCode})';
        try {
          final responseBody = json.decode(response.body);
          if (responseBody is Map && responseBody.containsKey('detail')) {
            errorMessage = responseBody['detail'];
          }
        } catch (e) {
          _logger.w('Failed to parse error response body: ${response.body}', tag: 'UserService');
          errorMessage += '\nResponse: ${response.body}';
        }
        _logger.e('Error sending friend request to $username: $errorMessage', tag: 'UserService');
        throw Exception(errorMessage);
      }
    } catch (e) {
      _logger.e('Error sending friend request to $username', error: e, tag: 'UserService');
      rethrow;
    }
  }

  // Respond to friend request - returns true on success
  Future<bool> respondToFriendRequest(
    String requestId,
    String action,
  ) async {
    final token = _authService.token;
    if (token == null) {
       _logger.w('Attempted to respond to friend request without auth token', tag: 'UserService');
       return false;
    }
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/friends/respond'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'request_id': requestId, 'action': action}),
      );

      // Check for successful status code (e.g., 200 OK or 204 No Content)
      if (response.statusCode >= 200 && response.statusCode < 300) {
         _logger.i('Successfully responded ($action) to friend request $requestId', tag: 'UserService');
         return true; // Indicate success
      } else {
         // Log error with details if possible
         String errorMessage = 'Failed to respond ($action) to friend request $requestId (Code: ${response.statusCode})';
         try {
           final responseBody = json.decode(response.body);
           if (responseBody is Map && responseBody.containsKey('detail')) {
             errorMessage = responseBody['detail'];
           }
         } catch (e) { /* Ignore parsing error */ }
         _logger.e(errorMessage, tag: 'UserService');
         // Optionally throw an exception here based on status code if needed
         return false; // Indicate failure
      }

    } catch (e) {
      _logger.e('Error responding to friend request $requestId ($action)', error: e, tag: 'UserService');
      return false; // Indicate failure
    }
  }

  // Get received friend requests
  Future<List<FriendRequestModel>> getReceivedFriendRequests() async {
    try {
      String url = '${ApiConfig.baseUrl}${ApiConfig.usersPath}/friends/requests/received';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => FriendRequestModel.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      _logger.e('Error getting received friend requests', error: e, tag: 'UserService');
      return [];
    }
  }

  // Get sent friend requests
  Future<List<FriendRequestModel>> getSentFriendRequests({
    String? status,
  }) async {
    try {
      String url = '${ApiConfig.baseUrl}${ApiConfig.usersPath}/friends/requests/sent';
      if (status != null) {
        url += '?status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => FriendRequestModel.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      _logger.e('Error getting sent friend requests', error: e, tag: 'UserService');
      return [];
    }
  }
}
