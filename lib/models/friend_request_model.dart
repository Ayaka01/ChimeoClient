// lib/models/friend_request_model.dart

class FriendRequestModel {
  final String id;
  final String senderUsername;
  final String recipientUsername;
  final String status;

  FriendRequestModel({
    required this.id,
    required this.senderUsername,
    required this.recipientUsername,
    required this.status,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'] as String,
      senderUsername: json['sender_username'] as String,
      recipientUsername: json['recipient_username'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_username': senderUsername,
      'recipient_username': recipientUsername,
      'status': status,
    };
  }
}
