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
          // This case is less likely if Dio throws for non-2xx by default
          _logger.w('Sign in returned non-success or invalid data: ${response.statusCode}', tag: 'AuthRepository');
          // Throw a generic exception or try to parse as an API error if possible
          throw ApiException(message: 'Sign in failed: Unexpected response format', statusCode: response.statusCode);
      }

    } on DioException catch (e) {
      _logger.e('DioException during sign in', error: e, tag: 'AuthRepository');
      // Use the centralized mapping function
      return Result.failure(mapDioExceptionToApiException(e));
    } catch (e) {
       // Catch other potential exceptions (e.g., the ApiException thrown above)
       _logger.e('Unexpected error during sign in', error: e, tag: 'AuthRepository');
       if (e is Exception) {
          return Result.failure(e); // Return the caught exception directly if it makes sense
       }
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
            '${ApiConfig.authPath}/register',
            data: json.encode({
                'username': username,
                'email': email,
                'password': password,
                'display_name': displayName,
            }),
        );

        if ((response.statusCode == 200 || response.statusCode == 201) && response.data is Map<String, dynamic>) {
             return Result.success(response.data as Map<String, dynamic>);
        } else {
             _logger.w('Sign up returned non-200 or invalid data: ${response.statusCode}', tag: 'AuthRepository');
             throw ApiException(message: 'Sign up failed: Unexpected response format', statusCode: response.statusCode);
        }

     } on DioException catch (e) {
         _logger.e('DioException during sign up', error: e, tag: 'AuthRepository');
         // Use the centralized mapping function
         return Result.failure(mapDioExceptionToApiException(e));
     } catch (e) {
         _logger.e('Unexpected error during sign up', error: e, tag: 'AuthRepository');
         if (e is Exception) {
           return Result.failure(e);
         }
        return Result.failure(RepositoryException('Sign up failed: ${e.toString()}'));
      }
  }
  
  // Accept an optional Dio instance, default to the global one
  Future<Result<Map<String, dynamic>>> refreshAuthToken(String refreshToken) async { // Removed optional dioInstance if always using dioForRefresh
      final dioClient = dioForRefresh; 
      try {
          _logger.d('Attempting token refresh', tag: 'AuthRepository');
          
          final response = await dioClient.post(
              '${ApiConfig.authPath}/refresh',
              // Send token in the request body as JSON
              data: json.encode({'refresh_token': refreshToken}), 
              // Remove header option
              // options: Options(headers: {'Authorization': 'Bearer $refreshToken'})
          );
          
          if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
              _logger.i('Token refresh successful', tag: 'AuthRepository');
              return Result.success(response.data as Map<String, dynamic>);
          } else {
               _logger.w('Token refresh returned non-200 or invalid data: ${response.statusCode}', tag: 'AuthRepository');
               throw ApiException(message: 'Token refresh failed: Unexpected response format', statusCode: response.statusCode);
          }
      } on DioException catch (e) {
          _logger.e('DioException during token refresh', error: e, tag: 'AuthRepository');
          return Result.failure(mapDioExceptionToApiException(e));
      } catch (e) {
           _logger.e('Unexpected error during token refresh', error: e, tag: 'AuthRepository');
           if (e is Exception) {
              return Result.failure(e);
           }
          return Result.failure(RepositoryException('Token refresh failed: ${e.toString()}'));
      }
  }
}
