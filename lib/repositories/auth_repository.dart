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
          final errorData = e.response!.data;
          String detail = e.message ?? 'Unknown error';
          if (errorData is Map && errorData.containsKey('detail')) {
              detail = errorData['detail'];
          }
          
          // Use specific exceptions based on status code
          if (statusCode == 404) { 
              // Specific handling for Email Not Found
              return Result.failure(LoginException(detail)); // Or create EmailNotFoundException
          }
          if (statusCode == 401) {
            // Handles PasswordIncorrectError from backend
            return Result.failure(InvalidCredentialsException());
          }
           if (statusCode == 422) { 
              // Assuming 422 is still possible for validation errors (though backend uses 400 now)
             return Result.failure(InvalidEmailFormatException());
          }
           if (statusCode == 500) {
            return Result.failure(InternalServerErrorException());
          }
          // Fallback for other 4xx/5xx errors
          return Result.failure(RepositoryException('Sign in failed ($statusCode): $detail'));
      } else {
          // Handle connection errors, timeouts, etc. (no response)
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
        // Backend now returns 200 on success, update check? Assuming 200 is okay.
        if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
             return Result.success(response.data as Map<String, dynamic>);
        } else {
            _logger.w('Sign up returned non-200 or invalid data: ${response.statusCode}', tag: 'AuthRepository');
            throw RepositoryException('Sign up failed: Unexpected response format');
        }

     } on DioException catch (e) {
         _logger.e('DioException during sign up', error: e, tag: 'AuthRepository');
         if (e.response != null) {
            final statusCode = e.response!.statusCode;
            final errorData = e.response!.data;
            String detail = e.message ?? 'Unknown error';
            String? errorCode; // Variable to store the error code
            
            if (errorData is Map) {
                if (errorData.containsKey('detail')) {
                    detail = errorData['detail'];
                }
                if (errorData.containsKey('error_code')) {
                    errorCode = errorData['error_code']; // Parse error code
                }
            }

            if (statusCode == 409) { // Conflict for existing user/email
                if (errorCode == "USERNAME_EXISTS") {
                    return Result.failure(UsernameTakenException());
                }
                if (errorCode == "EMAIL_EXISTS") {
                    return Result.failure(EmailInUseException());
                }
                // Fallback for unexpected 409
                 return Result.failure(RegistrationException('Registration conflict: $detail'));
            }
            if (statusCode == 400) { // Bad Request for validation errors
                 if (errorCode == "USERNAME_TOO_SHORT") {
                    return Result.failure(UsernameTooShortException());
                }
                 if (errorCode == "WEAK_PASSWORD") {
                    return Result.failure(PasswordTooWeakException());
                }
                // Fallback for other 400 errors
                 return Result.failure(RegistrationException('Registration failed: $detail'));
            }
            if (statusCode == 422) { 
                // If backend can still send 422 for other validation
                return Result.failure(InvalidEmailFormatException()); // Or a more generic ValidationDataError
            }
             if (statusCode == 500) {
                 return Result.failure(InternalServerErrorException());
            }
            // Fallback for other status codes
            return Result.failure(RepositoryException('Sign up failed ($statusCode): $detail'));
         } else {
            // Handle connection errors, timeouts, etc. (no response)
            return Result.failure(RepositoryException('Sign up failed: ${e.message}'));
         }
      } catch (e) {
         _logger.e('Unexpected error during sign up', error: e, tag: 'AuthRepository');
        return Result.failure(RepositoryException('Sign up failed: ${e.toString()}'));
      }
  }
  
  // Accept an optional Dio instance, default to the global one
  Future<Result<Map<String, dynamic>>> refreshAuthToken(String refreshToken, {Dio? dioInstance}) async {
      // Use the dedicated dio instance for refresh to avoid interceptor loop
      final dioClient = dioForRefresh; 
      try {
          _logger.d('Attempting token refresh', tag: 'AuthRepository');
          // Refresh token should be sent in the header now
          final response = await dioClient.post(
              '${ApiConfig.authPath}/refresh',
              options: Options(headers: {'Authorization': 'Bearer $refreshToken'})
          );
          
          if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
              _logger.i('Token refresh successful', tag: 'AuthRepository');
              return Result.success(response.data as Map<String, dynamic>);
          } else {
               _logger.w('Token refresh returned non-200 or invalid data: ${response.statusCode}', tag: 'AuthRepository');
              // Use specific exception if possible based on backend contract
              return Result.failure(RepositoryException('Token refresh failed: Unexpected response format'));
          }
      } on DioException catch (e) {
          _logger.e('DioException during token refresh', error: e, tag: 'AuthRepository');
          if (e.response != null) {
              final statusCode = e.response!.statusCode;
              final errorData = e.response!.data;
              String detail = e.message ?? 'Unknown error';
              if (errorData is Map && errorData.containsKey('detail')) {
                 detail = errorData['detail'];
              }
               if (statusCode == 401) {
                  // Invalid/Expired refresh token
                  _logger.w('Token refresh failed (401): $detail', tag: 'AuthRepository');
                  return Result.failure(InvalidCredentialsException()); // Or a specific RefreshTokenExpiredException
               }
               if (statusCode == 500) {
                 _logger.w('Token refresh failed (500): $detail', tag: 'AuthRepository');
                 return Result.failure(InternalServerErrorException());
               }
               // Fallback for other errors during refresh
               _logger.w('Token refresh failed ($statusCode): $detail', tag: 'AuthRepository');
               return Result.failure(RepositoryException('Token refresh failed ($statusCode): $detail'));
          } else {
              // Network/connection error during refresh
               _logger.w('Token refresh failed (Connection Error): ${e.message}', tag: 'AuthRepository');
               return Result.failure(RepositoryException('Token refresh failed: ${e.message}'));
          }
      } catch (e) {
           _logger.e('Unexpected error during token refresh', error: e, tag: 'AuthRepository');
          return Result.failure(RepositoryException('Token refresh failed: ${e.toString()}'));
      }
  }
}
