import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../repositories/auth_repository.dart';
import 'auth_interceptor.dart';

// --- Main Dio Instance (for general API calls) ---
final Dio dio = Dio(
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
  dio.interceptors.removeWhere((interceptor) => interceptor is AuthInterceptor);
  
  dio.interceptors.add(AuthInterceptor(authService, authRepository));

}

