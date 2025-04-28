// lib/models/user_model.dart
import 'package:flutter/material.dart';

enum UserStatus {
  online,
  away,
  offline,
  busy
}

extension UserStatusExtension on UserStatus {
  String get displayName {
    switch (this) {
      case UserStatus.online: return 'Online';
      case UserStatus.away: return 'Away';
      case UserStatus.offline: return 'Offline';
      case UserStatus.busy: return 'Busy';
    }
  }
  
  Color get color {
    switch (this) {
      case UserStatus.online: return Colors.green;
      case UserStatus.away: return Colors.orange;
      case UserStatus.offline: return Colors.grey;
      case UserStatus.busy: return Colors.red;
    }
  }
}

class UserModel {
  final String username;
  final String displayName;
  
  UserModel({
    required this.username,
    required this.displayName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      username: json['username'],
      displayName: json['display_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'display_name': displayName,
    };
  }
  
  // Create a copy of this user with updated fields
  UserModel copyWith({
    String? username,
    String? displayName,
  }) {
    return UserModel(
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
    );
  }
}