// lib/services/local_storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';

class LocalStorageService {
  // Key prefix for message storage
  static const String _messagePrefix = 'messages_';
  // Key for chat rooms
  static const String _chatRoomsKey = 'chat_rooms';

  // Save a message to local storage
  Future<void> saveMessage(MessageModel message) async {
    final prefs = await SharedPreferences.getInstance();
    final chatRoomKey = '$_messagePrefix${message.chatRoomId}';

    // Get existing messages for this chat room
    List<String> messages = prefs.getStringList(chatRoomKey) ?? [];

    // Add the new message
    messages.add(json.encode(message.toJson()));

    // Save back to shared preferences
    await prefs.setStringList(chatRoomKey, messages);

    // Make sure this chat room is in our list of chat rooms
    await _addChatRoomToList(message.chatRoomId);
  }

  // Get all messages for a chat room
  Future<List<MessageModel>> getMessages(String chatRoomId) async {
    final prefs = await SharedPreferences.getInstance();
    final chatRoomKey = '$_messagePrefix$chatRoomId';

    // Get messages as strings
    List<String> messageStrings = prefs.getStringList(chatRoomKey) ?? [];

    // Convert to message objects
    List<MessageModel> messages =
        messageStrings.map((msgStr) {
          return MessageModel.fromJson(json.decode(msgStr));
        }).toList();

    // Sort by timestamp, newest first
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return messages;
  }

  // Update a message (e.g., to mark as delivered)
  Future<void> updateMessage(MessageModel message) async {
    final prefs = await SharedPreferences.getInstance();
    final chatRoomKey = '$_messagePrefix${message.chatRoomId}';

    // Get existing messages
    List<String> messageStrings = prefs.getStringList(chatRoomKey) ?? [];
    List<dynamic> messageJsons =
        messageStrings.map((str) => json.decode(str)).toList();

    // Find and update the message
    int index = messageJsons.indexWhere((msg) => msg['id'] == message.id);
    if (index >= 0) {
      messageJsons[index] = message.toJson();

      // Save back to shared preferences
      await prefs.setStringList(
        chatRoomKey,
        messageJsons.map((msg) => json.encode(msg)).toList(),
      );
    }
  }

  // Get list of all chat room IDs
  Future<List<String>> getAllChatRooms() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_chatRoomsKey) ?? [];
  }

  // Add a chat room to the list
  Future<void> _addChatRoomToList(String chatRoomId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> chatRooms = prefs.getStringList(_chatRoomsKey) ?? [];

    if (!chatRooms.contains(chatRoomId)) {
      chatRooms.add(chatRoomId);
      await prefs.setStringList(_chatRoomsKey, chatRooms);
    }
  }

  // Clear all messages for a chat room
  Future<void> clearMessages(String chatRoomId) async {
    final prefs = await SharedPreferences.getInstance();
    final chatRoomKey = '$_messagePrefix$chatRoomId';
    await prefs.remove(chatRoomKey);
  }

  // Clear all stored data
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> chatRooms = prefs.getStringList(_chatRoomsKey) ?? [];

    // Remove all chat room messages
    for (String chatRoomId in chatRooms) {
      await prefs.remove('$_messagePrefix$chatRoomId');
    }

    // Remove chat rooms list
    await prefs.remove(_chatRoomsKey);
  }
}
