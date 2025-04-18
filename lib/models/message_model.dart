// lib/models/message_model.dart
class MessageModel {
  final String id;
  final String senderId;
  final String recipientId;
  final String text;
  final DateTime timestamp;
  bool delivered;
  bool read;
  bool isOffline;
  bool error;
  String? errorMessage;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.timestamp,
    this.delivered = false,
    this.read = false,
    this.isOffline = false,
    this.error = false,
    this.errorMessage,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      senderId: json['sender_username'],
      recipientId: json['recipient_username'],
      text: json['text'],
      timestamp: DateTime.parse(json['created_at']),
      delivered: json['delivered'] ?? false,
      read: json['read'] ?? false,
      isOffline: json['is_offline'] ?? false,
      error: json['error'] ?? false,
      errorMessage: json['error_message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_username': senderId,
      'recipient_username': recipientId,
      'text': text,
      'created_at': timestamp.toIso8601String(),
      'delivered': delivered,
      'read': read,
      'is_offline': isOffline,
      'error': error,
      'error_message': errorMessage,
    };
  }
  
  // Create a copy with updated fields
  MessageModel copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    String? text,
    DateTime? timestamp,
    bool? delivered,
    bool? read,
    bool? isOffline,
    bool? error,
    String? errorMessage,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      delivered: delivered ?? this.delivered,
      read: read ?? this.read,
      isOffline: isOffline ?? this.isOffline,
      error: error ?? this.error,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
