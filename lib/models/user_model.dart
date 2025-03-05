// lib/models/user_model.dart
class UserModel {
  final String id;
  final String username;
  final String displayName;
  final DateTime lastSeen;

  UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.lastSeen,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      displayName: json['display_name'],
      lastSeen:
          json['last_seen'] != null
              ? DateTime.parse(json['last_seen'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'last_seen': lastSeen.toIso8601String(),
    };
  }
}
