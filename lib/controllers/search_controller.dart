import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/message_service.dart';
import '../utils/error_handler.dart';

/// Controller for the search functionality
class SearchController extends ChangeNotifier {
  final String _authToken;
  final MessageService _messageService;
  final UserRepository _userRepo = UserRepository();
  final ErrorHandler _errorHandler = ErrorHandler();
  
  String _searchQuery = '';
  bool _isSearching = false;
  Map<String, List<MessageModel>> _searchResults = {};
  Map<String, UserModel> _friendsMap = {};
  
  /// Constructor
  SearchController({
    required String authToken,
    required UserModel currentUser,
    required MessageService messageService,
  }) : 
    _authToken = authToken,
    _messageService = messageService {
    // Load friends on initialization
    _loadFriends();
  }
  
  /// Get the search query
  String get searchQuery => _searchQuery;
  
  /// Get the searching status
  bool get isSearching => _isSearching;
  
  /// Get the search results
  Map<String, List<MessageModel>> get searchResults => _searchResults;
  
  /// Get the friends map
  Map<String, UserModel> get friendsMap => _friendsMap;
  
  /// Set the search query and perform search
  set searchQuery(String value) {
    _searchQuery = value;
    if (value.length >= 2) {
      performSearch();
    } else {
      _searchResults = {};
      notifyListeners();
    }
  }
  
  /// Load friends
  Future<void> _loadFriends() async {
    try {
      final friends = await _userRepo.getFriends(_authToken);
      _friendsMap = {for (var friend in friends) friend.username: friend};
      notifyListeners();
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace: stackTrace);
    }
  }
  
  /// Perform search
  void performSearch() {
    if (_searchQuery.length < 2) return;
    
    _isSearching = true;
    notifyListeners();
    
    try {
      _searchResults = _messageService.searchMessages(_searchQuery);
      _isSearching = false;
      notifyListeners();
    } catch (e, stackTrace) {
      _isSearching = false;
      _searchResults = {};
      notifyListeners();
      _errorHandler.logError(e, stackTrace: stackTrace);
    }
  }
  
  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    _searchResults = {};
    notifyListeners();
  }
  
  /// Get friend by username
  UserModel? getFriend(String username) {
    return _friendsMap[username];
  }
  
  /// Get display name for a friend
  String getFriendName(String username) {
    return _friendsMap[username]?.displayName ?? username;
  }
} 