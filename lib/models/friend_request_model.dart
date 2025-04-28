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
    // Helper function for safe parsing with logging
    String _parseField(String key, String defaultValue, Map<String, dynamic> sourceJson) {
      final value = sourceJson[key];
      if (value == null) {
        return defaultValue;
      }
      return value.toString();
    }

    return FriendRequestModel(
      id: _parseField('id', 'missing_id', json),
      senderUsername: _parseField('sender_username', 'unknown_sender', json),
      recipientUsername: _parseField('recipient_username', 'unknown_recipient', json),
      status: _parseField('status', 'unknown', json),
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
