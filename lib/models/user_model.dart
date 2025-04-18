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
  final DateTime lastSeen;
  final String? avatarUrl;
  final String? statusMessage;
  final UserStatus status;
  
  UserModel({
    required this.username,
    required this.displayName,
    required this.lastSeen,
    this.avatarUrl,
    this.statusMessage,
    this.status = UserStatus.offline,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      username: json['username'],
      displayName: json['display_name'],
      lastSeen:
          json['last_seen'] != null
              ? DateTime.parse(json['last_seen'])
              : DateTime.now(),
      avatarUrl: json['avatar_url'],
      statusMessage: json['status_message'],
      status: json['status'] != null 
        ? UserStatus.values[json['status']] 
        : UserStatus.offline,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'display_name': displayName,
      'last_seen': lastSeen.toIso8601String(),
      'avatar_url': avatarUrl,
      'status_message': statusMessage,
      'status': status.index,
    };
  }
  
  // Create a copy of this user with updated fields
  UserModel copyWith({
    String? username,
    String? displayName,
    DateTime? lastSeen,
    String? avatarUrl,
    String? statusMessage,
    UserStatus? status,
  }) {
    return UserModel(
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      lastSeen: lastSeen ?? this.lastSeen,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      statusMessage: statusMessage ?? this.statusMessage,
      status: status ?? this.status,
    );
  }
}