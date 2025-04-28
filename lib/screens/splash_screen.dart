import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';


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
    final authService = context.read<AuthService>();
    final messageService = context.read<MessageService>();

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
            Image.asset(
              'assets/images/logo.png',
              width: 150,
            ),
            SizedBox(height: 48),
            if (_isLoading)
              CircularProgressIndicator(color: AppColors.primary)
          ],
        ),
      ),
    );
  }
}
