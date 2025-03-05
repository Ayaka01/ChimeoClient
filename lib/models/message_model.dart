// lib/models/message_model.dart
class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final String chatRoomId;
  bool delivered; // Added delivery status flag

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.chatRoomId,
    this.delivered = false, // Default to not delivered
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      senderId: json['sender_id'],
      text: json['text'],
      timestamp:
          json['timestamp'] != null
              ? DateTime.parse(json['timestamp'])
              : DateTime.now(),
      chatRoomId: json['chat_room_id'],
      delivered: json['delivered'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'chat_room_id': chatRoomId,
      'delivered': delivered,
    };
  }
}
