import 'dart:async';
import '../utils/error_handler.dart';

/// Base repository interface
/// 
/// Provides a consistent interface for all repositories to implement
abstract class BaseRepository {
  /// The error handler instance used by all repositories
  final ErrorHandler errorHandler = ErrorHandler();
  
  /// Execute a safe operation with automatic error handling
  /// 
  /// T is the return type of the operation
  /// Returns null if an error occurs
  Future<T?> executeSafe<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      // Log the error but still throw it
      errorHandler.handleError(e, stackTrace: stackTrace);
      rethrow; // Re-throw the exception so it can be handled at a higher level
    }
  }
  
  /// Execute a safe operation returning a boolean success flag
  /// 
  /// Returns true if successful, false if an error occurs
  Future<bool> executeSafeBool(Future<void> Function() operation) async {
    try {
      await operation();
      return true;
    } catch (e, stackTrace) {
      // Log the error but still throw it
      errorHandler.handleError(e, stackTrace: stackTrace);
      rethrow; // Re-throw the exception so it can be handled at a higher level
    }
  }
} 