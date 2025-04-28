import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import 'auth_service.dart';
import '../utils/logger.dart';
import '../repositories/user_repository.dart';
import '../utils/result.dart'; 

class UserService {
  final AuthService _authService;
  final UserRepository _userRepository; 
  final Logger _logger = Logger();

  UserService(this._authService, this._userRepository);


  Future<List<UserModel>> searchUsers(String query) async {
    _logger.d('Executing searchUsers with query: "$query"', tag: 'UserService');
    final token = _authService.token;
    if (token == null) {
      _logger.w('Search users requires authentication', tag: 'UserService');
      throw Exception('Not authenticated'); // Changed to throw
    }
    final Result<List<UserModel>> result = await _userRepository.searchUsers(query, token);

    if (result.isSuccess) {
       _logger.i('User search successful, found ${result.value.length} users', tag: 'UserService');
      return result.value;
    } else {
      _logger.e('Error searching users via repository', error: result.error, tag: 'UserService');
      throw result.error;
    }
  }

  Future<List<UserModel>> getFriends() async {
    _logger.d('Executing getFriends', tag: 'UserService');
    final token = _authService.token;
    if (token == null) {
      _logger.w('Get friends requires authentication', tag: 'UserService');
      throw Exception('Not authenticated'); // Changed to throw
    }
    final Result<List<UserModel>> result = await _userRepository.getFriends(token);

    if (result.isSuccess) {
      _logger.i('Get friends successful, found ${result.value.length} friends', tag: 'UserService');
      return result.value;
    } else {
      _logger.e('Error getting friends via repository', error: result.error, tag: 'UserService');
      throw result.error;
    }
  }

  Future<bool> sendFriendRequest(String username) async {
    _logger.d('Executing sendFriendRequest to username: $username', tag: 'UserService');
    final token = _authService.token;
    if (token == null) {
      _logger.w('Send friend request requires authentication', tag: 'UserService');
      throw Exception('Not authenticated'); 
    }
    final Result<void> result = await _userRepository.sendFriendRequest(username, token);

    if (result.isSuccess) {
      _logger.i('Friend request sent successfully to $username via repository', tag: 'UserService');
      return true;
    } else {
      _logger.e('Error sending friend request to $username via repository', error: result.error, tag: 'UserService');
      throw result.error;
    }
  }

  Future<void> respondToFriendRequest(
    String requestId,
    String action,
  ) async {
    _logger.d('Executing respondToFriendRequest ID: $requestId, action: $action', tag: 'UserService');
    final token = _authService.token;
    if (token == null) {
      _logger.w('Respond to friend request requires authentication', tag: 'UserService');
      throw Exception('Not authenticated');
    }

    if (action != 'accept' && action != 'reject') {
        _logger.e('Invalid action for respondToFriendRequest: $action', tag: 'UserService');
        throw ArgumentError('Action must be either \'accept\' or \'reject\'');
    }

    final Result<void> result = await _userRepository.respondToFriendRequest(requestId, action, token);

    if (result.isSuccess) {
      _logger.i('Successfully responded ($action) to friend request $requestId via repository', tag: 'UserService');
    } else {
      _logger.e('Error responding to friend request $requestId ($action) via repository', error: result.error, tag: 'UserService');
      throw result.error;
    }
  }

  Future<List<FriendRequestModel>> getReceivedFriendRequests() async {
    _logger.d('Executing getReceivedFriendRequests', tag: 'UserService');
    final token = _authService.token;
    if (token == null) {
      _logger.w('Get received friend requests requires authentication', tag: 'UserService');
       throw Exception('Not authenticated'); // Changed to throw
    }
    final Result<List<FriendRequestModel>> result = await _userRepository.getReceivedFriendRequests(token);

    if (result.isSuccess) {
       _logger.i('Get received requests successful, found ${result.value.length} requests', tag: 'UserService');
      return result.value;
    } else {
      _logger.e('Error getting received friend requests via repository', error: result.error, tag: 'UserService');
      throw result.error;
    }
  }

  Future<List<FriendRequestModel>> getSentFriendRequests({
    String? status, // Keep status param if future filtering is planned
  }) async {
    _logger.d('Executing getSentFriendRequests', tag: 'UserService');
    final token = _authService.token;
    if (token == null) {
      _logger.w('Get sent friend requests requires authentication', tag: 'UserService');
      throw Exception('Not authenticated'); // Changed to throw
    }
    // Log if status filter is provided (though not used by repo yet)
    if (status != null) {
       _logger.d('Filtering sent requests by status: $status', tag: 'UserService');
    }
    
    final Result<List<FriendRequestModel>> result = await _userRepository.getSentFriendRequests(token);

    if (result.isSuccess) {
      _logger.i('Get sent requests successful, found ${result.value.length} requests', tag: 'UserService');
      return result.value;
    } else {
      _logger.e('Error getting sent friend requests via repository', error: result.error, tag: 'UserService');
      throw result.error;
    }
  }
}
