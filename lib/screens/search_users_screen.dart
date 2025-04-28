// lib/screens/search_users_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import 'package:simple_messenger/constants/colors.dart';
import '../components/user_avatar.dart';
import '../components/error_display.dart';
import '../utils/logger.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  SearchUsersScreenState createState() => SearchUsersScreenState();
}

class SearchUsersScreenState extends State<SearchUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  late UserService _userService;
  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  String? _validationError;
  final Map<String, bool> _requestInProgress = {};
  final Set<String> _sentRequestsUsernames = {};
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _userService = Provider.of<UserService>(context, listen: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();

    if (query.length < 3) {
      if (!mounted) return;
      
      setState(() {
        _validationError = 'Ingresa al menos 3 caracteres para buscar';
        _isSearching = false;
        _searchResults = [];
        _searchError = null;
      });
      return;
    }

    _logger.d('Searching users with query: "$query"', tag: 'SearchUsersScreen');
    setState(() {
      _validationError = null;
      _isSearching = true;
      _searchError = null;
    });

    try {
      final results = await _userService.searchUsers(query);
      if (!mounted) return;
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
      _logger.i('User search returned ${results.length} results', tag: 'SearchUsersScreen');
    } catch (e) {
      _logger.e('Error during user search', error: e, tag: 'SearchUsersScreen');
      if (!mounted) return;
      
      setState(() {
        _isSearching = false;
        _searchError = 'Error al buscar usuarios';
      });
    }
  }

  Future<void> _sendFriendRequest(UserModel user) async {
    final username = user.username;
    if (_requestInProgress[username] == true || _sentRequestsUsernames.contains(username)) {
        _logger.d('Send request to $username skipped (already in progress or sent)', tag: 'SearchUsersScreen');
        return;
    }
    
    _logger.d('Attempting to send friend request to $username', tag: 'SearchUsersScreen');
    setState(() {
      _requestInProgress[username] = true;
    });

    try {
      await _userService.sendFriendRequest(username);

      _logger.i('Successfully sent friend request to $username', tag: 'SearchUsersScreen');
      if (!mounted) return;
      
      setState(() {
        _sentRequestsUsernames.add(username);
      });

    } catch (e) {
      _logger.e('Error sending friend request to $username', error: e, tag: 'SearchUsersScreen');
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text('Error al enviar solicitud'),
            content: Text(""),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      );

    } finally {
      if (mounted) {
        setState(() {
          _requestInProgress[username] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Buscar usuarios'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _buildBodyContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar por nombre de usuario o nombre completo',
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          suffixIcon: IconButton(
            icon: Icon(Icons.search, color: AppColors.primary),
            tooltip: 'Buscar',
            onPressed: _searchUsers,
          ),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(14),
             borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        onSubmitted: (_) => _searchUsers(),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isSearching) {
      return Center(child: CircularProgressIndicator());
    } else if (_searchError != null) {
      return ErrorDisplay(
        errorMessage: _searchError!,
        onRetry: _searchUsers,
      );
    } else if (_validationError != null) {
      return _buildInfoView(
        icon: Icons.warning_amber_rounded,
        message: _validationError!,
        color: Colors.orange[700],
      );
    } else if (_searchResults.isEmpty && _searchController.text.isEmpty) {
      return _buildSearchInstructions();
    } else if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return _buildNoUsersFoundView();
    } else {
      return _buildSearchResultsList();
    }
  }

  Widget _buildInfoView({required IconData icon, required String message, String? details, Color? color}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color ?? Colors.grey),
          SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
          if (details != null) ...[
            SizedBox(height: 8),
            Text(
              details,
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSearchInstructions() {
    return _buildInfoView(
      icon: Icons.search,
      message: 'Busca usuarios por nombre de usuario',
      details: 'Introduce al menos 3 caracteres',
    );
  }

  Widget _buildNoUsersFoundView() {
    return _buildInfoView(
      icon: Icons.person_off_outlined,
      message: 'No se encontraron usuarios',
    );
  }

  Widget _buildSearchResultsList() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildSearchResultTile(user);
      },
    );
  }

  Widget _buildSearchResultTile(UserModel user) {
    final isRequesting = _requestInProgress[user.username] ?? false;
    final alreadySent = _sentRequestsUsernames.contains(user.username);

    return ListTile(
      leading: UserAvatar(
        displayName: user.displayName,
        size: 45,
        backgroundColor: AppColors.primary.withAlpha((255 * 0.2).round()),
        textColor: AppColors.primary,
      ),
      title: Text(
        user.displayName,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '@${user.username}',
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: isRequesting
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : alreadySent
              ? Tooltip(
                  message: 'Solicitud enviada',
                  child: Icon(Icons.check_circle_outline, color: Colors.green),
                ) 
              : IconButton(
                  icon: Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
                  tooltip: 'Añadir amigo',
                  onPressed: alreadySent ? null : () => _sendFriendRequest(user),
                ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
