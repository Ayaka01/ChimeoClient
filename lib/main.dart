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
import 'utils/dio_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Initialize dependencies needed for Dio Interceptor --- 
  // Create repositories (they use the global dio instance internally now)
  final authRepository = AuthRepository();
  final messageRepository = MessageRepository(); // Keep these for providers
  final userRepository = UserRepository(); // Keep these for providers

  // Create AuthService (needs AuthRepository)
  final authService = AuthService(authRepository); 
  // Important: Load auth data early if needed by interceptor immediately
  // await authService._loadAuthData(); // Consider if needed before first API call

  // --- Setup Dio Interceptors ---
  setupDioInterceptors(authService, authRepository);
  // --- End Setup --- 

  runApp(MyApp( // Pass instances needed by MyApp build method
    authRepository: authRepository,
    messageRepository: messageRepository,
    userRepository: userRepository,
    authService: authService, 
  ));
}

class MyApp extends StatelessWidget {
  // Receive the instances needed for providers
  final AuthRepository authRepository;
  final MessageRepository messageRepository;
  final UserRepository userRepository;
  final AuthService authService;

  const MyApp({
    super.key,
    required this.authRepository,
    required this.messageRepository,
    required this.userRepository,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    // Use the pre-created instances for the providers
    // final authRepository = AuthRepository(); // Remove recreation
    // final messageRepository = MessageRepository(); // Remove recreation
    // final userRepository = UserRepository(); // Remove recreation

    SingleChildWidget localStorageServiceProvider = Provider(
      create: (context) => LocalStorageService(),
    );

    // Use the pre-created authService instance
    SingleChildWidget authServiceProvider = ChangeNotifierProvider.value(
      value: authService,
    );

    SingleChildWidget userServiceProvider =
        ProxyProvider<AuthService, UserService>(
          update: (context, auth, previous) => UserService(auth, userRepository),
        );

    SingleChildWidget messageServiceProvider = ChangeNotifierProxyProvider2<
      AuthService,
      LocalStorageService,
      MessageService
    >(
      // Note: MessageService might also need the configured Dio instance or its repo
      create:
          (context) => MessageService(
            authService, // Use pre-created instance
            context.read<LocalStorageService>(),
            messageRepository,
          ),
      update:
          (context, auth, storage, previous) =>
              previous!..updateServices(auth, storage, messageRepository),
    );

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
