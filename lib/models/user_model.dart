// lib/models/user_model.dart
class UserModel {
  final String id;
  final String displayName;
  final String email;
  final DateTime lastSeen;

  UserModel({
    required this.id,
    required this.displayName,
    required this.email,
    required this.lastSeen,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      displayName: json['display_name'],
      email: json['email'],
      lastSeen:
          json['last_seen'] != null
              ? DateTime.parse(json['last_seen'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
      'last_seen': lastSeen.toIso8601String(),
    };
  }
}
