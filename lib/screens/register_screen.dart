import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_messenger/utils/exceptions.dart';
import '../components/custom_button.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'home_screen.dart';
import '../components/input_decorations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Unique reference to the form. Used to validate registration form
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeatPasswordController =
      TextEditingController();

  bool _isLoading = false;

  bool _obscurePassword = true;
  bool _obscureRepeatPassword = true;

  String? _apiError;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_clearApiError);
    _emailController.addListener(_clearApiError);
    _passwordController.addListener(_clearApiError);
  }

  @override
  void dispose() {
    super.dispose();

    _usernameController.removeListener(_clearApiError);
    _emailController.removeListener(_clearApiError);
    _passwordController.removeListener(_clearApiError);

    _usernameController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
  }

  void _clearApiError() {
    if (_apiError != null) {
      setState(() {
        _apiError = null;
      });
    }
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
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildInputFields(),
                  const SizedBox(height: 16),
                  if (_apiError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _apiError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  _buildRegisterButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputFields() {
    return Column(
      children: [
        TextFormField(
          controller: _usernameController,
          keyboardType: TextInputType.text,
          decoration: buildModernInputDecoration(
            labelText: 'Nombre de usuario',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, introduce un nombre de usuario';
            }
            if (value.length < 3) {
              return 'Debe tener al menos 3 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _displayNameController,
          decoration: buildModernInputDecoration(
            labelText: 'Nombre a mostrar',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, introduce un nombre a mostrar';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: buildModernInputDecoration(
            labelText: 'Email',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, introduce tu email';
            }
            if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
               return 'Introduce un email válido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: buildModernInputDecoration(
            labelText: 'Contraseña',
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey, size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, introduce una contraseña';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _repeatPasswordController,
          obscureText: _obscureRepeatPassword,
          decoration: buildModernInputDecoration(
            labelText: 'Repetir Contraseña',
            suffixIcon: IconButton(
              icon: Icon(
                _obscureRepeatPassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey, size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscureRepeatPassword = !_obscureRepeatPassword;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, repite la contraseña';
            }
            if (value != _passwordController.text) {
              return 'Las contraseñas no coinciden';
            }
            return null;
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

  Future<void> _register() async {
    setState(() {
      _apiError = null;
    });

    if (_formKey.currentState?.validate() != true) {
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

      final messageService = context.read<MessageService>();
      messageService.connectToWebSocket();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );

    } on UsernameTakenException {
      setState(() {
        _apiError = 'Nombre de usuario ya está en uso';
        _isLoading = false;
      });
    } on EmailInUseException {
      setState(() {
        _apiError = 'Correo electrónico ya registrado';
        _isLoading = false;
      });
    } on PasswordTooWeakException { 
      setState(() {
        _apiError = 'La contraseña es demasiado débil';
        _isLoading = false;
      });
    } on RegistrationException catch (e) { 
      setState(() {
        _apiError = 'Error de registro: ${e.message}';
        _isLoading = false;
      });
    } catch (e) { 
      setState(() {
        _apiError = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
        _isLoading = false;
      });
    }
  }
}
