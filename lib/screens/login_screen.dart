import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import '../components/custom_text_field.dart';
import '../components/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 60),
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildEmailField(),
                      const SizedBox(height: 16),
                      _buildPasswordField(),
                      const SizedBox(height: 32),
                      _buildLoginButton(),
                      const SizedBox(height: 64),
                      _buildRegistrationPrompt(context),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Text(
          '¡Bienvenido a Chimeo!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1E1E),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Plataforma de Mensajería Segura',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return CustomTextField(
      label: 'Email',
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
    );
  }

  Widget _buildPasswordField() {
    return CustomTextField(
      label: 'Contraseña',
      controller: _passwordController,
      obscureText: _obscurePassword,
      onToggleVisibility: () {
        setState(() {
          _obscurePassword = !_obscurePassword;
        });
      },
    );
  }

  Widget _buildLoginButton() {
    return CustomButton(
      text: 'Iniciar Sesión',
      onPressed: _login,
      isLoading: _isLoading,
    );
  }

  Widget _buildRegistrationPrompt(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '¿Aún no tienes cuenta?',
            style: TextStyle(color: AppColors.secondary, fontSize: 13),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegisterScreen()),
              );
            },
            child: const Text(
              ' Regístrate',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, rellena todos los campos.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });


    final authService = Provider.of<AuthService>(context, listen: false);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      // Handle login
      await authService.signIn(email, password);
      _setLoading(false);

      // Handle connection with web sockets
      if(!mounted) return;
      final messageService = Provider.of<MessageService>(
        context,
        listen: false,
      );

      messageService.connectToWebSocket();

      // Handle navigation to Home Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );

    } catch (e) {
      _setLoading(false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _setLoading(bool val) {
    if (!mounted) return;

    setState(() {
      _isLoading = val;
    });
  }
}
