// Custom exception for base repository operations
class RepositoryException implements Exception {
  final String message;
  RepositoryException(this.message);

  @override
  String toString() => message;
}

// Specific Authentication Exceptions

// Base class for registration specific errors
class RegistrationException extends RepositoryException {
  RegistrationException(super.message);
}

// Base class for login specific errors
class LoginException extends RepositoryException {
  LoginException(super.message);
}

// Thrown when credentials (email/password) are incorrect during login.
class InvalidCredentialsException extends LoginException {
  InvalidCredentialsException() : super("Invalid credentials provided.");
}

// Thrown when the provided username is already taken during registration.
class UsernameTakenException extends RegistrationException {
  UsernameTakenException() : super("Username is already taken.");
}

// Thrown when the provided email is already registered during registration.
class EmailInUseException extends RegistrationException {
  EmailInUseException() : super("Email is already in use.");
}

// Thrown when the provided email format is invalid.
class InvalidEmailFormatException extends RepositoryException { // Can happen in login or register
  InvalidEmailFormatException() : super("Invalid email format.");
}

// Thrown when the password does not meet strength requirements.
class PasswordTooWeakException extends RegistrationException {
  PasswordTooWeakException()
      : super("Password does not meet strength requirements.");
}

// Thrown when the username is too short during registration.
class UsernameTooShortException extends RegistrationException {
  UsernameTooShortException() : super("Username is too short.");
}

// General exception for WebSocket connection errors
class WebSocketException implements Exception {
  // ... existing code ...
}