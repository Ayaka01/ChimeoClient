import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../utils/result.dart';
import 'local_storage_service.dart';
import '../repositories/auth_repository.dart';
import '../utils/logger.dart';
import 'package:provider/provider.dart';
import '../services/message_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// Define Secure Storage keys
const String _secureTokenKey = 'auth_token';
const String _secureRefreshTokenKey = 'refresh_token'; // Key for refresh token
const String _secureUserDataKey = 'user_data';

class AuthService with ChangeNotifier {
  UserModel? _user;
  String? _token; // Access Token
  String? _refreshToken; // Refresh Token
  final LocalStorageService _storageService = LocalStorageService(); // Still used for non-auth data clear on logout
  final AuthRepository _authRepo;
  final Logger _logger = Logger();

  // To securely store the token and the user's data
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  UserModel? get user => _user;
  String? get token => _token; // Access Token getter
  String? get refreshToken => _refreshToken; // Refresh Token getter
  bool get isAuthenticated => _user != null && _token != null;

  // Constructor
  AuthService(this._authRepo) {
    _logger.d('AuthService initialized', tag: 'AuthService');
    _loadAuthData();
  }

  Future<void> _loadAuthData() async {
    _logger.d('Attempting to load auth data from storage', tag: 'AuthService');
    try {
      // Read both access and refresh tokens
      final accessToken = await _secureStorage.read(key: _secureTokenKey);
      final refreshToken = await _secureStorage.read(key: _secureRefreshTokenKey);
      final userDataString = await _secureStorage.read(key: _secureUserDataKey);

      if (accessToken != null && refreshToken != null && userDataString != null) {
        _token = accessToken;
        _refreshToken = refreshToken;
        _user = UserModel.fromJson(json.decode(userDataString));
        _logger.i('Auth data loaded successfully from storage for user: ${_user?.username}', tag: 'AuthService');
        notifyListeners();
      } else {
        _logger.i('No complete auth data found in storage', tag: 'AuthService');
        // Clear potentially partial data if incomplete
        await _clearAuthDataFromStorage(); 
      }

    } catch (e) {
      _logger.e('Error loading auth data', error: e, tag: 'AuthService');
      // Clear data on error to avoid inconsistent state
      await _clearAuthDataFromStorage();
    }
  }

  // Renamed to reflect saving BOTH tokens and user data
  Future<void> _saveTokensAndUserData(String accessToken, String refreshToken, UserModel user) async {
    _logger.d('Saving tokens and user data to storage for user: ${user.username}', tag: 'AuthService');
    try {
      await _secureStorage.write(key: _secureTokenKey, value: accessToken);
      await _secureStorage.write(key: _secureRefreshTokenKey, value: refreshToken);
      await _secureStorage.write(
        key: _secureUserDataKey,
        value: json.encode(user.toJson()),
      );
      // Update internal state AFTER successful save
      _token = accessToken;
      _refreshToken = refreshToken;
      _user = user;
      _logger.i('Tokens and user data saved successfully', tag: 'AuthService');
      notifyListeners(); // Notify after state is updated
    } catch (e) {
      _logger.e('Failed to save tokens and user data', error: e, tag: 'AuthService');
      // Optionally clear state if save fails?
    }
  }
  
  // Helper to clear only auth-related keys
  Future<void> _clearAuthDataFromStorage() async {
    _logger.d('Clearing auth data from secure storage', tag: 'AuthService');
    try {
      await _secureStorage.delete(key: _secureTokenKey);
      await _secureStorage.delete(key: _secureRefreshTokenKey);
      await _secureStorage.delete(key: _secureUserDataKey);
    } catch (e) {
      _logger.e('Error clearing auth data from secure storage', error: e, tag: 'AuthService');
    }
  }

