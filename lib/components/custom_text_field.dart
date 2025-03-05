import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final TextInputType? keyboardType;

  const CustomTextField({
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.onToggleVisibility,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 2),
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  TextField(
                    controller: controller,
                    obscureText: obscureText,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                    keyboardType: keyboardType,
                  ),
                ],
              ),
            ),
            if (onToggleVisibility != null)
              SizedBox(
                height: 40,
                width: 40,
                child: IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: onToggleVisibility,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
