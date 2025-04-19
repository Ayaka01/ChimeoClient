import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../config/app_config.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }


  Future<void> _checkAuthStatus() async {
    await Future.delayed(Duration(seconds: 1));

    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final messageService = Provider.of<MessageService>(context, listen: false);

    if (authService.isAuthenticated) {
      if (!messageService.isConnected) {
        messageService.connectToWebSocket();
      }
      await messageService.getPendingMessages();
    }

    if(!mounted) return;
    setState(() {
      _isLoading = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                authService.isAuthenticated ? HomeScreen() : LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: AppColors.primary),
            SizedBox(height: 24),
            Text(
              AppConfig.appName,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            if (_isLoading)
              CircularProgressIndicator(color: AppColors.primary)
          ],
        ),
      ),
    );
  }
}
