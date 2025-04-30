import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../repositories/auth_repository.dart';
import '../config/api_config.dart';
import '../utils/logger.dart';
import 'dio_client.dart';

class AuthInterceptor extends QueuedInterceptorsWrapper {
  final AuthService authService;
  final AuthRepository authRepository;
  final Logger _logger = Logger();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isRefreshing = false;

  AuthInterceptor(this.authService, this.authRepository);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Don't add token to auth routes or refresh route
    if (options.path.startsWith(ApiConfig.authPath)) {
      _logger.d('Auth path request [${options.path}], skipping token injection.', tag: 'AuthInterceptor');
      return handler.next(options);
    }

    final token = await _secureStorage.read(key: 'auth_token');

    if (token != null) {
      _logger.d('Injecting token into request header.', tag: 'AuthInterceptor');
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      _logger.w('No token found for ${options.path}, proceeding without Authorization header.', tag: 'AuthInterceptor');
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    _logger.d(
      'onError: ${err.requestOptions.path}, Status: ${err.response?.statusCode}',
      tag: 'AuthInterceptor',
    );

    // Check if it's a 401 error and not an auth path
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.startsWith(ApiConfig.authPath)) {

      // --- Start Refresh Lock ---
      if (_isRefreshing) {
        _logger.d('Refresh already in progress for ${err.requestOptions.path}, rejecting temporarily.', tag: 'AuthInterceptor');
        // Reject subsequent 401s while refresh is happening to avoid queueing complexity
        return handler.reject(DioException(
            requestOptions: err.requestOptions,
            error: 'Token refresh already in progress',
            response: err.response));
      }
      _isRefreshing = true;
      // --- End Refresh Lock ---

      _logger.i('Caught 401 on ${err.requestOptions.path}. Attempting token refresh.', tag: 'AuthInterceptor');

      try {
        final refreshToken = await _secureStorage.read(key: 'refresh_token');
        if (refreshToken == null) {
          _logger.w('No refresh token found. Triggering logout.', tag: 'AuthInterceptor');
          await _handleRefreshFailure(err, handler); // Handle failure (logs out and rejects)
          return;
        }

        // Make the refresh API call using the AuthRepository, 
        // but pass the dedicated Dio instance for this specific call.
        final refreshResult = await authRepository.refreshAuthToken(refreshToken);

        if (refreshResult.isSuccess) {
          _logger.i('Token refresh successful. Retrying original request.', tag: 'AuthInterceptor');
          final newTokens = refreshResult.value;
          // Update stored tokens via AuthService
          await authService.handleSuccessfulRefresh(newTokens);

          // Prepare options for the retry request
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer ${newTokens['access_token']}';

          // Retry the original request using the dedicated Dio instance
          _logger.d('Retrying request for ${options.path} with new token.', tag: 'AuthInterceptor');
          final response = await dioForRefresh.fetch(options);
          _logger.d('Successfully retried original request for ${options.path}', tag: 'AuthInterceptor');
          
          // Release lock *before* resolving
          _isRefreshing = false; 
          return handler.resolve(response); // Resolve with the retried response
        
        } else {
          // Refresh token failed (e.g., expired, invalid)
          _logger.w('Token refresh failed. Triggering logout.', error: refreshResult.error, tag: 'AuthInterceptor');
          await _handleRefreshFailure(err, handler); // Handle failure (logs out and rejects)
          return; // Exit after handling
        }
      } catch (e) {
        // Catch any other exception during the refresh process
        _logger.e('Exception during token refresh process', error: e, tag: 'AuthInterceptor');
        await _handleRefreshFailure(err, handler); // Handle failure (logs out and rejects)
        return; // Exit after handling
      } finally {
        // Ensure the lock is always released, even on unexpected errors within the try block
        _isRefreshing = false;
      }

    } else {
      // Not a 401 error, or it's an auth path error, pass it on
      return handler.next(err);
    }
  }

  // Helper to handle logout and reject original error
  Future<void> _handleRefreshFailure(DioException originalError, ErrorInterceptorHandler handler) async {
      _logger.w('Triggering logout due to refresh failure.', tag: 'AuthInterceptor');
      // Call the context-free signOut method
      await authService.signOut(); 
      _isRefreshing = false; // Ensure lock is released
      // Reject the original error that triggered the refresh attempt
      handler.reject(originalError);
  }
}
