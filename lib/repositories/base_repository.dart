import 'dart:async';
import 'package:simple_messenger/utils/result.dart';
import 'package:simple_messenger/utils/error_handler.dart';

// Provides a consistent interface for all repositories to implement
abstract class BaseRepository {
  final ErrorHandler errorHandler = ErrorHandler();

  Future<Result<T>> executeSafe<T>(Future<T> Function() operation) async {
    try {
      final value = await operation();
      return Result.success(value);

    } on Exception catch (e, stackTrace) {
      errorHandler.handleError(e, stackTrace: stackTrace);
      return Result.failure(e);
    }
  }
}