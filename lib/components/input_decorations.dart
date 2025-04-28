import 'package:flutter/material.dart';
import '../constants/colors.dart'; // Import AppColors

/// Builds a modern InputDecoration for TextFormFields.
/// 
/// Features:
/// - No background fill.
/// - Subtle rounded outline border by default.
/// - Primary color rounded outline border when focused.
InputDecoration buildModernInputDecoration({
  required String labelText, 
  Widget? suffixIcon,
  String? errorText,
}) {
  return InputDecoration(
    labelText: labelText,
    labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
    // No fill
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    // Defines the border look when not enabled/focused (uses enabledBorder style)
    border: OutlineInputBorder(
       borderRadius: BorderRadius.circular(8.0),
       borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
    suffixIcon: suffixIcon,
    errorText: errorText,
  );
} 