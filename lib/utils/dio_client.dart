import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../repositories/auth_repository.dart';
import 'auth_interceptor.dart';

final baseOptions = BaseOptions(
  baseUrl: ApiConfig.baseUrl,
  connectTimeout: const Duration(seconds: 5),
  receiveTimeout: const Duration(seconds: 10),
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
);

// Main Dio Instance (for general API calls)
final Dio dio = Dio(baseOptions);

// Secondary Dio Instance (for token refresh and retrying failed requests)
final Dio dioForRefresh = Dio(baseOptions);

// Add interceptors ONLY to the main Dio instance
void setupDioInterceptors(AuthService authService, AuthRepository authRepository) {
  dio.interceptors.removeWhere((interceptor) => interceptor is AuthInterceptor);
  dio.interceptors.add(AuthInterceptor(authService, authRepository));
}

