import '../models/conversation_model.dart';
import '../services/local_storage_service.dart';
import 'base_repository.dart';

/// Repository for managing local storage operations related to conversations and message queues
class StorageRepository extends BaseRepository {
  final LocalStorageService _storage = LocalStorageService();
  
  /// Get all conversations from storage
  Future<Map<String, ConversationModel>> getConversations() async {
    return await executeSafe<Map<String, ConversationModel>>(() async {
      return await _storage.getConversations() ?? {};
    }) ?? {};
  }
  
  /// Save conversations to storage
  Future<bool> saveConversations(Map<String, ConversationModel> conversations) async {
    return await executeSafeBool(() async {
      await _storage.saveConversations(conversations);
    });
  }
  
  /// Get the offline message queue
  Future<List<Map<String, dynamic>>> getOfflineQueue() async {
    return await executeSafe<List<Map<String, dynamic>>>(() async {
      return await _storage.getOfflineQueue() ?? [];
    }) ?? [];
  }
  
  /// Save the offline message queue
  Future<bool> saveOfflineQueue(List<Map<String, dynamic>> queue) async {
    return await executeSafeBool(() async {
      await _storage.saveOfflineQueue(queue);
    });
  }
  
  /// Clear the offline message queue
  Future<bool> clearOfflineQueue() async {
    return await executeSafeBool(() async {
      await _storage.clearOfflineQueue();
    });
  }
  
  /// Get conversation by ID
  Future<ConversationModel?> getConversation(String conversationId) async {
    final conversations = await getConversations();
    return conversations[conversationId];
  }
  
  /// Save a single conversation
  Future<bool> saveConversation(String conversationId, ConversationModel conversation) async {
    return await executeSafeBool(() async {
      final conversations = await getConversations();
      conversations[conversationId] = conversation;
      await saveConversations(conversations);
    });
  }
} 