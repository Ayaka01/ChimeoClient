import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'logger.dart';

/// Error type enum for categorizing errors
enum ErrorType {
  network,
  authentication,
  server,
  validation,
  storage,
  unknown
}

/// Centralized error handler for consistent error handling throughout the app
class ErrorHandler {
  /// Singleton instance
  static final ErrorHandler _instance = ErrorHandler._internal();
  
  /// Global error logger handler that can be set for analytics platforms
  Function(String message, ErrorType type, dynamic error, StackTrace? stackTrace)? 
    logHandler;
  
  /// Logger instance
  final Logger _logger = Logger();
  
  /// Factory constructor to return the singleton instance
  factory ErrorHandler() => _instance;
  
  /// Private constructor
  ErrorHandler._internal();
  
  /// Handle errors and return a user-friendly message
  String handleError(dynamic error, {StackTrace? stackTrace}) {
    ErrorType type = _determineErrorType(error);
    String message = _getUserFriendlyMessage(error, type);
    
    // Log the error if a log handler is set
    if (logHandler != null) {
      logHandler!(message, type, error, stackTrace);
    }
    
    return message;
  }
  
  /// Show an error snackbar with the error message
  void showErrorSnackBar(BuildContext context, dynamic error) {
    final message = handleError(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  /// Run a function with error handling and return a result or null if error occurs
  Future<T?> runWithErrorHandling<T>(
    Future<T> Function() function, {
    Function(String errorMessage)? onError,
  }) async {
    try {
      return await function();
    } catch (e, stackTrace) {
      final message = handleError(e, stackTrace: stackTrace);
      if (onError != null) {
        onError(message);
      }
      return null;
    }
  }
  
  /// Determine the type of error
  ErrorType _determineErrorType(dynamic error) {
    if (error is SocketException || error is TimeoutException) {
      return ErrorType.network;
    } else if (error is HttpException && (error.message.contains('401') || error.message.contains('403'))) {
      return ErrorType.authentication;
    } else if (error is HttpException) {
      return ErrorType.server;
    } else if (error is FormatException) {
      return ErrorType.validation;
    } else {
      return ErrorType.unknown;
    }
  }
  
  /// Get a user-friendly error message based on the error type
  String _getUserFriendlyMessage(dynamic error, ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'No se pudo conectar con el servidor. Comprueba tu conexión a internet.';
      case ErrorType.authentication:
        return 'Error de autenticación. Por favor, inicia sesión de nuevo.';
      case ErrorType.server:
        return 'Error en el servidor. Inténtalo de nuevo más tarde.';
      case ErrorType.validation:
        return 'Los datos proporcionados no son válidos.';
      case ErrorType.storage:
        return 'Error al guardar datos locales.';
      case ErrorType.unknown:
        return 'Ha ocurrido un error inesperado: ${error.toString()}';
    }
  }

  /// Log error to the internal logger
  void logError(dynamic error, {StackTrace? stackTrace, String? context}) {
    // Log the error
    _logError(error, stackTrace, context);
  }
  
  /// Format and log error information
  void _logError(dynamic error, StackTrace? stackTrace, String? context) {
    final errorString = error.toString();
    final contextInfo = context != null ? ' in $context' : '';
    final trace = stackTrace ?? StackTrace.current;
    
    final logMessage = 'ERROR$contextInfo: $errorString';
    
    _logger.e(logMessage, error: error, stackTrace: trace, tag: 'ErrorHandler');
  }
  
  /// Convert an HTTP status code to a user-friendly message
  String getMessageForStatusCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Authentication failed. Please log in again.';
      case 403:
        return 'You don\'t have permission to access this resource.';
      case 404:
        return 'The requested resource was not found.';
      case 408:
        return 'Request timed out. Please try again.';
      case 409:
        return 'Conflict with the current state of the resource.';
      case 422:
        return 'The server could not process your request.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      case 502:
      case 503:
      case 504:
        return 'Service temporarily unavailable. Please try again later.';
      default:
        if (statusCode >= 400 && statusCode < 500) {
          return 'Request error. Please try again.';
        } else if (statusCode >= 500) {
          return 'Server error. Please try again later.';
        }
        return 'An unexpected error occurred. Please try again.';
    }
  }
  
  /// Determine if error is a connectivity issue
  bool isConnectivityError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socket') || 
           errorString.contains('connection') ||
           errorString.contains('network') ||
           errorString.contains('timeout');
  }
  
  /// Get user-friendly error message from any type of error
  String getUserFriendlyMessage(dynamic error) {
    if (error is SocketException) {
      return 'Connection error. Please check your internet connection.';
    } else if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    } else if (isConnectivityError(error)) {
      return 'Network error. Please check your connection and try again.';
    }
    
    return 'An error occurred. Please try again.';
  }
} 