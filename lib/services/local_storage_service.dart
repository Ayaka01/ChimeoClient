// lib/services/local_storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation_model.dart';

class LocalStorageService {
  // Key for storing conversations
  static const String _conversationsKey = 'app_conversations';

  // Save all conversations to local storage
  Future<void> saveConversations(
    Map<String, ConversationModel> conversations,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert to JSON
      final Map<String, dynamic> conversationsJson = {};
      conversations.forEach((key, value) {
        conversationsJson[key] = value.toJson();
      });

      // Save as string
      await prefs.setString(_conversationsKey, json.encode(conversationsJson));
    } catch (e) {
      print('Error saving conversations: $e');
      throw e;
    }
  }

  // Retrieve conversations from local storage
  Future<Map<String, ConversationModel>?> getConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? conversationsJson = prefs.getString(_conversationsKey);

      if (conversationsJson == null) {
        return {};
      }

      // Parse from JSON
      final Map<String, dynamic> decodedJson = json.decode(conversationsJson);
      final Map<String, ConversationModel> conversations = {};

      decodedJson.forEach((key, value) {
        conversations[key] = ConversationModel.fromJson(value);
      });

      return conversations;
    } catch (e) {
      print('Error retrieving conversations: $e');
      return {};
    }
  }

  // Save a single conversation
  Future<void> saveConversation(
    String friendId,
    ConversationModel conversation,
  ) async {
    try {
      // Get existing conversations
      final conversations = await getConversations() ?? {};

      // Update the specific conversation
      conversations[friendId] = conversation;

      // Save all conversations
      await saveConversations(conversations);
    } catch (e) {
      print('Error saving conversation: $e');
      throw e;
    }
  }

  // Delete a conversation
  Future<void> deleteConversation(String friendId) async {
    try {
      // Get existing conversations
      final conversations = await getConversations() ?? {};

      // Remove the specified conversation
      if (conversations.containsKey(friendId)) {
        conversations.remove(friendId);

        // Save the updated conversations
        await saveConversations(conversations);
      }
    } catch (e) {
      print('Error deleting conversation: $e');
      throw e;
    }
  }

  // Clear all stored conversations
  Future<void> clearAllConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_conversationsKey);
    } catch (e) {
      print('Error clearing conversations: $e');
      throw e;
    }
  }
}
