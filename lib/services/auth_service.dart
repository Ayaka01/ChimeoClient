import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'local_storage_service.dart';
import '../repositories/auth_repository.dart';
import '../utils/logger.dart';
import 'package:provider/provider.dart';
import '../services/message_service.dart';
import 'package:flutter/material.dart';

// Keys for storing auth data in SharedPreferences
const String _tokenKey = 'auth_token';
const String _userDataKey = 'user_data';

class AuthService with ChangeNotifier {
  UserModel? _user;
  String? _token;
  final LocalStorageService _storageService = LocalStorageService();
  final AuthRepository _authRepo = AuthRepository();
  final Logger _logger = Logger();

  UserModel? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _user != null && _token != null;

  AuthService() {
    _loadAuthData();
  }

  Future<void> _loadAuthData() async {
    try {
      // Directly load from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userDataString = prefs.getString(_userDataKey);

      if (token != null && userDataString != null) {
        _token = token;
        _user = UserModel.fromJson(json.decode(userDataString));
        notifyListeners();
      }
    } catch (e) {
      _logger.e('Error loading auth data', error: e, tag: 'AuthService');
    }
  }

  Future<void> _saveUserToStorage() async {
    final prefs = await SharedPreferences.getInstance();

    if (_user != null && _token != null) {
      // Use the defined keys
      await prefs.setString(_tokenKey, _token!);
      await prefs.setString(_userDataKey, json.encode(_user!.toJson()));
    }
  }

  Future<UserModel> signIn(String email, String password) async {
    try {
      final authData = await _authRepo.signIn(email, password);
      
      if (authData == null) {
        throw Exception('Error en el inicio de sesión: No se recibieron datos');
      }
      
      _token = authData['access_token'];
      _user = UserModel(
        username: authData['username'],
        displayName: authData['display_name'],
        lastSeen: DateTime.now(),
      );
      
      await _saveUserToStorage();
      notifyListeners();
      return _user!;
    } catch (e) {
      _logger.e('Error signing in', error: e, tag: 'AuthService');
      rethrow;
    }
  }

  Future<UserModel> signUp(
    String username,
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final authData = await _authRepo.signUp(
        username,
        email,
        password,
        displayName,
      );
      
      if (authData == null) {
        throw Exception('Error en el registro: No se recibieron datos');
      }
      
      _token = authData['access_token'];
      _user = UserModel(
        username: authData['username'],
        displayName: authData['display_name'],
        lastSeen: DateTime.now(),
      );
      
      await _saveUserToStorage();
      notifyListeners();
      return _user!;
    } catch (e) {
      _logger.e('Error signing up', error: e, tag: 'AuthService');
      rethrow;
    }
  }

  Future<bool> signOut(BuildContext context) async {
    try {
      // Directly clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userDataKey);

      _token = null;
      _user = null;
      
      await _storageService.clearAllConversations();
      
      // Disconnect WebSocket and clear message data
      final messageService = Provider.of<MessageService>(context, listen: false);
      messageService.disconnectWebSocket();
      messageService.clearData();
      
      notifyListeners();
      return true;
    } catch (e) {
      _logger.e('Error signing out', error: e, tag: 'AuthService');
      return false;
    }
  }
}
