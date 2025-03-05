// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_messenger/constants/colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'friend_requests_screen.dart';
import 'search_users_screen.dart';
import 'user_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UserService _userService;
  late AuthService _authService;
  late MessageService _messageService;
  List<UserModel> _friends = [];
  bool _isLoadingFriends = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _authService = Provider.of<AuthService>(context, listen: false);
    _userService = Provider.of<UserService>(context, listen: false);
    _messageService = Provider.of<MessageService>(context, listen: false);

    _loadFriends();

    // Listen for new messages
    _messageService.messagesStream.listen((message) {
      // Refresh the screen when a new message arrives
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoadingFriends = true;
    });

    final friends = await _userService.getFriends();

    // Ensure conversations exist for all friends
    for (var friend in friends) {
      _messageService.getOrCreateConversation(friend);
    }

    setState(() {
      _friends = friends;
      _isLoadingFriends = false;
    });
  }

  void _signOut() async {
    await _authService.signOut();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_authService.isAuthenticated) {
      return LoginScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Chimeo'),
        actions: [
          // Friend requests button
          IconButton(
            icon: Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FriendRequestsScreen()),
              ).then((_) => _loadFriends());
            },
          ),
          // Search users button
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchUsersScreen()),
              ).then((_) => _loadFriends());
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [Tab(text: 'Chats'), Tab(text: 'Amigos')],
        ),
      ),
      drawer: _buildNavigationDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: [_buildConversationsList(), _buildFriendsList()],
      ),
    );
  }

  Widget _buildConversationsList() {
    final conversations = _messageService.conversations;

    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No tienes conversaciones activas',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Busca amigos para empezar a chatear',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Sort conversations by most recent message
    final sortedConversations =
        conversations.entries.toList()..sort((a, b) {
          final aTime = a.value.lastMessage?.timestamp ?? DateTime(2000);
          final bTime = b.value.lastMessage?.timestamp ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });

    return ListView.builder(
      itemCount: sortedConversations.length,
      itemBuilder: (context, index) {
        final conversation = sortedConversations[index].value;
        final friendId = sortedConversations[index].key;
        final lastMessage = conversation.lastMessage;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(conversation.friendName[0].toUpperCase()),
          ),
          title: Text(conversation.friendName),
          subtitle:
              lastMessage != null
                  ? Text(
                    lastMessage.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                  : Text('No hay mensajes'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (lastMessage != null)
                Text(
                  _formatTimestamp(lastMessage.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              SizedBox(height: 4),
              if (lastMessage != null &&
                  lastMessage.senderId == _authService.user!.id)
                Icon(
                  lastMessage.delivered ? Icons.done_all : Icons.done,
                  size: 16,
                  color: lastMessage.delivered ? Colors.blue : Colors.grey,
                ),
            ],
          ),
          onTap: () {
            // Find the friend from our list
            final friend = _friends.firstWhere(
              (f) => f.id == friendId,
              orElse:
                  () => UserModel(
                    id: friendId,
                    username: '',
                    displayName: conversation.friendName,
                    lastSeen: DateTime.now(),
                  ),
            );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(friend: friend),
              ),
            ).then((_) => setState(() {}));
          },
          onLongPress: () {
            _showDeleteConversationDialog(friendId, conversation.friendName);
          },
        );
      },
    );
  }

  Widget _buildFriendsList() {
    if (_isLoadingFriends) {
      return Center(child: CircularProgressIndicator());
    }

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No tienes amigos aún',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Busca usuarios para enviar solicitudes de amistad',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.search),
              label: Text('Buscar usuarios'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SearchUsersScreen()),
                ).then((_) => _loadFriends());
              },
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView.builder(
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(friend.displayName[0].toUpperCase()),
            ),
            title: Text(friend.displayName),
            subtitle: Text('@${friend.username}'),
            trailing: Text(
              'Última conexión: ${_formatTimestamp(friend.lastSeen)}',
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(friend: friend),
                ),
              ).then((_) => setState(() {}));
            },
          );
        },
      ),
    );
  }

  void _showDeleteConversationDialog(String friendId, String friendName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Eliminar conversación'),
            content: Text(
              '¿Estás seguro de que quieres eliminar tu conversación con $friendName? Se borrarán todos los mensajes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  _messageService.deleteConversation(friendId);
                  Navigator.pop(context);
                  setState(() {});
                },
                child: Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (dateToCheck == today) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (dateToCheck == yesterday) {
      return 'Ayer';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(_authService.user?.displayName ?? 'Usuario'),
            accountEmail: Text('@${_authService.user?.username ?? ''}'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _authService.user?.displayName[0].toUpperCase() ?? 'U',
                style: TextStyle(fontSize: 24, color: AppColors.primary),
              ),
            ),
            decoration: BoxDecoration(color: AppColors.primary),
          ),
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Mi perfil'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UserProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.person_add),
            title: Text('Solicitudes de amistad'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FriendRequestsScreen()),
              ).then((_) => _loadFriends());
            },
          ),
          ListTile(
            leading: Icon(Icons.search),
            title: Text('Buscar usuarios'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchUsersScreen()),
              ).then((_) => _loadFriends());
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.exit_to_app, color: Colors.red),
            title: Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              _signOut();
            },
          ),
        ],
      ),
    );
  }
}
