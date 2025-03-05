// lib/screens/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../constants/colors.dart';
import 'login_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late AuthService _authService;
  late MessageService _messageService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _messageService = Provider.of<MessageService>(context, listen: false);
  }

  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signOut();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cerrar sesión: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearAllConversations() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Borrar todas las conversaciones'),
            content: Text(
              '¿Estás seguro de que quieres borrar todas tus conversaciones? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);

                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    // Clear conversations one by one
                    final conversationIds =
                        _messageService.conversations.keys.toList();
                    for (final id in conversationIds) {
                      await _messageService.deleteConversation(id);
                    }

                    setState(() {
                      _isLoading = false;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Todas las conversaciones han sido eliminadas',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    setState(() {
                      _isLoading = false;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error al eliminar conversaciones: ${e.toString()}',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text('Borrar todo', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_authService.user == null) {
      return Scaffold(body: Center(child: Text('No hay sesión iniciada')));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Mi perfil')),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 20),

                    // Profile avatar
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        _authService.user!.displayName[0].toUpperCase(),
                        style: TextStyle(fontSize: 40, color: Colors.white),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Display name
                    Text(
                      _authService.user!.displayName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 4),

                    // Username
                    Text(
                      '@${_authService.user!.username}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),

                    SizedBox(height: 40),

                    // Account information section
                    _buildSectionHeader('Información de la cuenta'),

                    // Note: We don't have access to email in UserModel currently,
                    // so we'll just show username instead
                    _buildInfoItem(
                      Icons.email,
                      'Nombre de usuario',
                      '@${_authService.user!.username}',
                    ),

                    Divider(),

                    // Actions section
                    _buildSectionHeader('Acciones'),

                    // Clear all conversations
                    _buildActionItem(
                      Icons.delete_sweep,
                      'Borrar todas las conversaciones',
                      'Elimina todos los mensajes de tu dispositivo',
                      Colors.orange,
                      _clearAllConversations,
                    ),

                    SizedBox(height: 12),

                    // Sign out
                    _buildActionItem(
                      Icons.logout,
                      'Cerrar sesión',
                      'Salir de la aplicación',
                      Colors.red,
                      _signOut,
                    ),

                    SizedBox(height: 40),

                    // App information
                    Text(
                      'Chimeo v1.0.0',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),

                    SizedBox(height: 8),

                    Text(
                      '© 2025 Chimeo Messaging',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),

                    SizedBox(height: 20),
                  ],
                ),
              ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
