import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:simple_messenger/utils/exceptions.dart';
import '../config/api_config.dart';
import 'base_repository.dart';

class AuthRepository extends BaseRepository {
  static final AuthRepository _instance = AuthRepository._singletonInstance();

  // Private constructor
  AuthRepository._singletonInstance();

  // Factory constructor to return the singleton instance
  factory AuthRepository() => _instance;

  Future<Map<String, dynamic>?> signIn(String email, String password) async {
    return await executeSafe<Map<String, dynamic>>(() async {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authPath}/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 422) {
        throw InvalidEmailFormatException();
      } else if (response.statusCode == 401) {
        throw InvalidCredentialsException();
      } else {
        throw LoginException('Login failed due to an unexpected server response.');
      }
    });
  }

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

      if(response.statusCode == 201) {
        return json.decode(response.body);
      } else if (response.statusCode == 422) {
        throw InvalidEmailFormatException();
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        final detail = error['detail'] as String?;

        if (detail != null) {
          if (detail.contains("Username must be at least")) {
            throw UsernameTooShortException();
          } else if (detail == "Username already taken") {
            throw UsernameTakenException();
          } else if (detail == "Email already registered") {
            throw EmailInUseException();
          } else if (detail.contains("Password is too weak") ||
              detail.contains("Password must contain")) {
            throw PasswordTooWeakException();
          } else {
            throw RegistrationException(detail);
          }
        } else {
          throw RegistrationException(
            "Registration failed with status code 400.",
          );
        }
      } else {
        throw RegistrationException("Could not connect to server");
      }
    });
  }
}
