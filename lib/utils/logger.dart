import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

/// Logging levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// A utility class for consistent logging throughout the app
class Logger {
  /// Singleton instance
  static final Logger _instance = Logger._internal();
  
  /// Private constructor
  Logger._internal();
  
  /// Factory constructor to return the singleton instance
  factory Logger() => _instance;
  
  /// The minimum level to log, defaults to debug in debug mode, info in release mode
  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  
  /// Set the minimum log level
  set minLevel(LogLevel level) => _minLevel = level;
  
  /// Log a debug message
  void d(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  /// Log an info message
  void i(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  /// Log a warning message
  void w(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  /// Log an error message
  void e(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  /// Internal logging method
  void _log(LogLevel level, String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    // Skip logging if below minimum level
    if (level.index < _minLevel.index) return;
    
    // Format tag
    final tagString = tag != null ? '[$tag] ' : '';
    
    // Format log level
    final levelString = level.toString().split('.').last.toUpperCase();
    
    // Create log message
    final logMessage = '$tagString$levelString: $message';
    
    // Log message differently depending on mode
    if (kDebugMode) {
      // Print to console in debug mode
      // ignore: avoid_print
      print(logMessage);
      if (error != null) {
        // ignore: avoid_print
        print('ERROR: $error');
        if (stackTrace != null) {
          // ignore: avoid_print
          print('STACK TRACE: $stackTrace');
        }
      }
    } else {
      // Use developer log in release mode, which can be captured by tools
      developer.log(
        logMessage,
        name: tag ?? 'App',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
} 