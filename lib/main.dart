import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'services/message_service.dart';
import 'services/local_storage_service.dart';
import 'screens/splash_screen.dart';
import 'constants/colors.dart';
import 'config/app_config.dart';
import 'repositories/auth_repository.dart';
import 'repositories/message_repository.dart';
import 'repositories/user_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // These repositories will be used for API requests
    final authRepository = AuthRepository();
    final messageRepository = MessageRepository();
    final userRepository = UserRepository();

    // To store messages locally
    SingleChildWidget localStorageServiceProvider = Provider(
      create: (context) => LocalStorageService(),
    );

    // To handle authentication
    SingleChildWidget authServiceProvider = ChangeNotifierProvider(
      create: (context) => AuthService(authRepository),
    );

    // To handle friendships
    SingleChildWidget userServiceProvider =
        ProxyProvider<AuthService, UserService>(
          update: (context, auth, previous) => UserService(auth, userRepository),
        );

    // To handle messages
    SingleChildWidget messageServiceProvider = ChangeNotifierProxyProvider2<
      AuthService,
      LocalStorageService,
      MessageService
    >(
      create:
          (context) => MessageService(
            context.read<AuthService>(),
            context.read<LocalStorageService>(),
            messageRepository,
          ),
      update:
          (context, auth, storage, previous) =>
              previous!..updateServices(auth, storage, messageRepository),
    );

    // These services will be available
    List<SingleChildWidget> rootProviders = [
      localStorageServiceProvider,
      authServiceProvider,
      userServiceProvider,
      messageServiceProvider,
    ];

    // General styling
    ThemeData baseTheme = ThemeData(
      visualDensity: VisualDensity.adaptivePlatformDensity,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.secondary,
        centerTitle: true,
      ),

      textTheme: TextTheme(
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.secondary,
        ),
        bodyMedium: TextStyle(fontSize: 16, color: Colors.grey),
      ),

      drawerTheme: DrawerThemeData(backgroundColor: AppColors.bg),
      scaffoldBackgroundColor: AppColors.bg,
    );

    return MultiProvider(
      providers: rootProviders,
      child: MaterialApp(
        title: AppConfig.appName,
        theme: baseTheme,
        home: SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
