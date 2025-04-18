import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/conversation_model.dart';
import '../repositories/user_repository.dart';
import '../utils/error_handler.dart';

/// Controller for the home screen that manages friends and conversations
class HomeController extends ChangeNotifier {
  final String _authToken;
  final UserRepository _userRepo = UserRepository();
  final ErrorHandler _errorHandler = ErrorHandler();
  
  List<UserModel> _friends = [];
  bool _isLoadingFriends = false;
  String _searchQuery = '';
  bool _isSearching = false;
  
  /// Constructor
  HomeController({
    required String authToken,
    required UserModel currentUser,
  }) : 
    _authToken = authToken {
    // Load friends on initialization
    loadFriends();
  }
  
  /// Get the list of friends
  List<UserModel> get friends => _friends;
  
  /// Get loading status
  bool get isLoadingFriends => _isLoadingFriends;
  
  /// Get search query
  String get searchQuery => _searchQuery;
  
  /// Get searching status
  bool get isSearching => _isSearching;
  
  /// Set search query
  set searchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }
  
  /// Set searching status
  set isSearching(bool value) {
    _isSearching = value;
    if (!value) {
      _searchQuery = '';
    }
    notifyListeners();
  }
  
  /// Load or refresh friends list
  Future<void> loadFriends() async {
    if (_isLoadingFriends) return;
    
    _isLoadingFriends = true;
    notifyListeners();
    
    try {
      final friends = await _userRepo.getFriends(_authToken);
      _friends = friends;
      _isLoadingFriends = false;
      notifyListeners();
    } catch (e, stackTrace) {
      _isLoadingFriends = false;
      notifyListeners();
      _errorHandler.logError(e, stackTrace: stackTrace);
    }
  }
  
  /// Filter friends by search query
  List<UserModel> getFilteredFriends() {
    if (_searchQuery.isEmpty) return _friends;
    
    final query = _searchQuery.toLowerCase();
    return _friends.where((friend) {
      return friend.displayName.toLowerCase().contains(query) ||
             friend.username.toLowerCase().contains(query) ||
             (friend.statusMessage?.toLowerCase().contains(query) ?? false);
    }).toList();
  }
  
  /// Filter conversations by search query
  List<MapEntry<String, ConversationModel>> getFilteredConversations(
    Map<String, ConversationModel> conversations
  ) {
    if (conversations.isEmpty) return [];
    
    final sortedConversations = conversations.entries.toList()
      ..sort((a, b) {
        final aTime = a.value.lastMessage?.timestamp ?? DateTime(2000);
        final bTime = b.value.lastMessage?.timestamp ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
    
    if (_searchQuery.isEmpty) return sortedConversations;
    
    final query = _searchQuery.toLowerCase();
    return sortedConversations.where((entry) {
      final conversation = entry.value;
      return conversation.friendName.toLowerCase().contains(query) ||
             conversation.friendUsername.toLowerCase().contains(query);
    }).toList();
  }
  
  /// Find a friend by username
  UserModel? findFriendByUsername(String username) {
    try {
      return _friends.firstWhere((f) => f.username == username);
    } catch (e) {
      return null;
    }
  }
  
  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }
} 