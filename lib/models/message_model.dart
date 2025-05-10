// lib/models/message_model.dart
class MessageModel {
  final String id;
  final String senderId;
  final String recipientId;
  final String text;
  DateTime? timestamp;
  bool delivered;
  bool isOffline;
  bool error;
  String? errorMessage;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.text,
    this.timestamp,
    this.delivered = false,
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
      timestamp: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      delivered: json['is_delivered'] ?? false,
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
      'created_at': timestamp?.toIso8601String(),
      'delivered': delivered,
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
      isOffline: isOffline ?? this.isOffline,
      error: error ?? this.error,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
