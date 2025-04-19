// lib/screens/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../constants/colors.dart';
import 'login_screen.dart';
import '../components/user_avatar.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  UserProfileScreenState createState() => UserProfileScreenState();
}

class UserProfileScreenState extends State<UserProfileScreen> {
  late AuthService _authService;
  late MessageService _messageService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _messageService = Provider.of<MessageService>(context, listen: false);
  }

  // Show confirmation dialog before signing out
  Future<void> _signOut() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirmar Cierre de Sesión'),
          content: Text('¿Estás seguro de que quieres cerrar sesión?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // Return false when cancelled
              },
            ),
            TextButton(
              child: Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // Return true when confirmed
              },
            ),
          ],
        );
      },
    );

    // Proceed only if the user confirmed (dialog returned true)
    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _authService.signOut(context);

        if (!mounted) return;

        // Navigate to LoginScreen after successful sign out
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
        // No need to set _isLoading = false here as the screen is being replaced

      } catch (e) {
        if (!mounted) return;
        
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'), // More specific error
            backgroundColor: Colors.red,
          ),
        );
      }
    } 
    // If confirm is null or false, do nothing (dialog was dismissed or cancelled)
  }

  Future<void> _clearAllConversations() async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Eliminar conversaciones'),
        content: Text(
          '¿Estás seguro de que quieres eliminar todas las conversaciones? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              // Show loading indicator
              setState(() {
                _isLoading = true;
              });
              
              try {
                final success = await _messageService.clearAllLocalConversations();
                
                if (!mounted) return;
                
                setState(() {
                  _isLoading = false;
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Todas las conversaciones fueron eliminadas'
                          : 'Error al eliminar conversaciones',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                
                setState(() {
                  _isLoading = false;
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.user;
    if (currentUser == null) {
      // Handle case where user data might not be available yet
      return Scaffold(
        appBar: AppBar(title: Text('Mi perfil')), 
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Mi perfil')), 
      body:
          _isLoading 
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Use UserAvatar component
                    UserAvatar(
                      displayName: currentUser.displayName,
                      avatarUrl: currentUser.avatarUrl,
                      size: 100, // Larger size for profile screen
                      // Customize background/text if needed
                      // backgroundColor: AppColors.primary.withOpacity(0.1),
                      // textColor: AppColors.primary,
                    ),

                    SizedBox(height: 20),

                    // Display name
                    Text(
                      currentUser.displayName,
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.w600, // Slightly bolder
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 6),

                    // Username
                    Text(
                      '@${currentUser.username}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),

                    SizedBox(height: 40),

                    // Account information section
                    _buildSectionHeader('Información de la cuenta'),
                    SizedBox(height: 8),
                    _buildInfoItem(
                      Icons.alternate_email_outlined, // Icon for username
                      'Nombre de usuario',
                      '@${currentUser.username}',
                    ),
                    // Add email here if it becomes available in UserModel
                    // _buildInfoItem(Icons.email_outlined, 'Email', currentUser.email ?? 'N/A'),

                    Divider(height: 40, thickness: 1), // Add divider with more space

                    // Actions section
                    _buildSectionHeader('Acciones'),
                    SizedBox(height: 8),

                    // Clear all conversations - refactored to ListTile
                    _buildActionListTile(
                      icon: Icons.delete_sweep_outlined,
                      title: 'Borrar todas las conversaciones',
                      subtitle: 'Elimina todos los mensajes de tu dispositivo',
                      color: Colors.orange[700]!, // Use a specific shade
                      onTap: _clearAllConversations,
                    ),

                    SizedBox(height: 12), // Consistent spacing

                    // Sign out - refactored to ListTile
                    _buildActionListTile(
                      icon: Icons.logout_outlined,
                      title: 'Cerrar sesión',
                      subtitle: 'Salir de la aplicación',
                      color: Colors.red, 
                      onTap: _signOut,
                    ),

                    SizedBox(height: 60), // More space before app info

                    // App information
                    Text(
                      'Chimeo v1.0.0', // TODO: Get version dynamically
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '© ${DateTime.now().year} Chimeo Messaging',
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

  // Refactored Action Item using ListTile
  Widget _buildActionListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          // fontSize: 16, // Default ListTile font size is usually fine
          fontWeight: FontWeight.w500, // Medium weight
          color: color,
        ),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 8), // Adjust padding
      shape: RoundedRectangleBorder( // Optional: Add subtle rounded corners
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!, width: 1), // Optional: Subtle border
      ),
      // tileColor: Colors.grey[50], // Optional: Slight background color
    );
  }
}
