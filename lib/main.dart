// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/user_service.dart';
import 'services/local_storage_service.dart';
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
        // Auth service
        ChangeNotifierProvider(create: (context) => AuthService()),

        // Chat service depends on auth service
        ProxyProvider<AuthService, ChatService>(
          update: (context, auth, previous) => ChatService(auth),
          dispose: (context, service) => service.dispose(),
        ),

        // User service depends on auth service
        ProxyProvider<AuthService, UserService>(
          update: (context, auth, previous) => UserService(auth),
        ),

        // Local storage service is a singleton
        Provider(create: (context) => LocalStorageService()),
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
