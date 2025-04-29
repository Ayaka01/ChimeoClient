import 'package:dio/dio.dart';
import '../config/api_config.dart'; // Assuming ApiConfig holds the base URL
import '../services/auth_service.dart'; // Import AuthService
import '../repositories/auth_repository.dart'; // Import AuthRepository
import 'auth_interceptor.dart'; // Import the interceptor

// --- Main Dio Instance (for general API calls) ---
final Dio dio = Dio(
  BaseOptions(
    baseUrl: ApiConfig.baseUrl, // Set the base URL for all requests
    connectTimeout: const Duration(seconds: 5), // Example: 5 seconds
    receiveTimeout: const Duration(seconds: 10), // Example: 10 seconds
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ),
);

// --- Secondary Dio Instance (for token refresh & retries within interceptor) ---
// IMPORTANT: This instance does NOT have the AuthInterceptor
final Dio dioForRefresh = Dio(
   BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 5), 
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ),
);

// Function to add interceptors ONLY to the main Dio instance
void setupDioInterceptors(AuthService authService, AuthRepository authRepository) {
  // Remove existing interceptors of the same type to avoid duplicates if called multiple times
  dio.interceptors.removeWhere((interceptor) => interceptor is AuthInterceptor);
  
  // Add the AuthInterceptor with its dependencies
  dio.interceptors.add(AuthInterceptor(authService, authRepository));
  
  // Optionally add other interceptors like logging
  // dio.interceptors.add(LogInterceptor(responseBody: true)); 
}

// Later, we will add interceptors here, like:
// dio.interceptors.add(AuthInterceptor()); 