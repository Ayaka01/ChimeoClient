// lib/models/friend_request_model.dart
import 'package:simple_messenger/models/user_model.dart';

class FriendRequestModel {
  final String id;
  final UserModel sender;
  final UserModel recipient;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  FriendRequestModel({
    required this.id,
    required this.sender,
    required this.recipient,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'],
      sender: UserModel.fromJson(json['sender']),
      recipient: UserModel.fromJson(json['recipient']),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender.toJson(),
      'recipient': recipient.toJson(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
