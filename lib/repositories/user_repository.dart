import 'dart:convert';
import 'package:http/http.dart' as http;

// Assuming these imports are correct for your project structure
import '../config/api_config.dart';      // For API URLs
import '../models/user_model.dart';      // For UserModel
import 'base_repository.dart';          // For BaseRepository (and executeSafe)
import '../utils/result.dart';          // For Result<T>
import '../utils/error_handler.dart';   // For errorHandler used by executeSafe
// import '../utils/exceptions.dart';   // For potential custom Exceptions

/// Repository for handling user-related data access using Result type.
class UserRepository extends BaseRepository {
  /// Singleton instance
  static final UserRepository _instance = UserRepository._internal();

  /// Private constructor
  UserRepository._internal();

  /// Factory constructor to return the singleton instance
  factory UserRepository() => _instance;

  /// Gets user profile by username.
  /// Returns Result.success(UserModel) or Result.failure(Exception).
  Future<Result<UserModel>> getUserProfile(String username, String token) async {
    // Return the Result directly from executeSafe
    return await executeSafe<UserModel>(() async {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/$username');
      print("DEBUG: Getting user profile: $url"); // Optional debug
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Success: Parse and return the model
        return UserModel.fromJson(json.decode(response.body));
      } else {
        // Failure: Throw an exception for executeSafe to catch
        // TODO: Consider specific exceptions e.g., UserNotFoundException for 404
        throw Exception('Failed to get user profile for $username: ${response.statusCode} ${response.reasonPhrase}');
      }
    });
  }

  /// Searches users by query.
  /// Returns Result.success(List<UserModel>) or Result.failure(Exception).
  Future<Result<List<UserModel>>> searchUsers(String query, String token) async {
    // Return the Result directly from executeSafe
    return await executeSafe<List<UserModel>>(() async {
      // Use Uri.encodeComponent for the query parameter for safety
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/search?q=${Uri.encodeComponent(query)}');
      print("DEBUG: Searching users: $url"); // Optional debug
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Success: Parse the list
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => UserModel.fromJson(json)).toList();
      } else {
        // Failure: Throw an exception
        throw Exception('Failed to search users for query "$query": ${response.statusCode} ${response.reasonPhrase}');
      }
    });
    // Removed '?? []'
  }

  /// Gets the current user's friends list.
  /// Returns Result.success(List<UserModel>) or Result.failure(Exception).
  Future<Result<List<UserModel>>> getFriends(String token) async {
    // Return the Result directly from executeSafe
    return await executeSafe<List<UserModel>>(() async {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/friends');
      print("DEBUG: Getting friends list: $url"); // Optional debug
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Success: Parse the list
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => UserModel.fromJson(json)).toList();
      } else {
        // Failure: Throw an exception
        throw Exception('Failed to get friends: ${response.statusCode} ${response.reasonPhrase}');
      }
    });
    // Removed '?? []'
  }

  /// Gets the current user's friend requests.
  /// Returns Result.success(List<UserModel>) or Result.failure(Exception).
  Future<Result<List<UserModel>>> getFriendRequests(String token) async {
    // Return the Result directly from executeSafe
    return await executeSafe<List<UserModel>>(() async {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/friend-requests');
      print("DEBUG: Getting friend requests: $url"); // Optional debug
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Success: Parse the list
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => UserModel.fromJson(json)).toList();
      } else {
        // Failure: Throw an exception
        throw Exception('Failed to get friend requests: ${response.statusCode} ${response.reasonPhrase}');
      }
    });
    // Removed '?? []'
  }

  /// Sends a friend request to a user.
  /// Returns Result.success(null) on success, Result.failure(Exception) on failure.
  Future<Result<void>> sendFriendRequest(String username, String token) async {
    // Replace executeSafeBool with executeSafe<void>
    return await executeSafe<void>(() async {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/friend-request/$username');
      print("DEBUG: Sending friend request to $username: $url"); // Optional debug
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      // Assuming 200 OK means success for this operation
      if (response.statusCode != 200) {
        // Failure: Throw an exception
        // TODO: Handle specific codes like 404 (user not found), 409 (already friends/request pending?)
        throw Exception('Failed to send friend request to $username: ${response.statusCode} ${response.reasonPhrase}');
      }
      // Success: No return needed for void
    });
  }

  /// Accepts a friend request from a user.
  /// Returns Result.success(null) on success, Result.failure(Exception) on failure.
  Future<Result<void>> acceptFriendRequest(String username, String token) async {
    // Replace executeSafeBool with executeSafe<void>
    return await executeSafe<void>(() async {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/friend-request/$username/accept');
      print("DEBUG: Accepting friend request from $username: $url"); // Optional debug
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      // Assuming 200 OK means success
      if (response.statusCode != 200) {
        // Failure: Throw an exception
        // TODO: Handle specific codes like 404 (request/user not found)
        throw Exception('Failed to accept friend request from $username: ${response.statusCode} ${response.reasonPhrase}');
      }
      // Success: No return needed for void
    });
  }

  /// Rejects a friend request from a user.
  /// Returns Result.success(null) on success, Result.failure(Exception) on failure.
  Future<Result<void>> rejectFriendRequest(String username, String token) async {
    // Replace executeSafeBool with executeSafe<void>
    return await executeSafe<void>(() async {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersPath}/friend-request/$username/reject');
      print("DEBUG: Rejecting friend request from $username: $url"); // Optional debug
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      // Assuming 200 OK means success (or maybe 204 No Content?)
      if (response.statusCode != 200) {
        // Failure: Throw an exception
        // TODO: Handle specific codes like 404 (request/user not found)
        throw Exception('Failed to reject friend request from $username: ${response.statusCode} ${response.reasonPhrase}');
      }
      // Success: No return needed for void
    });
  }
} // End of UserRepository class