import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/message_service.dart';
import '../models/message_model.dart';
import 'chat_screen.dart';
import '../components/user_avatar.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../utils/logger.dart';

class MessageSearchScreen extends StatefulWidget {
  const MessageSearchScreen({super.key});

  @override
  MessageSearchScreenState createState() => MessageSearchScreenState();
}

class MessageSearchScreenState extends State<MessageSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, List<MessageModel>> _searchResults = {};
  bool _isSearching = false;
  late MessageService _messageService;
  late UserService _userService;
  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    _messageService = Provider.of<MessageService>(context, listen: false);
    _userService = Provider.of<UserService>(context, listen: false);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.length >= 3) {
      setState(() {
        _isSearching = true;
      });
      
      // Perform the search
      _performSearch(query);
    } else {
      setState(() {
        _searchResults = {};
        _isSearching = false;
      });
    }
  }

  void _performSearch(String query) {
    final results = _messageService.searchMessages(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Buscar Mensajes'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar mensajes (mínimo 3 caracteres)...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
            ),
          ),
        ),
      ),
      body: _buildSearchResults(),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Introduce al menos 3 caracteres para buscar',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No se encontraron mensajes con "${_searchController.text}"',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final conversationId = _searchResults.keys.elementAt(index);
        final messages = _searchResults[conversationId]!;
        final conversation = _messageService.conversations[conversationId];

        // Skip if conversation doesn't exist anymore (rare case)
        if (conversation == null) return SizedBox.shrink();

        return ExpansionTile(
          title: Text(conversation.friendName),
          subtitle: Text('${messages.length} mensajes encontrados'),
          leading: UserAvatar(
            displayName: conversation.friendName,
            avatarUrl: conversation.friendAvatarUrl,
            size: 40,
          ),
          children: messages.map((message) {
            return ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 32.0),
              title: Text(
                message.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _formatTimestamp(message.timestamp),
                style: TextStyle(fontSize: 12),
              ),
              onTap: () {
                _navigateToChat(conversationId);
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _navigateToChat(String username) async {
    try {
      final friend = await _userService.getUserProfile(username);
      if (friend != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(friend: friend),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error navigating to chat', error: e, tag: 'MessageSearchScreen');
      // If there's an error fetching the friend profile, create a simple UserModel
      final fallbackUser = UserModel(
        username: username,
        displayName: _messageService.conversations[username]?.friendName ?? username,
        lastSeen: DateTime.now(),
      );
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(friend: fallbackUser),
          ),
        );
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} días atrás';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} horas atrás';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutos atrás';
    } else {
      return 'hace un momento';
    }
  }
} 