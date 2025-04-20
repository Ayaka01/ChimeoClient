import 'dart:async';
import '../utils/error_handler.dart';

// Provides a consistent interface for all repositories to implement
abstract class BaseRepository {
  final ErrorHandler errorHandler = ErrorHandler();
  
  /// Execute a safe operation with automatic error handling
  Future<T?> executeSafe<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      errorHandler.handleError(e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Execute a safe operation returning a boolean success flag
  Future<void> executeSafeVoid(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (e, stackTrace) {
      errorHandler.handleError(e, stackTrace: stackTrace);
      rethrow;
    }
  }
} 