import 'package:dio/dio.dart'; // Import Dio
import 'dart:convert'; // Needed for potential validation error parsing

// Base class for API-related errors parsed from server responses
class ApiException implements Exception {
  final int? statusCode; // Can be null if not an HTTP error
  final String message; // Corresponds to 'detail' from server
  final String? errorCode; // Corresponds to 'error_code' from server
  final List<Map<String, dynamic>>? validationErrors; // Corresponds to 'errors' from server

  ApiException({
    this.statusCode,
    required this.message,
    this.errorCode,
    this.validationErrors,
  });

  factory ApiException.fromDioException(dynamic dioError) {
    // Default values
    int? statusCode;
    String message = 'An unexpected error occurred.';
    String? errorCode;
    List<Map<String, dynamic>>? validationErrors;

    if (dioError is DioException) { // Check if it's a DioException
      message = dioError.message ?? message; // Use Dio message as fallback
      statusCode = dioError.response?.statusCode;

      if (dioError.response?.data != null) {
        try {
          var responseData = dioError.response!.data;

          // Handle cases where response data might be a string that needs decoding
          if (responseData is String) {
              try {
                  responseData = json.decode(responseData);
              } catch (_) {
                  // If string is not JSON, use it as the message if detail wasn't found later
              }
          }


          if (responseData is Map<String, dynamic>) {
            message = responseData['detail'] as String? ?? message;
            errorCode = responseData['error_code'] as String?;

            // Parse validation errors if present
            if (responseData.containsKey('errors') && responseData['errors'] is List) {
              // Ensure the list elements are maps
              try {
                 validationErrors = List<Map<String, dynamic>>.from(
                    (responseData['errors'] as List)
                    .map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{'error': item.toString()}) // Convert non-maps
                 );
              } catch (_) {
                 // Could not parse validation errors
                  validationErrors = [{'error': 'Failed to parse validation errors'}];
              }
            }
          } else {
              // If response data isn't a map, use Dio's message or default
              message = dioError.message ?? 'Unknown error from server.';
          }
        } catch (e) {
          // Error parsing response data
          message = 'Failed to parse error response: ${e.toString()}';
        }
      } else {
         // No response data, likely a connection error, timeout etc.
         message = dioError.message ?? 'Network error or timeout'; // More specific message
         if (dioError.type == DioExceptionType.connectionTimeout ||
             dioError.type == DioExceptionType.sendTimeout ||
             dioError.type == DioExceptionType.receiveTimeout) {
             message = 'Connection timeout. Please check your internet connection.';
             errorCode = 'TIMEOUT';
         } else if (dioError.type == DioExceptionType.cancel) {
            message = 'Request cancelled.';
            errorCode = 'CANCELLED';
         } else if (dioError.type == DioExceptionType.connectionError) {
             message = 'Connection error. Please check your internet connection.';
             errorCode = 'CONNECTION_ERROR';
         }
         // other DioException types can be handled here...
      }
    } else {
        // Handle non-Dio exceptions if necessary, or rethrow
        message = dioError.toString();
    }


    return ApiException(
      statusCode: statusCode,
      message: message,
      errorCode: errorCode,
      validationErrors: validationErrors,
    );
  }


  @override
  String toString() {
    String errorDetails = 'ApiException: $message (Status: ${statusCode ?? 'N/A'}, Code: ${errorCode ?? 'N/A'})';
    if (validationErrors != null && validationErrors!.isNotEmpty) {
      errorDetails += '\\nValidation Errors: ${validationErrors.toString()}';
    }
    return errorDetails;
  }
}

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
  final List<Map<String, dynamic>>? errors; // Optionally store parsed errors
  ValidationDataError(String message, {this.errors}) : super(message);
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

// --- Specific API Error Codes Mapping ---
// Can create specific exception classes mapping to error_code from ApiException

class ApiAuthException extends ApiException {
   ApiAuthException({required super.message, super.errorCode, super.statusCode});
}

class ApiRegistrationException extends ApiException {
   ApiRegistrationException({required super.message, super.errorCode, super.statusCode});
}

class ApiValidationException extends ApiException {
   ApiValidationException({required super.message, super.errorCode, super.statusCode, super.validationErrors});
}

