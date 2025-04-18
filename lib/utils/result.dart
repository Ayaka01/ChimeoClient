/// A class representing the result of an operation,
/// which can be either a success with a value or a failure with an error.
class Result<T> {
  final T? _value;
  final dynamic _error;
  final bool _isSuccess;

  /// Creates a successful result with a value.
  Result.success(T value)
      : _value = value,
        _error = null,
        _isSuccess = true;

  /// Creates a failure result with an error.
  Result.failure(dynamic error)
      : _value = null,
        _error = error,
        _isSuccess = false;

  /// Returns true if the result is a success.
  bool get isSuccess => _isSuccess;

  /// Returns true if the result is a failure.
  bool get isFailure => !_isSuccess;

  /// Gets the value if the result is a success.
  /// Throws an exception if the result is a failure.
  T get value {
    if (isFailure) {
      throw Exception('Cannot get value from a failure result');
    }
    return _value as T;
  }

  /// Gets the error if the result is a failure.
  /// Throws an exception if the result is a success.
  dynamic get error {
    if (isSuccess) {
      throw Exception('Cannot get error from a success result');
    }
    return _error;
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
    R Function(dynamic) onFailure,
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
  void onFailure(void Function(dynamic) action) {
    if (isFailure) {
      action(error);
    }
  }
} 