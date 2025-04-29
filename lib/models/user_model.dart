class UserModel {
  final String username;
  final String displayName;

  // Constructor
  UserModel({
    required this.username,
    required this.displayName,
  });

  // Named constructor
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
}