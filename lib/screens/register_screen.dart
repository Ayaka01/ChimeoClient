import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/custom_button.dart';
import '../components/custom_text_field.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  RegisterScreenState createState() => RegisterScreenState();
}

class RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeatPasswordController =
      TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Crear cuenta',
          style: TextStyle(
            color: AppColors.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top section
                Column(
                  children: [
                    const SizedBox(height: 40),

                    // Username (new field)
                    CustomTextField(
                      label: 'Nombre de usuario',
                      controller: _usernameController,
                      keyboardType: TextInputType.text,
                    ),

                    const SizedBox(height: 16),

                    // Display name
                    CustomTextField(
                      label: 'Nombre a mostrar',
                      controller: _displayNameController,
                    ),

                    const SizedBox(height: 16),

                    // Email field
                    CustomTextField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 16),

                    // Password field
                    CustomTextField(
                      label: 'Contraseña',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onToggleVisibility: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Repeat Password field
                    CustomTextField(
                      label: 'Repetir Contraseña',
                      controller: _repeatPasswordController,
                      obscureText: _obscurePassword,
                      onToggleVisibility: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),

                    const SizedBox(height: 32),
                  ],
                ),

                // Register button
                _isLoading
                    ? CircularProgressIndicator(color: AppColors.primary)
                    : CustomButton(text: 'Registrarse', onPressed: _register),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (_usernameController.text.isEmpty ||
        _displayNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _repeatPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, rellena todos los campos')),
      );
      return;
    }

    if (_passwordController.text != _repeatPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Las contraseñas no coinciden')));
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final displayName = _displayNameController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      await authService.signUp(username, email, password, displayName);

      // Check if still mounted after async operation
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // If we get here without an exception, registration was successful
      // Get message service after ensuring widget is still mounted
      final messageService = Provider.of<MessageService>(
        context,
        listen: false,
      );
      messageService.connectToWebSocket();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Display specific error messages based on the error
      String errorMessage = 'Error: ${e.toString()}';
      if (e.toString().contains('Username already taken')) {
        errorMessage = 'El nombre de usuario ya está en uso. Por favor, elige otro.';
      } else if (e.toString().contains('Email already registered')) {
        errorMessage = 'El correo electrónico ya está en uso.';
      } else if (e.toString().contains(
        'Password does not meet strength requirements',
      )) {
        errorMessage =
            'La contraseña no cumple con los requisitos de seguridad.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'El correo electrónico no es válido.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }
}
