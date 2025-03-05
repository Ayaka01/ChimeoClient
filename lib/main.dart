// lib/main.dart - App Entry Point
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/user_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthService()),
        ProxyProvider<AuthService, ChatService>(
          update: (context, auth, previous) => ChatService(auth),
          dispose: (context, service) => service.dispose(),
        ),
        ProxyProvider<AuthService, UserService>(
          update: (context, auth, previous) => UserService(auth),
        ),
      ],
      child: MaterialApp(
        title: 'Chimeo',
        theme: ThemeData(
          primarySwatch: Colors.amber,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: SplashScreen(),
      ),
    );
  }
}
