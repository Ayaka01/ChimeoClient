// lib/models/chat_room_model.dart
import 'package:simple_messenger/models/user_model.dart';

class ChatRoomModel {
  final String id;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final List<UserModel> participants;

  ChatRoomModel({
    required this.id,
    this.lastMessage,
    this.lastMessageTime,
    required this.participants,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    return ChatRoomModel(
      id: json['id'],
      lastMessage: json['last_message'],
      lastMessageTime:
          json['last_message_time'] != null
              ? DateTime.parse(json['last_message_time'])
              : null,
      participants:
          json['participants'] != null
              ? List<UserModel>.from(
                json['participants'].map((x) => UserModel.fromJson(x)),
              )
              : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'participants': participants.map((x) => x.toJson()).toList(),
    };
  }
}
