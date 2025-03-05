// lib/models/message_model.dart
class MessageModel {
  final String id;
  final String senderId;
  final String recipientId;
  final String text;
  final DateTime timestamp;
  bool delivered;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.timestamp,
    this.delivered = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      senderId: json['sender_id'],
      recipientId: json['recipient_id'],
      text: json['text'],
      timestamp:
          json['timestamp'] != null
              ? DateTime.parse(json['timestamp'])
              : DateTime.now(),
      delivered: json['delivered'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'delivered': delivered,
    };
  }
}
