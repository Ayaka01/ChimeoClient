// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../config/api_config.dart';

class AuthService with ChangeNotifier {
  UserModel? _user;
  String? _token;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _user != null && _token != null;

  AuthService() {
    _loadUserFromStorage();
  }

  Future<void> _loadUserFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('auth_token');
    final savedUser = prefs.getString('user_data');

    if (savedToken != null && savedUser != null) {
      _token = savedToken;
      _user = UserModel.fromJson(json.decode(savedUser));
      notifyListeners();
    }
  }

  Future<void> _saveUserToStorage() async {
    final prefs = await SharedPreferences.getInstance();

    if (_user != null && _token != null) {
      await prefs.setString('auth_token', _token!);
      await prefs.setString('user_data', json.encode(_user!.toJson()));
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['access_token'];

        _user = UserModel(
          id: data['user_id'],
          username: data['username'],
          displayName: data['display_name'],
          lastSeen: DateTime.now(),
        );

        await _saveUserToStorage();
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      print('Error signing in: $e');
      return false;
    }
  }

  Future<bool> signUp(
    String username,
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
          'display_name': displayName,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _token = data['access_token'];

        _user = UserModel(
          id: data['user_id'],
          username: data['username'],
          displayName: data['display_name'],
          lastSeen: DateTime.now(),
        );

        await _saveUserToStorage();
        notifyListeners();
        return true;
      } else {
        final error = json.decode(response.body);
        throw error['detail'] ?? 'Registration failed';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> signOut() async {
    _user = null;
    _token = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');

    notifyListeners();
  }
}
