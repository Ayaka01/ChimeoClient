import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_messenger/utils/exceptions.dart';
import '../components/custom_button.dart';
import '../components/custom_text_field.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeatPasswordController =
      TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureRepeatPassword = true;

  @override
  void dispose() {
    super.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildInputFields(),
                const SizedBox(height: 32),
                _buildRegisterButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputFields() {
    return Column(
      children: [
        CustomTextField(
          label: 'Nombre de usuario',
          controller: _usernameController,
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Nombre a mostrar',
          controller: _displayNameController,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Email',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
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
        CustomTextField(
          label: 'Repetir Contraseña',
          controller: _repeatPasswordController,
          obscureText: _obscureRepeatPassword,
          onToggleVisibility: () {
            setState(() {
              _obscureRepeatPassword = !_obscureRepeatPassword;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return _isLoading
        ? CircularProgressIndicator(color: AppColors.primary)
        : CustomButton(text: 'Registrarse', onPressed: _register);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return; 
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _register() async {
    if (_usernameController.text.isEmpty ||
        _displayNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _repeatPasswordController.text.isEmpty) {
      _showErrorSnackBar('Por favor, rellena todos los campos');
      return;
    }

    if (_passwordController.text != _repeatPasswordController.text) {
      _showErrorSnackBar('Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final displayName = _displayNameController.text.trim();

      await authService.signUp(username, email, password, displayName);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      // Handle web socket connection
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

    } on UsernameTakenException {
      _showErrorSnackBar('El nombre de usuario ya está en uso. Por favor, elige otro.');
    } on EmailInUseException {
      _showErrorSnackBar('El correo electrónico ya está registrado.');
    } on InvalidEmailFormatException {
      _showErrorSnackBar('El formato del correo electrónico no es válido.');
    } on PasswordTooWeakException {
      _showErrorSnackBar('La contraseña es demasiado débil.');
    } on UsernameTooShortException {
      _showErrorSnackBar('El nombre de usuario es demasiado corto. Debe tener al menos 3 caracteres.');
    } on RegistrationException catch (e) {
      _showErrorSnackBar('Error de registro: ${e.message}');
    } catch (e) {
      _showErrorSnackBar('Ocurrió un error inesperado durante el registro.');
    }
  }
}
