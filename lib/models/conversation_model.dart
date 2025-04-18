// lib/models/conversation_model.dart
import 'package:simple_messenger/models/message_model.dart';

class ConversationModel {
  final String friendUsername;
  final String friendName;
  final List<MessageModel> messages;
  final DateTime? lastMessageTime;
  final String? friendAvatarUrl;
  final bool isTyping;
  final DateTime? typingTimestamp;
  final bool isOnline;

  ConversationModel({
    required this.friendUsername,
    required this.friendName,
    required this.messages,
    this.lastMessageTime,
    this.friendAvatarUrl,
    this.isTyping = false,
    this.typingTimestamp,
    this.isOnline = false,
  });

  // Get the last message in the conversation
  MessageModel? get lastMessage {
    if (messages.isEmpty) {
      return null;
    }

    // Sort messages by timestamp (newest first)
    final sortedMessages = List<MessageModel>.from(messages)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return sortedMessages.first;
  }

  // Add a new message to the conversation
  void addMessage(MessageModel message) {
    messages.add(message);
  }

  // Replace a temporary message with a server message
  void replaceMessage(String tempId, MessageModel serverMessage) {
    final index = messages.indexWhere((m) => m.id == tempId);
    if (index >= 0) {
      messages[index] = serverMessage;
    }
  }

  // Search messages in conversation
  List<MessageModel> searchMessages(String query) {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    
    return messages.where((message) => 
      message.text.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  // Factory method to create from JSON
  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> messagesJson = json['messages'] ?? [];
    
    return ConversationModel(
      friendUsername: json['friend_username'],
      friendName: json['friend_name'],
      messages: messagesJson
          .map((messageJson) => MessageModel.fromJson(messageJson))
          .toList(),
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'])
          : null,
      friendAvatarUrl: json['friend_avatar_url'],
      isTyping: json['is_typing'] ?? false,
      typingTimestamp: json['typing_timestamp'] != null 
          ? DateTime.parse(json['typing_timestamp']) 
          : null,
      isOnline: json['is_online'] ?? false,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'friend_username': friendUsername,
      'friend_name': friendName,
      'messages': messages.map((message) => message.toJson()).toList(),
      'last_message_time': lastMessage?.timestamp.toIso8601String(),
      'friend_avatar_url': friendAvatarUrl,
      'is_typing': isTyping,
      'typing_timestamp': typingTimestamp?.toIso8601String(),
      'is_online': isOnline,
    };
  }
  
  // Create a copy with updated fields
  ConversationModel copyWith({
    String? friendUsername,
    String? friendName,
    List<MessageModel>? messages,
    DateTime? lastMessageTime,
    String? friendAvatarUrl,
    bool? isTyping,
    DateTime? typingTimestamp,
    bool? isOnline,
  }) {
    return ConversationModel(
      friendUsername: friendUsername ?? this.friendUsername,
      friendName: friendName ?? this.friendName,
      messages: messages ?? this.messages,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      friendAvatarUrl: friendAvatarUrl ?? this.friendAvatarUrl,
      isTyping: isTyping ?? this.isTyping,
      typingTimestamp: typingTimestamp ?? this.typingTimestamp,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
