// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../utils/logger.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Give it some time to show the splash screen
      await Future.delayed(Duration(seconds: 2));

      if (!mounted) return;

      final authService = Provider.of<AuthService>(context, listen: false);
      final messageService = Provider.of<MessageService>(context, listen: false);

      // If authenticated, ensure connection to WebSocket before navigating
      if (authService.isAuthenticated) {
        try {
          // Connect to WebSocket if not already connected
          if (!messageService.isConnected) {
            messageService.connectToWebSocket();
          }

          // Set a timeout for the WebSocket connection
          await Future.delayed(Duration(seconds: 5));

          // Load any pending messages
          await messageService.getPendingMessages();
        } catch (e) {
          // Use Logger directly without an instance variable
          Logger().e('Error connecting to WebSocket or fetching messages', error: e, tag: 'SplashScreen');
          // Continue to the home screen even if WebSocket fails
          // The app should handle reconnection later
        }
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => authService.isAuthenticated ? HomeScreen() : LoginScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = "Error initializing app: $e";
      });

      // After a delay, go to login screen anyway
      await Future.delayed(Duration(seconds: 3));
      
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: AppColors.primary),
            SizedBox(height: 24),
            Text(
              'Chimeo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            if (_isLoading)
              CircularProgressIndicator(color: AppColors.primary)
            else if (_errorMessage != null)
              Column(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 40),
                  SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
