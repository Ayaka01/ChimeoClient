import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_messenger/components/custom_button.dart';
import 'package:simple_messenger/components/custom_text_field.dart';
import 'package:simple_messenger/constants/colors.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeatPasswordController =
      TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

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
                      // Nombre de usuario
                      CustomTextField(
                        label: 'Nombre de usuario',
                        controller: _nameController,
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
                          ? CircularProgressIndicator()
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
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _repeatPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, rellena todos los campos')),
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
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );

      setState(() {
        _isLoading = false;
      });

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Display specific error messages based on the error
      String errorMessage = 'El registro falló. Por favor, inténtalo de nuevo.';
      if (e.toString().contains(
        'Password must be at least 6 characters long',
      )) {
        errorMessage = 'La contraseña debe tener al menos 6 caracteres.';
      } else if (e.toString().contains('email-already-in-use')) {
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