  Future<UserModel> signIn(String email, String password) async {
    final loggedEmail = kDebugMode ? email : '[REDACTED]';
    _logger.i('Attempting sign in for email: $loggedEmail', tag: 'AuthService');
    final Result<Map<String, dynamic>> result = await _authRepo.signIn(email, password);

    if (result.isSuccess) {
      final Map<String, dynamic> authData = result.value;

      // Extract both tokens
      final accessToken = authData['access_token'];
      final refreshToken = authData['refresh_token']; 
      final userModel = UserModel(
        username: authData['username'],
        displayName: authData['display_name'],
      );

      if (accessToken == null || refreshToken == null) {
        _logger.e('Sign in response missing required tokens', tag: 'AuthService');
        throw Exception('Authentication failed: Server response incomplete.');
      }

      _logger.i('Sign in successful for user: ${userModel.username}', tag: 'AuthService');
      // Save both tokens and user data
      await _saveTokensAndUserData(accessToken, refreshToken, userModel);
      // No need to call notifyListeners here, _saveTokensAndUserData does it

      return userModel;

    } else {
      _logger.w('Sign in failed', error: result.error, tag: 'AuthService');
      throw result.error;
    }
  }

  Future<UserModel> signUp(
    String username,
    String email,
    String password,
    String displayName,
  ) async {
    final loggedEmail = kDebugMode ? email : '[REDACTED]';
    _logger.i('Attempting sign up for username: $username, email: $loggedEmail', tag: 'AuthService');
    final Result<Map<String, dynamic>> result = await _authRepo.signUp(username, email, password, displayName);

    if (result.isSuccess) {
      final Map<String, dynamic> authData = result.value;

      // Extract both tokens
      final accessToken = authData['access_token'];
      final refreshToken = authData['refresh_token'];
      final userModel = UserModel(
        username: authData['username'],
        displayName: authData['display_name'],
      );

      if (accessToken == null || refreshToken == null) {
        _logger.e('Sign up response missing required tokens', tag: 'AuthService');
        throw Exception('Registration failed: Server response incomplete.');
      }

      _logger.i('Sign up successful for user: ${userModel.username}', tag: 'AuthService');
      // Save both tokens and user data
      await _saveTokensAndUserData(accessToken, refreshToken, userModel);
      // No need to call notifyListeners here, _saveTokensAndUserData does it

      return userModel;

    } else {
      _logger.w('Sign up failed', error: result.error, tag: 'AuthService');
      throw result.error;
    }
  }

  Future<bool> signOut() async {
    final username = _user?.username ?? 'unknown';
    _logger.i('Attempting sign out for user: $username', tag: 'AuthService');
    try {
      // Clear secure storage
      await _clearAuthDataFromStorage();

      // Clear internal state
      _token = null;
      _refreshToken = null;
      _user = null;

      // Clear non-secure storage (conversations) - Keep this if LocalStorageService is independent
      await _storageService.clearAllConversations();

      // Remove MessageService handling from here
      // The UI layer listening to AuthService changes should handle this
      /*
      try {
        final messageService = Provider.of<MessageService>(context, listen: false);
        messageService.disconnect();
        await messageService.clearAllLocalConversations();
      } catch (e) {
        _logger.e('Error accessing MessageService during sign out', error: e, tag: 'AuthService');
      }
      */

      _logger.i('Sign out successful for user: $username (state cleared)', tag: 'AuthService');
      notifyListeners(); // Notify UI about logout state

      return true;

    } catch (e) {
      _logger.e('Error signing out user: $username', error: e, tag: 'AuthService');
      // Ensure state is cleared even if error occurs (e.g., during storage clear)
      _token = null;
      _refreshToken = null;
      _user = null;
      notifyListeners();
      return false;
    }
  }

  // Method called by AuthInterceptor after successful token refresh
  Future<void> handleSuccessfulRefresh(Map<String, dynamic> tokenData) async {
    final accessToken = tokenData['access_token'] as String?;
    final refreshToken = tokenData['refresh_token'] as String?; // Backend sends back the same one
    final user = this.user; // Get current user

    if (accessToken != null && refreshToken != null && user != null) {
      _logger.i('Handling successful token refresh for user: ${user.username}', tag: 'AuthService');
      // Use the existing save method to update state and secure storage
      await _saveTokensAndUserData(accessToken, refreshToken, user);
    } else {
      // Include tokenData details in the message string
      _logger.e(
        'handleSuccessfulRefresh received invalid data or user was null. Data: ${jsonEncode(tokenData)}',
        tag: 'AuthService'
      ); 
      // If data is invalid, potentially log out
      // await signOut(); // Consider if this is appropriate
    }
  }
}
