// lib/models/message_model.dart
class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final String chatRoomId;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.chatRoomId,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'chat_room_id': chatRoomId,
    };
  }
}
