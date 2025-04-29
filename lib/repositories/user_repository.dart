import 'dart:convert';
// import 'package:http/http.dart' as http; // Remove http
import 'package:dio/dio.dart'; // Import dio
import 'package:simple_messenger/utils/exceptions.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
// import 'base_repository.dart'; // Remove BaseRepository
import '../utils/result.dart';
import '../utils/logger.dart';
import '../utils/dio_client.dart'; // Import global dio

// class UserRepository extends BaseRepository {
class UserRepository {
  // static final UserRepository _instance = UserRepository._internal();
  final Logger _logger = Logger();
  final Dio _dio = dio; // Use global dio

  // Remove internal constructor if not singleton
  // UserRepository._internal();
  // factory UserRepository() => _instance;

  // Constructor (can be default or accept Dio if needed later)
  UserRepository();

  Future<Result<List<UserModel>>> searchUsers(String query) async {
    _logger.i('Requesting user search with query: "$query"', tag: 'UserRepository');
    try {
      final response = await _dio.get(
        '${ApiConfig.usersPath}/search', 
        queryParameters: {'q': query},
      );

      if (response.statusCode == 200 && response.data is List) {
          final List<dynamic> data = response.data;
          _logger.i('User search successful', tag: 'UserRepository');
          return Result.success(data.map((json) => UserModel.fromJson(json)).toList());
      } else {
           _logger.w('Search users returned non-200 or invalid data: ${response.statusCode}', tag: 'UserRepository');
           throw RepositoryException('User search failed: Unexpected response format');
      }

    } on DioException catch (e) {
        _logger.e('DioException during user search', error: e, tag: 'UserRepository');
        if (e.response != null) {
            final statusCode = e.response!.statusCode;
            if (statusCode == 422) {
                // Assuming UsernameTooShortException maps to 422 for this query
                return Result.failure(UsernameTooShortException()); 
            }
            if (statusCode == 500) {
                return Result.failure(InternalServerErrorException());
            }
            final detail = e.response!.data?['detail'] ?? e.message;
            return Result.failure(RepositoryException('User search failed: $detail'));
        } else {
            return Result.failure(RepositoryException('Network error during user search: ${e.message}'));
        }
    } catch (e) {
        _logger.e('Unexpected error during user search', error: e, tag: 'UserRepository');
        return Result.failure(RepositoryException('User search failed: ${e.toString()}'));
    }
  }

  Future<Result<List<UserModel>>> getFriends() async {
    _logger.i('Requesting friends list', tag: 'UserRepository');
    try {
      final response = await _dio.get(
        '${ApiConfig.usersPath}/friends',
      );

      if (response.statusCode == 200 && response.data is List) {
          final List<dynamic> data = response.data;
          _logger.i('Friends list fetch successful', tag: 'UserRepository');
          return Result.success(data.map((json) => UserModel.fromJson(json)).toList());
      } else {
          _logger.w('Get friends returned non-200 or invalid data: ${response.statusCode}', tag: 'UserRepository');
          throw RepositoryException('Get friends failed: Unexpected response format');
      }

    } on DioException catch (e) {
        _logger.e('DioException fetching friends list', error: e, tag: 'UserRepository');
        if (e.response != null) {
            final statusCode = e.response!.statusCode;
            if (statusCode == 500) {
                return Result.failure(InternalServerErrorException());
            }
             final detail = e.response!.data?['detail'] ?? e.message;
            return Result.failure(RepositoryException('Get friends failed: $detail'));
        } else {
             return Result.failure(RepositoryException('Network error fetching friends: ${e.message}'));
        }
    } catch (e) {
        _logger.e('Unexpected error fetching friends', error: e, tag: 'UserRepository');
        return Result.failure(RepositoryException('Get friends failed: ${e.toString()}'));
    }
  }

  Future<Result<void>> sendFriendRequest(String username) async {
    _logger.i('Requesting send friend request to: $username', tag: 'UserRepository');
    try {
      final response = await _dio.post(
        '${ApiConfig.usersPath}/friends/request',
        data: json.encode({"username": username}),
      );
      // Assuming 200 or 201 for success (backend might return different)
      // Dio throws for non-2xx, so reaching here implies success
       _logger.i('Send friend request successful', tag: 'UserRepository');
       return Result.success(null);

    } on DioException catch (e) {
        _logger.e('DioException sending friend request', error: e, tag: 'UserRepository');
        if (e.response != null) {
            final statusCode = e.response!.statusCode;
            if(statusCode == 422) {
                // Use ValidationDataError defined in exceptions.dart
                return Result.failure(ValidationDataError("Invalid data sending friend request"));
            }
            if(statusCode == 500) {
                return Result.failure(InternalServerErrorException());
            }
            final detail = e.response!.data?['detail'] ?? e.message;
            return Result.failure(RepositoryException('Send friend request failed: $detail'));
        } else {
            return Result.failure(RepositoryException('Network error sending friend request: ${e.message}'));
        }
    } catch (e) {
         _logger.e('Unexpected error sending friend request', error: e, tag: 'UserRepository');
         return Result.failure(RepositoryException('Send friend request failed: ${e.toString()}'));
    }
  }

