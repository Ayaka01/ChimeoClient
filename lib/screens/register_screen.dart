// lib/screens/register_screen.dart
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

                      // Register button
                      _isLoading
                          ? CircularProgressIndicator(color: AppColors.primary)
                          : CustomButton(
                            text: 'Registrarse',
                            onPressed: _register,
                          ),
                      const SizedBox(height: 24),
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

  Future<void> _register() async {
    // Check if any field is empty
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
    // Validate username length
    if (_usernameController.text.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El nombre de usuario debe tener al menos 3 caracteres',
          ),
        ),
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La contraseña debe tener al menos 6 caracteres'),
        ),
      );
      return;
    }

    // Check if passwords match
    if (_passwordController.text != _repeatPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Las contraseñas no coinciden')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      bool success = await authService.signUp(
        _usernameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _displayNameController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      if (success) {
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
      }
    } catch (e) {
      print("ERROR MESSAGE");
      print(e.toString());
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Display specific error messages based on the error
        String errorMessage = e.toString();
        if (e.toString().contains('Username already taken')) {
          errorMessage = 'El nombre de usuario ya está en uso.';
        } else if (e.toString().contains('Email already registered')) {
          errorMessage = 'El correo electrónico ya está en uso.';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = 'El correo electrónico no es válido.';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    }
  }
}
