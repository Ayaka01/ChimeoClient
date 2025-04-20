/// A class representing the result of an operation,
/// which can be either a success with a value or a failure with an Exception.
class Result<T> {
  final T? _value;
  final Exception? _error;
  final bool _isSuccess;

  /// Creates a successful result with a value.
  Result.success(T value)
      : _value = value,
        _error = null,
        _isSuccess = true;

  /// Creates a failure result with an error.
  Result.failure(Exception error)
      : _value = null,
        _error = error,
        _isSuccess = false;

  bool get isSuccess => _isSuccess;

  bool get isFailure => !_isSuccess;

  /// Gets the value if the result is a success.
  /// Throws an StateError if the result is a failure.
  T get value {
    if (isFailure) {
      throw StateError('Cannot get value from a failure result');
    }
    return _value as T;
  }

  /// Gets the Exception if the result is a failure.
  /// Throws an StateError if the result is a success.
  Exception get error {
    if (isSuccess) {
      throw StateError('Cannot get error from a success result');
    }
    return _error!;
  }

  /// Maps the value of a successful result using the provided function.
  /// Returns a new Result with the mapped value.
  /// If the result is a failure, returns a new Result with the same error.
  Result<R> map<R>(R Function(T) mapper) {
    if (isSuccess) {
      return Result.success(mapper(value));
    } else {
      return Result.failure(error);
    }
  }

  /// Handles both success and failure cases with callback functions.
  R fold<R>(
    R Function(T) onSuccess,
    R Function(Exception) onFailure,
  ) {
    if (isSuccess) {
      return onSuccess(value);
    } else {
      return onFailure(error);
    }
  }
  
  /// Perform an action on the value if the result is a success.
  void onSuccess(void Function(T) action) {
    if (isSuccess) {
      action(value);
    }
  }
  
  /// Perform an action on the error if the result is a failure.
  void onFailure(void Function(Exception) action) {
    if (isFailure) {
      action(error);
    }
  }
} 