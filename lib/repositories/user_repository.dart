import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user_model.dart';
import 'base_repository.dart';

/// Repository for handling user-related data access
class UserRepository extends BaseRepository {
  /// Singleton instance
  static final UserRepository _instance = UserRepository._internal();
  
  /// Private constructor
  UserRepository._internal();
  
  /// Factory constructor to return the singleton instance
  factory UserRepository() => _instance;
  
  /// Get user profile by username
  Future<UserModel?> getUserProfile(String username, String token) async {
    return await executeSafe<UserModel>(() async {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/$username'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(json.decode(response.body));
      }
      
      throw Exception('Failed to get user profile: ${response.statusCode}');
    });
  }
  
  /// Search users by query
  Future<List<UserModel>> searchUsers(String query, String token) async {
    final result = await executeSafe<List<UserModel>>(() async {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/search?q=$query'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
      
      throw Exception('Failed to search users: ${response.statusCode}');
    });
    
    return result ?? [];
  }
  
  /// Get friends list
  Future<List<UserModel>> getFriends(String token) async {
    final result = await executeSafe<List<UserModel>>(() async {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/friends'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
      
      throw Exception('Failed to get friends: ${response.statusCode}');
    });
    
    return result ?? [];
  }
  
  /// Get friend requests
  Future<List<UserModel>> getFriendRequests(String token) async {
    final result = await executeSafe<List<UserModel>>(() async {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/friend-requests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
      
      throw Exception('Failed to get friend requests: ${response.statusCode}');
    });
    
    return result ?? [];
  }
  
  /// Send friend request
  Future<bool> sendFriendRequest(String username, String token) async {
    return await executeSafeBool(() async {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/friend-request/$username'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send friend request: ${response.statusCode}');
      }
    });
  }
  
  /// Accept friend request
  Future<bool> acceptFriendRequest(String username, String token) async {
    return await executeSafeBool(() async {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/friend-request/$username/accept'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to accept friend request: ${response.statusCode}');
      }
    });
  }
  
  /// Reject friend request
  Future<bool> rejectFriendRequest(String username, String token) async {
    return await executeSafeBool(() async {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/friend-request/$username/reject'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to reject friend request: ${response.statusCode}');
      }
    });
  }
} 