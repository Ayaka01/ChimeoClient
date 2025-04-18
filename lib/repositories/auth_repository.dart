import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import 'base_repository.dart';

/// Repository for handling authentication-related data access
class AuthRepository extends BaseRepository {
  /// Singleton instance
  static final AuthRepository _instance = AuthRepository._internal();
  
  /// Keys for storing auth data in SharedPreferences
  static const String _tokenKey = 'auth_token';
  static const String _userDataKey = 'user_data';
  
  /// Private constructor
  AuthRepository._internal();
  
  /// Factory constructor to return the singleton instance
  factory AuthRepository() => _instance;
  
  /// Sign in with email and password
  Future<Map<String, dynamic>?> signIn(String email, String password) async {
    return await executeSafe<Map<String, dynamic>>(() async {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authPath}/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Credenciales inválidas');
      }
      
      throw Exception('Error en el inicio de sesión: ${response.statusCode}');
    });
  }
  
  /// Sign up with new account details
  Future<Map<String, dynamic>?> signUp(
    String username,
    String email,
    String password,
    String displayName,
  ) async {
    return await executeSafe<Map<String, dynamic>>(() async {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authPath}/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
          'display_name': displayName,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Error en el registro');
    });
  }
  
  /// Save authentication data to SharedPreferences
  Future<bool> saveAuthData(String token, UserModel user) async {
    return await executeSafeBool(() async {
      final prefs = await SharedPreferences.getInstance();
      
      // Save token and user data
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userDataKey, json.encode(user.toJson()));
    });
  }
  
  /// Load authentication data from SharedPreferences
  Future<Map<String, dynamic>?> loadAuthData() async {
    return await executeSafe<Map<String, dynamic>>(() async {
      final prefs = await SharedPreferences.getInstance();
      
      final token = prefs.getString(_tokenKey);
      final userData = prefs.getString(_userDataKey);
      
      if (token == null || userData == null) {
        return <String, dynamic>{};  // Return empty map instead of null
      }
      
      return {
        'token': token,
        'user': UserModel.fromJson(json.decode(userData)),
      };
    });
  }
  
  /// Clear authentication data from SharedPreferences
  Future<bool> clearAuthData() async {
    return await executeSafeBool(() async {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove token and user data
      await prefs.remove(_tokenKey);
      await prefs.remove(_userDataKey);
    });
  }
} 