class Result<T> {
  final T? _value;
  final Exception? _error;
  final bool _isSuccess;

  Result.success(T value)
      : _value = value,
        _error = null,
        _isSuccess = true;

  Result.failure(Exception error)
      : _value = null,
        _error = error,
        _isSuccess = false;

  bool get isSuccess => _isSuccess;

  bool get isFailure => !_isSuccess;

  T get value {
    if (isFailure) {
      throw StateError('Cannot get value from a failure result');
    }
    return _value as T;
  }

  Exception get error {
    if (isSuccess) {
      throw StateError('Cannot get error from a success result');
    }
    return _error!;
  }

  Result<R> map<R>(R Function(T) mapper) {
    if (isSuccess) {
      return Result.success(mapper(value));
    } else {
      return Result.failure(error);
    }
  }

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
  
  void onSuccess(void Function(T) action) {
    if (isSuccess) {
      action(value);
    }
  }
  
  void onFailure(void Function(Exception) action) {
    if (isFailure) {
      action(error);
    }
  }
} 