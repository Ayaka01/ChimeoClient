import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:simple_messenger/utils/exceptions.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import 'base_repository.dart';
import '../utils/result.dart';
import '../utils/logger.dart';

class UserRepository extends BaseRepository {
  static final UserRepository _instance = UserRepository._internal();
  final Logger _logger = Logger();

  UserRepository._internal();
  factory UserRepository() => _instance;

  Future<Result<List<UserModel>>> searchUsers(
    String query,
    String token,
  ) async {
    _logger.i('Requesting user search with query: "$query"', tag: 'UserRepository');
    return await executeSafe<List<UserModel>>(() async {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.usersPath}/search?q=${Uri.encodeComponent(query)}',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 422) {
        throw UsernameTooShortException();
      }

      if (response.statusCode == 500) {
        throw InternalServerErrorException();
      }

      final List<dynamic> data = json.decode(response.body);
      _logger.i('User search successful', tag: 'UserRepository');
      return data.map((json) => UserModel.fromJson(json)).toList();
    });
  }

  Future<Result<List<UserModel>>> getFriends(String token) async {
    _logger.i('Requesting friends list', tag: 'UserRepository');
    return await executeSafe<List<UserModel>>(() async {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.usersPath}/friends',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 500) {
        throw InternalServerErrorException();
      }

      final List<dynamic> data = json.decode(response.body);
      _logger.i('Friends list fetch successful', tag: 'UserRepository');
      return data.map((json) => UserModel.fromJson(json)).toList();
    });
  }

  Future<Result<void>> sendFriendRequest(String username, String token) async {
    _logger.i('Requesting send friend request to: $username', tag: 'UserRepository');
    return await executeSafe<void>(() async {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.usersPath}/friends/request',
      );
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({"username": username}),
      );

      if(response.statusCode == 422) {
        throw ValidationDataError("Datos inválidos");
      }

      if(response.statusCode == 500) {
        throw InternalServerErrorException();
      }
      _logger.i('Send friend request successful', tag: 'UserRepository');
    });
  }

  Future<Result<void>> respondToFriendRequest(
      String requestId,
      String action,
      String token,
      ) async {
    _logger.i('Requesting respond ($action) to friend request ID: $requestId', tag: 'UserRepository');
    return await executeSafe<void>(() async {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.usersPath}/friends/respond',
      );
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({"request_id": requestId, "action": action}),
      );

      if(response.statusCode == 422) {
        throw ValidationDataError("Action must be either 'accept' or 'reject'");
      }

      if(response.statusCode == 500) {
        throw InternalServerErrorException();
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
         throw Exception('Failed to respond to friend request: ${response.statusCode} ${response.body}');
      }
      _logger.i('Respond friend request successful', tag: 'UserRepository');
    });
  }

  Future<Result<List<FriendRequestModel>>> getReceivedFriendRequests(String token) async {
    _logger.i('Requesting received friend requests', tag: 'UserRepository');
    return await executeSafe<List<FriendRequestModel>>(() async {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.usersPath}/friends/requests/received',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if(response.statusCode == 500) {
        throw InternalServerErrorException();
      }

      final List<dynamic> data = json.decode(response.body);
      _logger.i('Received friend requests fetch successful', tag: 'UserRepository');
      return data.map((json) => FriendRequestModel.fromJson(json)).toList();
    });
  }

  Future<Result<List<FriendRequestModel>>> getSentFriendRequests(String token) async {
    _logger.i('Requesting sent friend requests', tag: 'UserRepository');
    return await executeSafe<List<FriendRequestModel>>(() async {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.usersPath}/friends/requests/sent',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if(response.statusCode == 500) {
        throw InternalServerErrorException();
      }

      final List<dynamic> data = json.decode(response.body);
      _logger.i('Sent friend requests fetch successful', tag: 'UserRepository');
      return data.map((json) => FriendRequestModel.fromJson(json)).toList();
    });
  }
}
