class RepositoryException implements Exception {
  final String message;
  RepositoryException(this.message);

  @override
  String toString() => message;
}

class InternalServerErrorException extends RepositoryException {
  InternalServerErrorException() : super("Internal Server Error");
}

class ValidationDataError extends RepositoryException {
  ValidationDataError(super.message);
}

class RegistrationException extends RepositoryException {
  RegistrationException(super.message);
}

class LoginException extends RepositoryException {
  LoginException(super.message);
}

class InvalidCredentialsException extends LoginException {
  InvalidCredentialsException() : super("Invalid credentials provided.");
}

class UsernameTakenException extends RegistrationException {
  UsernameTakenException() : super("Username is already taken.");
}

class EmailInUseException extends RegistrationException {
  EmailInUseException() : super("Email is already in use.");
}

class InvalidEmailFormatException extends RepositoryException {
  InvalidEmailFormatException() : super("Invalid email format.");
}

class PasswordTooWeakException extends RegistrationException {
  PasswordTooWeakException()
      : super("Password does not meet strength requirements.");
}

class UsernameTooShortException extends RepositoryException {
  UsernameTooShortException() : super("Username is too short.");
}

class WebSocketException implements Exception {
  // ... existing code ...
}