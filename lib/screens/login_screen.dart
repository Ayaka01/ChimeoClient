import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_messenger/utils/exceptions.dart';
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
                      _buildHeader(context),
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

  Widget _buildHeader(context) {
    return Column(
      children: [
        Text(
          '¡Bienvenido a Chimeo!',
          style: Theme.of(context).textTheme.titleLarge,
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

  void _showErrorSnackBar(String message) {
    if (!mounted) return; // Check mount status
    setState(() => _isLoading = false); // Set loading state
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)), // Show snackbar
    );
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, introduce email y contraseña')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      await authService.signIn(email, password);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      // Connect to WebSocket
      final messageService = Provider.of<MessageService>(
        context,
        listen: false,
      );
      messageService.connectToWebSocket();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } on InvalidCredentialsException {
        _showErrorSnackBar('Email o contraseña incorrectos.');
    } on InvalidEmailFormatException {
        _showErrorSnackBar('Por favor, introduce un email válido.');
    } catch (e) {
        _showErrorSnackBar('Error al iniciar sesión: ${e.toString()}');
    }
  }
}
