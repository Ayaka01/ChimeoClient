import 'package:flutter/material.dart';

/// A reusable widget to display an error message centered on the screen
/// with an icon and a retry button.
class ErrorDisplay extends StatelessWidget {
  /// The error message to display.
  final String errorMessage;

  /// The callback function to execute when the retry button is pressed.
  final VoidCallback onRetry;

  /// Creates an ErrorDisplay widget.
  const ErrorDisplay({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade400, fontSize: 15),
            ),
            const SizedBox(height: 16),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reintentar',
              onPressed: onRetry,
              color: Colors.grey[700],
            ),
          ],
        ),
      ),
    );
  }
} 