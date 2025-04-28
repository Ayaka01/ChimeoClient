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
import 'package:flutter/foundation.dart'; // For kDebugMode

// Define Secure Storage keys
const String _secureTokenKey = 'auth_token';
const String _secureUserDataKey = 'user_data';

class AuthService with ChangeNotifier {
  UserModel? _user;
  String? _token;
  final LocalStorageService _storageService = LocalStorageService();
  final AuthRepository _authRepo;
  final Logger _logger = Logger();

  // To securely store the token and the user's data
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  UserModel? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _user != null && _token != null;

  // Constructor
  AuthService(this._authRepo) {
    _logger.d('AuthService initialized', tag: 'AuthService');
    _loadAuthData();
  }

  Future<void> _loadAuthData() async {
    _logger.d('Attempting to load auth data from storage', tag: 'AuthService');
    try {
      final token = await _secureStorage.read(key: _secureTokenKey);
      final userDataString = await _secureStorage.read(key: _secureUserDataKey);

      if (token != null && userDataString != null) {
        _token = token;
        _user = UserModel.fromJson(json.decode(userDataString));
        _logger.i('Auth data loaded successfully from storage for user: ${_user?.username}', tag: 'AuthService');
        notifyListeners();
      } else {
        _logger.i('No auth data found in storage', tag: 'AuthService');
      }
    } catch (e) {
      _logger.e('Error loading auth data', error: e, tag: 'AuthService');
    }
  }

  Future<void> _saveAuthDataToStorage() async {
    if (_token == null || _user == null) {
        _logger.w('Attempted to save null auth data to storage', tag: 'AuthService');
        return;
    }
    _logger.d('Saving auth data to storage for user: ${_user!.username}', tag: 'AuthService');
    try {
      await _secureStorage.write(key: _secureTokenKey, value: _token!);
      await _secureStorage.write(
        key: _secureUserDataKey,
        value: json.encode(_user!.toJson()),
      );
      _logger.i('Auth data saved successfully', tag: 'AuthService');
    } catch (e) {
      _logger.e('Failed to save auth data', error: e, tag: 'AuthService');
    }
  }

  Future<UserModel> signIn(String email, String password) async {
    // Avoid logging password in production
    final loggedEmail = kDebugMode ? email : '[REDACTED]';
    _logger.i('Attempting sign in for email: $loggedEmail', tag: 'AuthService');
    final Result<Map<String, dynamic>> result = await _authRepo.signIn(email, password);

    if (result.isSuccess) {
      final Map<String, dynamic> authData = result.value;

      _token = authData['access_token'];
      _user = UserModel(
        username: authData['username'],
        displayName: authData['display_name'],
      );

      _logger.i('Sign in successful for user: ${_user!.username}', tag: 'AuthService');
      await _saveAuthDataToStorage();
      notifyListeners();

      return _user!;
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

      _token = authData['access_token'];
      _user = UserModel(
        username: authData['username'],
        displayName: authData['display_name'],
      );

      _logger.i('Sign up successful for user: ${_user!.username}', tag: 'AuthService');
      await _saveAuthDataToStorage();
      notifyListeners();

      return _user!;

    } else {
      _logger.w('Sign up failed', error: result.error, tag: 'AuthService');
      throw result.error;
    }
  }

  Future<bool> signOut(BuildContext context) async {
    final username = _user?.username ?? 'unknown';
    _logger.i('Attempting sign out for user: $username', tag: 'AuthService');
    try {
      await _secureStorage.delete(key: _secureTokenKey);
      await _secureStorage.delete(key: _secureUserDataKey);

      _token = null;
      _user = null;

      await _storageService.clearAllConversations();

      final messageService = context.read<MessageService>();
      messageService.disconnectWebSocket();
      messageService.clearData();

      _logger.i('Sign out successful for user: $username', tag: 'AuthService');
      notifyListeners();

      return true;

    } catch (e) {
      _logger.e('Error signing out user: $username', error: e, tag: 'AuthService');
      return false;
    }
  }
}
