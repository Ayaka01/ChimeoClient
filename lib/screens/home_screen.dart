// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_messenger/constants/colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '../components/user_avatar.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'friend_requests_screen.dart';
import 'search_users_screen.dart';
import 'user_profile_screen.dart';
import 'message_search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UserService _userService;
  late AuthService _authService;
  late MessageService _messageService;
  List<UserModel> _friends = [];
  bool _isLoadingFriends = true;
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  
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
    
    // Listen for typing indicators
    _messageService.typingStream.listen((data) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
    // Store mounted state before async operation
    final isWidgetMounted = mounted;

    // No need to explicitly clear conversations here anymore
    // as it will be handled within the authService.signOut() method
    await _authService.signOut(context);

    // Check if widget is still mounted after async operation
    if (isWidgetMounted && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    }
  }
  
  void _openMessageSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MessageSearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_authService.isAuthenticated) {
      return LoginScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      drawer: _buildNavigationDrawer(),
      body: Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(splashColor: Color(0xFFFFD700)), // Yellow color
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Chats'),
                Tab(text: 'Amigos'),
              ],
              labelColor: Colors.black,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildConversationsList(), _buildFriendsList()],
            ),
          ),
        ],
      ),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text('Chimeo', style: TextStyle(color: Colors.black)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            icon: Icon(Icons.person_search),
            tooltip: 'Buscar personas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchUsersScreen()),
              ).then((_) => _loadFriends());
            },
          ),
        ),
      ],
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
        
    final filteredConversations = sortedConversations;

    return filteredConversations.isEmpty 
      ? Center(
          child: Text(
            'No se encontraron conversaciones que coincidan',
            style: TextStyle(color: Colors.grey),
          ),
        )
      : ListView.builder(
        itemCount: filteredConversations.length,
        itemBuilder: (context, index) {
          final conversation = filteredConversations[index].value;
          final friendId = filteredConversations[index].key;
          final lastMessage = conversation.lastMessage;
          
          // Find the corresponding friend
          final friend = _friends.firstWhere(
            (f) => f.username == friendId,
            orElse: () => UserModel(
              username: friendId,
              displayName: conversation.friendName,
              lastSeen: DateTime.now(),
            ),
          );

          return _buildConversationTile(conversation, friendId, lastMessage, friend);
        },
      );
  }
  
  Widget _buildConversationTile(
    ConversationModel conversation, 
    String friendId, 
    MessageModel? lastMessage,
    UserModel friend
  ) {
    return ListTile(
      leading: UserAvatar(
        displayName: conversation.friendName,
        avatarUrl: conversation.friendAvatarUrl,
        status: friend.status,
        size: 50,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.friendName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (lastMessage != null)
            Text(
              _formatTimestamp(lastMessage.timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (conversation.isTyping)
            Row(
              children: [
                Text(
                  'Escribiendo',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 4),
                _buildTypingIndicator(),
              ],
            )
          else if (lastMessage != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    lastMessage.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: lastMessage.error
                          ? Colors.red
                          : Colors.grey[600],
                    ),
                  ),
                ),
                SizedBox(width: 4),
                if (lastMessage.senderId == _authService.user!.username)
                  Icon(
                    lastMessage.error
                        ? Icons.error_outline
                        : lastMessage.delivered
                            ? Icons.done_all
                            : Icons.done,
                    size: 16,
                    color: lastMessage.error
                        ? Colors.red
                        : lastMessage.read
                            ? Colors.green
                            : Colors.grey,
                  ),
              ],
            )
          else
            Text('No hay mensajes'),
        ],
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
  }

  Widget _buildTypingIndicator() {
    return SizedBox(
      width: 20,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          3,
          (index) => _buildDot(index),
        ),
      ),
    );
  }
  
  Widget _buildDot(int index) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300),
      curve: Interval(index * 0.2, 0.7 + index * 0.1, curve: Curves.easeInOut),
      builder: (context, double value, child) {
        // Convert value (0.0-1.0) to alpha (0-255)
        final int alpha = (value * 255).round();
        return Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(alpha),
            shape: BoxShape.circle,
          ),
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
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No tienes amigos añadidos',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Busca usuarios para añadirlos como amigos',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return _friends.isEmpty
        ? Center(
            child: Text(
              'No se encontraron amigos que coincidan',
              style: TextStyle(color: Colors.grey),
            ),
          )
        : ListView.builder(
            itemCount: _friends.length,
            itemBuilder: (context, index) {
              final friend = _friends[index];
              
              return ListTile(
                leading: UserAvatar(
                  displayName: friend.displayName,
                  avatarUrl: friend.avatarUrl,
                  status: friend.status,
                  size: 50,
                ),
                title: Text(friend.displayName),
                subtitle: Text('@${friend.username}'),
                trailing: friend.statusMessage != null 
                    ? SizedBox(
                        width: 100,
                        child: Text(
                          friend.statusMessage!,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : null,
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
          );
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(_authService.user!.displayName),
            accountEmail: Text('@${_authService.user!.username}'),
            currentAccountPicture: UserAvatar(
              displayName: _authService.user!.displayName,
              size: 60,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserProfileScreen()),
                );
              },
            ),
            decoration: BoxDecoration(
              color: AppColors.primary,
            ),
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
          Divider(),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Cerrar sesión'),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'ahora';
    }
  }
}
