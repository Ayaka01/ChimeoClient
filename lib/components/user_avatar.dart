import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../constants/colors.dart';

class UserAvatar extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final double size;
  final UserStatus? status;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.size = 40.0,
    this.status,
    this.backgroundColor = AppColors.primary,
    this.textColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main avatar
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
              image: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? Center(
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: size * 0.4,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
} 