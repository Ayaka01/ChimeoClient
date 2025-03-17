// lib/services/user_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class UserService {
  final AuthService _authService;

  UserService(this._authService);

  // Search for users
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      if (query.length < 3) return [];

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/search?q=$query'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => UserModel.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Get all friends
  Future<List<UserModel>> getFriends() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/friends'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => UserModel.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error getting friends: $e');
      return [];
    }
  }

  // Send a friend request
  Future<String?> sendFriendRequest(String username) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/users/friends/request'),
        headers: {
          'Authorization': 'Bearer ${_authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'username': username}),
      );

      if (response.statusCode == 200) {
        final requestStatus = json.decode(response.body);
        return requestStatus['status'];
      } else if (response.statusCode == 400) {
        final errorResponse = json.decode(response.body);
        return errorResponse['detail'];
      }

      return null;
    } catch (e) {
      print('Error sending friend request: $e');
      return null;
    }
  }

  // Respond to a friend request (accept or reject)
  Future<UserModel?> respondToFriendRequest(
    String requestId,
    String action,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/users/friends/respond'),
        headers: {
          'Authorization': 'Bearer ${_authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'request_id': requestId, 'action': action}),
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(json.decode(response.body));
      }

      return null;
    } catch (e) {
      print('Error responding to friend request: $e');
      return null;
    }
  }

  // Get received friend requests
  Future<List<FriendRequestModel>> getReceivedFriendRequests({
    String? status,
  }) async {
    try {
      String url = '${ApiConfig.baseUrl}/users/friends/requests/received';
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
      print('Error getting received friend requests: $e');
      return [];
    }
  }

  // Get sent friend requests
  Future<List<FriendRequestModel>> getSentFriendRequests({
    String? status,
  }) async {
    try {
      String url = '${ApiConfig.baseUrl}/users/friends/requests/sent';
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
      print('Error getting sent friend requests: $e');
      return [];
    }
  }
}
