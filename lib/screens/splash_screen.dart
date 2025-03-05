// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_messenger/constants/colors.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

// SplashScreen es una pantalla con estado, porque se comprueba el estado de autenticación
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

// A la hora de trabajar con un widget con estado, se debe crear otra clase que extienda de State
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Give it some time to show the splash screen
    await Future.delayed(Duration(seconds: 2));

    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                authService.user != null ? HomeScreen() : LoginScreen(),
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
            Icon(Icons.done, size: 80, color: AppColors.primary),
            SizedBox(height: 24),
            Text(
              'Chimeo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
