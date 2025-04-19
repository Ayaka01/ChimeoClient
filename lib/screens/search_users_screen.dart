// lib/screens/search_users_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import 'package:simple_messenger/constants/colors.dart';
import '../components/user_avatar.dart';

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
    } else if (_searchResults.isEmpty && _searchController.text.isEmpty) {
      return _buildSearchInstructions();
    } else if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return _buildNoUsersFoundView();
    } else {
      return _buildSearchResultsList();
    }
  }

  Widget _buildSearchInstructions() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Busca usuarios por nombre de usuario',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Introduce al menos 3 caracteres',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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

    return ListTile(
      leading: UserAvatar(
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        size: 45,
        backgroundColor: AppColors.primary.withOpacity(0.2),
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
          : IconButton(
              icon: Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
              tooltip: 'Añadir amigo',
              onPressed: () => _sendFriendRequest(user),
            ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildNoUsersFoundView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 64, color: Colors.grey),
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
}
