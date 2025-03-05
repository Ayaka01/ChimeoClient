// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'services/message_service.dart';
import 'services/local_storage_service.dart';
import 'screens/splash_screen.dart';
import 'constants/colors.dart';

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
        // Local storage service is a singleton
        Provider(create: (context) => LocalStorageService()),

        // Auth service
        ChangeNotifierProvider(create: (context) => AuthService()),

        // User service depends on auth service
        ProxyProvider<AuthService, UserService>(
          update: (context, auth, previous) => UserService(auth),
        ),

        // Message service depends on auth service and local storage
        // Using ChangeNotifierProxyProvider2 instead of ProxyProvider2
        ChangeNotifierProxyProvider2<
          AuthService,
          LocalStorageService,
          MessageService
        >(
          create:
              (context) => MessageService(
                Provider.of<AuthService>(context, listen: false),
                Provider.of<LocalStorageService>(context, listen: false),
              ),
          update:
              (context, auth, storage, previous) =>
                  previous!..updateServices(auth, storage),
        ),
      ],
      child: MaterialApp(
        title: 'Chimeo',
        theme: ThemeData(
          primarySwatch: Colors.amber,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.secondary,
            elevation: 1,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.secondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        home: SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