  Future<Result<void>> respondToFriendRequest(
      String requestId,
      String action,
      ) async {
    _logger.i('Requesting respond ($action) to friend request ID: $requestId', tag: 'UserRepository');
    try {
       final response = await _dio.post(
        '${ApiConfig.usersPath}/friends/respond',
        data: json.encode({"request_id": requestId, "action": action}),
      );
      // Dio throws for non-2xx
      _logger.i('Respond friend request successful', tag: 'UserRepository');
      return Result.success(null);

    } on DioException catch (e) {
        _logger.e('DioException responding to friend request $requestId', error: e, tag: 'UserRepository');
        if (e.response != null) {
            final statusCode = e.response!.statusCode;
            if(statusCode == 400) { // Backend uses 400 for invalid action
                 return Result.failure(ValidationDataError("Invalid action. Must be 'accept' or 'reject'"));
            }
            if(statusCode == 500) {
                return Result.failure(InternalServerErrorException());
            }
            final detail = e.response!.data?['detail'] ?? e.message;
            return Result.failure(RepositoryException('Respond friend request failed: $detail'));
        } else {
            return Result.failure(RepositoryException('Network error responding to friend request: ${e.message}'));
        }
    } catch (e) {
         _logger.e('Unexpected error responding to friend request $requestId', error: e, tag: 'UserRepository');
         return Result.failure(RepositoryException('Respond friend request failed: ${e.toString()}'));
    }
  }

  Future<Result<List<FriendRequestModel>>> getReceivedFriendRequests() async {
    _logger.i('Requesting received friend requests', tag: 'UserRepository');
    try {
      final response = await _dio.get(
        '${ApiConfig.usersPath}/friends/requests/received',
      );
      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> data = response.data;
        _logger.i('Received friend requests fetch successful', tag: 'UserRepository');
        return Result.success(data.map((json) => FriendRequestModel.fromJson(json)).toList());
      } else {
         _logger.w('Get received requests returned non-200 or invalid data: ${response.statusCode}', tag: 'UserRepository');
         throw RepositoryException('Get received requests failed: Unexpected response format');
      }
    } on DioException catch (e) {
       _logger.e('DioException fetching received friend requests', error: e, tag: 'UserRepository');
        if (e.response != null) {
            final statusCode = e.response!.statusCode;
            if(statusCode == 500) {
              return Result.failure(InternalServerErrorException());
            }
            final detail = e.response!.data?['detail'] ?? e.message;
            return Result.failure(RepositoryException('Get received requests failed: $detail'));
        } else {
             return Result.failure(RepositoryException('Network error fetching received requests: ${e.message}'));
        }
    } catch (e) {
        _logger.e('Unexpected error fetching received requests', error: e, tag: 'UserRepository');
        return Result.failure(RepositoryException('Get received requests failed: ${e.toString()}'));
    }
  }

  Future<Result<List<FriendRequestModel>>> getSentFriendRequests() async {
    _logger.i('Requesting sent friend requests', tag: 'UserRepository');
     try {
        final response = await _dio.get(
          '${ApiConfig.usersPath}/friends/requests/sent',
        );
       if (response.statusCode == 200 && response.data is List) {
          final List<dynamic> data = response.data;
          _logger.i('Sent friend requests fetch successful', tag: 'UserRepository');
          return Result.success(data.map((json) => FriendRequestModel.fromJson(json)).toList());
       } else {
           _logger.w('Get sent requests returned non-200 or invalid data: ${response.statusCode}', tag: 'UserRepository');
           throw RepositoryException('Get sent requests failed: Unexpected response format');
       }
    } on DioException catch (e) {
         _logger.e('DioException fetching sent friend requests', error: e, tag: 'UserRepository');
          if (e.response != null) {
              final statusCode = e.response!.statusCode;
              if(statusCode == 500) {
                return Result.failure(InternalServerErrorException());
              }
              final detail = e.response!.data?['detail'] ?? e.message;
              return Result.failure(RepositoryException('Get sent requests failed: $detail'));
          } else {
               return Result.failure(RepositoryException('Network error fetching sent requests: ${e.message}'));
          }
    } catch (e) {
         _logger.e('Unexpected error fetching sent requests', error: e, tag: 'UserRepository');
          return Result.failure(RepositoryException('Get sent requests failed: ${e.toString()}'));
    }
  }
}
