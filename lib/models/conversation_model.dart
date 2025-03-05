// lib/models/conversation_model.dart
import 'package:simple_messenger/models/message_model.dart';

class ConversationModel {
  final String friendId;
  final String friendName;
  final List<MessageModel> messages;
  final DateTime? lastMessageTime;

  ConversationModel({
    required this.friendId,
    required this.friendName,
    required this.messages,
    this.lastMessageTime,
  });

  // Get the last message in the conversation
  MessageModel? get lastMessage {
    if (messages.isEmpty) return null;
    return messages.reduce(
      (curr, next) => curr.timestamp.isAfter(next.timestamp) ? curr : next,
    );
  }

  // Helper to add a new message to the conversation
  void addMessage(MessageModel message) {
    messages.add(message);
    messages.sort(
      (a, b) => b.timestamp.compareTo(a.timestamp),
    ); // Sort descending
  }

  // Convert to a simple JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'friend_id': friendId,
      'friend_name': friendName,
      'messages': messages.map((m) => m.toJson()).toList(),
      'last_message_time': lastMessageTime?.toIso8601String(),
    };
  }

  // Create from storage JSON
  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      friendId: json['friend_id'],
      friendName: json['friend_name'],
      messages:
          (json['messages'] as List)
              .map((m) => MessageModel.fromJson(m))
              .toList(),
      lastMessageTime:
          json['last_message_time'] != null
              ? DateTime.parse(json['last_message_time'])
              : null,
    );
  }
}
