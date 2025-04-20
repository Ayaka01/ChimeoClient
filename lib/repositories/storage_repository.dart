import '../models/conversation_model.dart';
import '../services/local_storage_service.dart'; // Assuming this service might throw Exceptions
import 'base_repository.dart';             // For BaseRepository (and executeSafe)
import '../utils/result.dart';             // For Result<T>
import '../utils/error_handler.dart';      // For errorHandler used by executeSafe
// import '../utils/exceptions.dart';      // For potential custom Exceptions

/// Repository for managing local storage operations related to conversations and message queues using Result type.
class StorageRepository extends BaseRepository {
  // Assuming LocalStorageService() is correctly instantiated
  final LocalStorageService _storage = LocalStorageService();

  /// Gets all conversations from storage.
  /// Returns Result.success(Map<String, ConversationModel>) or Result.failure(Exception).
  /// Returns Result.success({}) if storage is empty or null.
  Future<Result<Map<String, ConversationModel>>> getConversations() async {
    // Use executeSafe, which returns Result<T>
    return await executeSafe<Map<String, ConversationModel>>(() async {
      // Await the actual storage operation
      final conversations = await _storage.getConversations();
      // Handle null from storage by returning default value on success path
      return conversations ?? {};
      // If _storage.getConversations() throws Exception, executeSafe catches it
    });
    // Removed outer '?? {}' as executeSafe now returns Result, not Map?
  }

  /// Saves conversations to storage.
  /// Returns Result.success(null) on success, Result.failure(Exception) on failure.
  Future<Result<void>> saveConversations(Map<String, ConversationModel> conversations) async {
    // Replace executeSafeBool with executeSafe<void>
    return await executeSafe<void>(() async {
      // Await the storage operation. If it throws Exception, executeSafe catches it.
      await _storage.saveConversations(conversations);
      // No explicit return needed for void success
    });
  }

  /// Gets the offline message queue.
  /// Returns Result.success(List<Map<String, dynamic>>) or Result.failure(Exception).
  /// Returns Result.success([]) if storage is empty or null.
  Future<Result<List<Map<String, dynamic>>>> getOfflineQueue() async {
    // Use executeSafe, which returns Result<T>
    return await executeSafe<List<Map<String, dynamic>>>(() async {
      // Await the actual storage operation
      final queue = await _storage.getOfflineQueue();
      // Handle null from storage by returning default value on success path
      return queue ?? [];
      // If _storage.getOfflineQueue() throws Exception, executeSafe catches it
    });
    // Removed outer '?? []' as executeSafe now returns Result, not List?
  }

  /// Saves the offline message queue.
  /// Returns Result.success(null) on success, Result.failure(Exception) on failure.
  Future<Result<void>> saveOfflineQueue(List<Map<String, dynamic>> queue) async {
    // Replace executeSafeBool with executeSafe<void>
    return await executeSafe<void>(() async {
      // Await the storage operation. If it throws Exception, executeSafe catches it.
      await _storage.saveOfflineQueue(queue);
      // No explicit return needed for void success
    });
  }

  /// Clears the offline message queue.
  /// Returns Result.success(null) on success, Result.failure(Exception) on failure.
  Future<Result<void>> clearOfflineQueue() async {
    // Replace executeSafeBool with executeSafe<void>
    return await executeSafe<void>(() async {
      // Await the storage operation. If it throws Exception, executeSafe catches it.
      await _storage.clearOfflineQueue();
      // No explicit return needed for void success
    });
  }

  /// Gets a specific conversation by ID.
  /// Returns Result.success(ConversationModel?) containing the model or null if not found.
  /// Returns Result.failure(Exception) if fetching conversations fails.
  Future<Result<ConversationModel?>> getConversation(String conversationId) async {
    // 1. Call the refactored getConversations method
    final conversationsResult = await getConversations(); // Returns Result<Map<String, ConversationModel>>

    // 2. Handle the Result using if/else for clarity
    if (conversationsResult.isSuccess) {
      // If getConversations succeeded:
      // Get the map from the successful result's value
      final conversationsMap = conversationsResult.value; // Safe access to value

      // Find the specific conversation in the map (result is ConversationModel?)
      final conversation = conversationsMap[conversationId];

      // Wrap the outcome (the found conversation or null) in a new success Result
      return Result.success(conversation); // Result<ConversationModel?>

    } else {
      // If getConversations failed:
      // Get the error from the failure result's error property
      final error = conversationsResult.error; // Safe access to error (returns Exception)

      // Propagate the failure by wrapping the original error in a new failure Result
      return Result.failure(error); // Result<ConversationModel?>
    }
  }

  /// Saves a single conversation, overwriting if it exists.
  /// Returns Result.success(null) on success, Result.failure(Exception) on failure.
  Future<Result<void>> saveConversation(String conversationId, ConversationModel conversation) async {
    // Use executeSafe<void> to wrap the entire multi-step operation
    return await executeSafe<void>(() async {
      // 1. Get existing conversations (returns Result)
      final getResult = await getConversations();

      // Must check if getConversations succeeded before proceeding
      if (getResult.isFailure) {
        // If getting failed, throw the error *within* this lambda
        // so the outer executeSafe catches it and returns Result.failure
        throw getResult.error;
      }

      // Get the map if successful
      final conversations = getResult.value; // Safe access after check

      // 2. Modify the map
      conversations[conversationId] = conversation;

      // 3. Save the updated map (returns Result)
      final saveResult = await saveConversations(conversations);

      // Must check if saveConversations succeeded
      if (saveResult.isFailure) {
        // If saving failed, throw the error *within* this lambda
        // so the outer executeSafe catches it and returns Result.failure
        throw saveResult.error;
      }

      // 4. If both get and save succeeded, the operation is successful (void)
    });
  }
} // End of StorageRepository class