// Helper function to convert DioException to a specific RepositoryException/ApiException
// This centralizes the logic from the repository catch blocks
Exception mapDioExceptionToApiException(DioException dioError) {
  final apiException = ApiException.fromDioException(dioError);

  // --- Map known error codes or status codes to more specific exceptions ---
  final errorCode = apiException.errorCode;
  final statusCode = apiException.statusCode;
  final message = apiException.message;
  final validationErrors = apiException.validationErrors;

  // Authentication Errors
  if (statusCode == 401 || errorCode == "AUTHENTICATION_ERROR" || errorCode == "INVALID_CREDENTIALS") {
     return InvalidCredentialsException();
  }
  if (errorCode == "EMAIL_NOT_FOUND") {
     return LoginException(message); 
  }

  // Registration Errors 
  if (errorCode == "USERNAME_EXISTS") { // Status 409
     return UsernameTakenException();
   }
  if (errorCode == "EMAIL_EXISTS") { // Status 409
     return EmailInUseException();
   }
  if (errorCode == "WEAK_PASSWORD") { // Status 400
     return PasswordTooWeakException(); 
   }
  if (errorCode == "USERNAME_TOO_SHORT") { // Status 400
     return UsernameTooShortException(); 
   }
  if (errorCode == "REGISTRATION_ERROR" || (statusCode == 400 && validationErrors == null)) {
      return RegistrationException(message);
  }

   // User/Friendship Errors
   if (errorCode == "USER_NOT_FOUND") { // Status 404
      return UserNotFoundException(message);
   }
   if (errorCode == "FRIEND_REQUEST_NOT_FOUND") { // Status 404
      return FriendRequestNotFoundException(message);
   }
   if (errorCode == "FRIENDSHIP_ALREADY_EXISTS") { // Status 409
      return FriendshipExistsException(message);
   }
   if (errorCode == "FRIEND_REQUEST_ALREADY_EXISTS") { // Status 409
      return FriendRequestExistsException(message);
   }
   if (errorCode == "INVALID_FRIEND_REQUEST_STATE") { // Status 400
       return InvalidFriendRequestStateException(message);
   }
   if (errorCode == "CANNOT_FRIEND_SELF") { // Status 400
       return CannotFriendSelfException(message);
   }
   if (errorCode == "NOT_AUTHORIZED") { // Status 403
       return NotAuthorizedException(message);
   }

   // Message Errors
   if (errorCode == "MESSAGE_NOT_FOUND") { // Status 404
       return MessageNotFoundException(message);
   }
   
   // Database Errors (from generic service catches)
   if (errorCode == "DB_ERROR") { // Status 500
       // Could potentially map to a more specific internal error if needed
       return InternalServerErrorException(); 
   }

   // Validation Errors (Status 422 primarily, or 400 with errors list)
   if (statusCode == 422 || (statusCode == 400 && validationErrors != null && validationErrors!.isNotEmpty)) {
     String validationMessage = message; // Fallback message
     if (validationErrors != null && validationErrors!.isNotEmpty) {
        try {
            validationMessage = validationErrors!
                .map((e) => "${e['loc']?.isNotEmpty == true ? e['loc'].last : 'field'}: ${e['msg'] ?? 'invalid'}")
                .join(', ');
        } catch (_) { 
            validationMessage = "Invalid data provided.";
        } 
     }
      return ValidationDataError(validationMessage, errors: validationErrors);
   }

   // Internal Server Error (Generic 500)
   if (statusCode == 500) {
     return InternalServerErrorException(); 
   }

   // --- Fallback ---
   if (statusCode != null && statusCode! >= 400) {
      // Return the generic ApiException containing details from the server if no specific mapping matched
      return apiException; 
   }

   // Fallback for network/Dio issues (no status code or non-API error)
   return RepositoryException(apiException.message); 
}

// (Add more message errors if needed)

// --- User/Friendship Related Exceptions (mapped from APIError codes) ---

class UserNotFoundException extends RepositoryException {
  UserNotFoundException([String message = "User not found."]) : super(message);
}

class FriendRequestNotFoundException extends RepositoryException {
   FriendRequestNotFoundException([String message = "Friend request not found."]) : super(message);
}

class FriendshipExistsException extends RepositoryException {
   FriendshipExistsException([String message = "Already friends with this user."]) : super(message);
}

class FriendRequestExistsException extends RepositoryException {
   FriendRequestExistsException([String message = "Friend request already exists."]) : super(message);
}

class InvalidFriendRequestStateException extends RepositoryException {
   InvalidFriendRequestStateException([String message = "Friend request status prevents this action."]) : super(message);
}

class CannotFriendSelfException extends RepositoryException {
   CannotFriendSelfException([String message = "You cannot send a friend request to yourself."]) : super(message);
}

class NotAuthorizedException extends RepositoryException {
   NotAuthorizedException([String message = "Operation not authorized."]) : super(message);
}

// --- Message Related Exceptions ---

class MessageNotFoundException extends RepositoryException {
   MessageNotFoundException([String message = "Message not found."]) : super(message);
}