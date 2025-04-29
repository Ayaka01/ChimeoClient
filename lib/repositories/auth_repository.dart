import 'dart:convert';
// import 'package:http/http.dart' as http; // Remove http
import 'package:dio/dio.dart'; // Import dio
import '../config/api_config.dart';
// import 'base_repository.dart'; // Remove BaseRepository for now
import 'package:simple_messenger/utils/exceptions.dart'; // Keep general import
import '../utils/result.dart';
import '../utils/logger.dart'; // Import logger
import '../utils/dio_client.dart'; // Correct path to dio_client

// class AuthRepository extends BaseRepository {
class AuthRepository {
  // static final AuthRepository _instance = AuthRepository._internal(); // Remove singleton for now if injecting Dio
  // Use the global Dio instance
  final Dio _dio = dio;
  final Logger _logger = Logger(); // Add logger

  // Constructor accepting Dio instance
  // AuthRepository(this._dio);

  // Factory constructor removed or adapted if singleton needed later with Dio injection
  // AuthRepository._internal();
  // factory AuthRepository() => _instance;

  Future<Result<Map<String, dynamic>>> signIn(
    String email,
    String password,
  ) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.authPath}/login', // Use relative path if base URL is set in Dio
        data: json.encode({'email': email, 'password': password}),
      );

      // Dio automatically throws for non-2xx status codes by default
      // If specific handling needed, check response.data
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
         return Result.success(response.data as Map<String, dynamic>);
      } else {
          // This path might not be reached if Dio throws first
          _logger.w('Sign in returned non-success or invalid data: ${response.statusCode}', tag: 'AuthRepository');
          throw RepositoryException('Sign in failed: Unexpected response format');
      }

    } on DioException catch (e) {
      _logger.e('DioException during sign in', error: e, tag: 'AuthRepository');
      // Handle specific Dio errors (e.g., connection errors)
      if (e.response != null) {
          // Handle specific HTTP status codes from the response
          final statusCode = e.response!.statusCode;
          if (statusCode == 422) {
             return Result.failure(InvalidEmailFormatException());
          }
          if (statusCode == 401) {
            return Result.failure(InvalidCredentialsException());
          }
           if (statusCode == 500) {
            return Result.failure(InternalServerErrorException());
          }
          // Extract detail if possible
          final detail = e.response!.data?['detail'] ?? e.message;
          return Result.failure(RepositoryException('Sign in failed: $detail'));
      } else {
          // Handle connection errors, timeouts, etc.
          return Result.failure(RepositoryException('Sign in failed: ${e.message}'));
      }
    } catch (e) {
      _logger.e('Unexpected error during sign in', error: e, tag: 'AuthRepository');
      return Result.failure(RepositoryException('Sign in failed: ${e.toString()}'));
    }
  }

  Future<Result<Map<String, dynamic>>> signUp(
    String username,
    String email,
    String password,
    String displayName,
  ) async {
     try {
        final response = await _dio.post(
            '${ApiConfig.authPath}/register', // Use relative path
            data: json.encode({
                'username': username,
                'email': email,
                'password': password,
                'display_name': displayName,
            }),
        );

        // Check for 201 Created specifically
        if (response.statusCode == 201 && response.data is Map<String, dynamic>) {
             return Result.success(response.data as Map<String, dynamic>);
        } else {
            _logger.w('Sign up returned non-201 or invalid data: ${response.statusCode}', tag: 'AuthRepository');
            throw RepositoryException('Sign up failed: Unexpected response format');
        }

     } on DioException catch (e) {
         _logger.e('DioException during sign up', error: e, tag: 'AuthRepository');
         if (e.response != null) {
            final statusCode = e.response!.statusCode;
            final errorData = e.response!.data;
            String detail = e.message ?? 'Unknown error';
            if (errorData is Map && errorData.containsKey('detail')) {
                detail = errorData['detail'];
            }

            if (statusCode == 422) {
                return Result.failure(InvalidEmailFormatException());
            }
            if (statusCode == 400) {
                if (detail.contains("Username must be at least")) {
                    return Result.failure(UsernameTooShortException());
                }
                if (detail == "Username already taken") {
                    return Result.failure(UsernameTakenException());
                }
                if (detail == "Email already registered") {
                    return Result.failure(EmailInUseException());
                }
                if (detail.contains("Password must")) {
                    return Result.failure(PasswordTooWeakException());
                }
                // Generic 400
                 return Result.failure(RepositoryException('Sign up failed: $detail'));
            }
             if (statusCode == 500) {
                 return Result.failure(InternalServerErrorException());
            }
            // Other status codes
            return Result.failure(RepositoryException('Sign up failed: $detail'));
         } else {
            return Result.failure(RepositoryException('Sign up failed: ${e.message}'));
         }
      } catch (e) {
         _logger.e('Unexpected error during sign up', error: e, tag: 'AuthRepository');
        return Result.failure(RepositoryException('Sign up failed: ${e.toString()}'));
      }
  }
  
  // Accept an optional Dio instance, default to the global one
  Future<Result<Map<String, dynamic>>> refreshAuthToken(String refreshToken, {Dio? dioInstance}) async {
      final dioClient = dioInstance ?? _dio; // Use provided Dio or the default one
      try {
          final response = await dioClient.post( // Use the selected Dio client
              '${ApiConfig.authPath}/refresh',
              data: json.encode({'refresh_token': refreshToken}),
          );
          
          if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
              return Result.success(response.data as Map<String, dynamic>);
          } else {
               _logger.w('Token refresh returned non-200 or invalid data: ${response.statusCode}', tag: 'AuthRepository');
              throw RepositoryException('Token refresh failed: Unexpected response format');
          }
      } on DioException catch (e) {
          _logger.e('DioException during token refresh', error: e, tag: 'AuthRepository');
          if (e.response != null) {
              final statusCode = e.response!.statusCode;
              final detail = e.response!.data?['detail'] ?? e.message;
               if (statusCode == 401) {
                  return Result.failure(InvalidCredentialsException());
               }
               if (statusCode == 500) { // Added check for 500
                 return Result.failure(InternalServerErrorException());
               }
               return Result.failure(RepositoryException('Token refresh failed: $detail'));
          } else {
               return Result.failure(RepositoryException('Token refresh failed: ${e.message}'));
          }
      } catch (e) {
           _logger.e('Unexpected error during token refresh', error: e, tag: 'AuthRepository');
          return Result.failure(RepositoryException('Token refresh failed: ${e.toString()}'));
      }
  }
}
