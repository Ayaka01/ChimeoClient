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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SingleChildWidget localStorageServiceProvider = Provider(create: (context) => LocalStorageService());
    SingleChildWidget authServiceProvider =  ChangeNotifierProvider(create: (context) => AuthService());

    SingleChildWidget userServiceProvider = ProxyProvider<AuthService, UserService>(
      update: (context, auth, previous) => UserService(auth),
    );

    SingleChildWidget messageServiceProvider = ChangeNotifierProxyProvider2<
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

    );


    List<SingleChildWidget> rootProviders = [
      localStorageServiceProvider,
      authServiceProvider,
      userServiceProvider,
      messageServiceProvider
    ];

    ThemeData baseTheme = ThemeData(
      visualDensity: VisualDensity.adaptivePlatformDensity,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.secondary,
        centerTitle: true,
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.secondary),
        bodyMedium: TextStyle(fontSize: 16, color: Colors.grey),

      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: AppColors.bg
      ),
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
