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
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late AuthService _authService;
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _authService.addListener(_handleAuthStateChange);
    WidgetsBinding.instance.addPostFrameCallback((_) { 
        if(mounted) { 
             _handleAuthStateChange(); 
              _performInitialAuthenticatedTasks();
  }
    });
  }

  @override
  void dispose() {
    _authService.removeListener(_handleAuthStateChange);
    super.dispose();
  }

  void _handleAuthStateChange() {
    if (!mounted) return;

    if (!_authService.isAuthenticated) {
      _logger.i('Auth state is unauthenticated, navigating to LoginScreen.', tag: 'SplashScreen');
      _cleanupServices();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } else {
       _logger.i('Auth state is authenticated, navigating to HomeScreen.', tag: 'SplashScreen');
       Navigator.of(context).pushAndRemoveUntil(
         MaterialPageRoute(builder: (context) => HomeScreen()),
         (Route<dynamic> route) => false,
       );
    }
  }

  void _cleanupServices() {
     try {
    final messageService = context.read<MessageService>();
        messageService.disconnect();
        messageService.clearAllLocalConversations(); 
        _logger.i('MessageService disconnected and cleared.', tag: 'SplashScreen');
      } catch (e) {
        _logger.e('Error cleaning up MessageService', error: e, tag: 'SplashScreen');
      }
  }
  
  void _performInitialAuthenticatedTasks() {
      if (_authService.isAuthenticated) {
         _logger.d('User is authenticated, performing initial tasks (WebSocket connect, get pending messages).', tag: 'SplashScreen');
         try {
           final messageService = context.read<MessageService>();
      if (!messageService.isConnected) {
        messageService.connectToWebSocket();
      }
           messageService.getPendingMessages(); 
         } catch (e) {
            _logger.e('Error accessing MessageService during initial tasks', error: e, tag: 'SplashScreen');
         }
      }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image(image: AssetImage('assets/images/logo.png'), width: 150),
            SizedBox(height: 48),
            CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
