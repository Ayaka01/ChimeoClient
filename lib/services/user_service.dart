// lib/services/user_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class UserService {
  final AuthService _authService;

  UserService(this._authService);

  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => UserModel.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/$userId'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(json.decode(response.body));
      }

      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }
}
