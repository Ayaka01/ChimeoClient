// lib/screens/search_users_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import 'package:simple_messenger/constants/colors.dart';

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
  final Map<String, bool> _requestInProgress = {};

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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ingresa al menos 3 caracteres para buscar'),
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results = await _userService.searchUsers(query);

    if (!mounted) return;
    
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _sendFriendRequest(UserModel user) async {
    if (_requestInProgress[user.username] == true) return;

    setState(() {
      _requestInProgress[user.username] = true;
    });

    try {
      await _userService.sendFriendRequest(user.username);

      if (!mounted) return;
      
      setState(() {
        _searchResults.removeWhere((searchResult) => searchResult.username == user.username);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solicitud enviada a ${user.displayName}'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );

    } finally {
      if (mounted) {
        setState(() {
          _requestInProgress[user.username] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Buscar usuarios'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Buscar por nombre de usuario o nombre completo',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (_) => _searchUsers(),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchUsers,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  child: Text('Buscar'),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isSearching
                    ? Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                    ? _buildSearchInstructions()
                    : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchInstructions() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Busca usuarios por nombre o nombre de usuario',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Introduce al menos 3 caracteres para iniciar la búsqueda',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No se encontraron usuarios',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Intenta con otros términos de búsqueda',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final isRequesting = _requestInProgress[user.username] ?? false;

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(user.displayName[0].toUpperCase()),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('@${user.username}'),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                isRequesting
                    ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : ElevatedButton.icon(
                      icon: Icon(Icons.person_add),
                      label: Text('Añadir'),
                      onPressed: () => _sendFriendRequest(user),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
