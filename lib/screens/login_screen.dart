import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_messenger/utils/exceptions.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import '../components/custom_button.dart';
import '../components/input_decorations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Unique reference to the form. Used to validate login form
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  // To show error messages on the form
  String? _apiError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();

    // Add listeners to clear general API error on input
    _emailController.addListener(_clearApiError);
    _passwordController.addListener(_clearApiError);
  }

  @override
  void dispose() {
    super.dispose();

    _emailController.removeListener(_clearApiError);
    _passwordController.removeListener(_clearApiError);

    _emailController.dispose();
    _passwordController.dispose();

  }

  void _clearApiError() {
      setState(() {
        _apiError = null;
      });
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
              child: Form(
                key: _formKey,
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
    return TextFormField(
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
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: buildModernInputDecoration(
        labelText: 'Contraseña',
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
            size: 20,
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
          return 'Por favor, introduce tu contraseña';
        }
        return null;
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
    setState(() => _apiError = null);

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      final messageService = context.read<MessageService>();

      final email = _emailController.text.trim();
      final password = _passwordController.text;

      await authService.signIn(email, password);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      messageService.connectToWebSocket();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );

    } on InvalidCredentialsException {
        setState(() {
          _apiError = 'Email o contraseña incorrectos.';
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
