import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_messenger/config/app_config.dart';
import 'package:simple_messenger/constants/colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '../components/user_avatar.dart';
import '../components/error_display.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'friend_requests_screen.dart';
import 'search_users_screen.dart';
import 'user_profile_screen.dart';
import '../utils/logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final Logger _logger = Logger();

  late UserService _userService;
  late AuthService _authService;
  late MessageService _messageService;

  List<UserModel> _friends = [];
  bool _isLoadingFriends = true;
  String? _friendsError;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _authService = context.read<AuthService>();
    _userService = context.read<UserService>();
    _messageService = context.read<MessageService>();

    _loadFriends();

    _messageService.messagesStream.listen((message) {
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
      _friendsError = null;
    });

    try {
      final friends = await _userService.getFriends();

      // Ensure conversations exist for all friends
      for (var friend in friends) {
        _messageService.getOrCreateConversation(friend);
      }

      if (!mounted) return;
      setState(() {
        _friends = friends;
        _isLoadingFriends = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingFriends = false;
        _friendsError = "Error al cargar amigos";
      });
    }
  }

  void _signOut() async {
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
                Navigator.of(dialogContext).pop(false); // Return false
              },
            ),
            TextButton(
              child: Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // Return true
              },
            ),
          ],
        );
      },
    );

    // Proceed only if the user confirmed
    if (confirm == true) {
      final isWidgetMounted = mounted;
      _logger.i('User confirmed sign out', tag: 'HomeScreen');

      try {
        await _authService.signOut();

        // Check if widget is still mounted after async operation
        if (isWidgetMounted && mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
         _logger.e('Error during sign out process', error: e, tag: 'HomeScreen');
         if (isWidgetMounted && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al cerrar sesión: $e'),
                backgroundColor: Colors.red,
              ),
            );
         }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authService.isAuthenticated) {
      return LoginScreen();
    }

    return Scaffold(
      appBar: _buildAppBar(),
      drawer: _buildNavigationDrawer(),
      body: Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(splashColor: AppColors.primary),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Chats'),
                Tab(text: 'Amigos'),
              ],
              labelColor: AppColors.secondary,
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
      title: Text(AppConfig.appName, style: TextStyle(color: AppColors.secondary)),
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
    final sortedConversations = _getSortedConversations();

    if (sortedConversations.isEmpty) {
      return _buildEmptyConversationsView();
    }

    final filteredConversations = sortedConversations; 

    return ListView.builder(
      itemCount: filteredConversations.length,
      itemBuilder: (context, index) {
        final conversation = filteredConversations[index].value;
        final friendId = filteredConversations[index].key;

        final friend = _friends.firstWhere(
          (f) => f.username == friendId,
          orElse: () => UserModel(
            username: friendId,
            displayName: conversation.friendName,
          ),
        );

        return _buildConversationTile(conversation, friendId, friend);
      },
    );
  }

  List<MapEntry<String, ConversationModel>> _getSortedConversations() {
    final conversations = _messageService.conversations;
    final sortedList = conversations.entries.toList()
      ..sort((a, b) {
        // Use a very old date for conversations without messages to put them last
        final aTime = a.value.lastMessage?.timestamp ?? DateTime(1970);
        final bTime = b.value.lastMessage?.timestamp ?? DateTime(1970);
        return bTime.compareTo(aTime); // Sort descending (most recent first)
      });
    return sortedList;
  }

  Widget _buildEmptyConversationsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No tienes conversaciones activas',
            style: Theme.of(context).textTheme.bodyMedium,
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
  
  Widget _buildConversationTile(
    ConversationModel conversation, 
    String friendId,
    UserModel friend
  ) {
    // Get last message directly from conversation model
    final lastMessage = conversation.lastMessage; 

    return ListTile(
      leading: UserAvatar(
        displayName: friend.displayName,
        size: 50,
      ),
      title: _buildConversationTitleRow(friend, lastMessage),
      subtitle: _buildConversationSubtitle(conversation, lastMessage, friend),
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

  Widget _buildConversationTitleRow(UserModel friend, MessageModel? lastMessage) {
    return Row(
      children: [
        Expanded(
          child: Text(
            friend.displayName,
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
    );
  }

  Widget _buildConversationSubtitle(
    ConversationModel conversation, 
    MessageModel? lastMessage, 
    UserModel friend
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lastMessage != null)
          _buildLastMessageRow(lastMessage)
        else
          Text('No hay mensajes', style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  // Builds the row displaying the last message text and status icon
  Widget _buildLastMessageRow(MessageModel lastMessage) {
    final bool isCurrentUserSender = lastMessage.senderId == _authService.user!.username;
    
    return Row(
      children: [
        Expanded(
          child: Text(
            lastMessage.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: lastMessage.error ? Colors.red : Colors.grey[600],
            ),
          ),
        ),
        SizedBox(width: 4),
        if (isCurrentUserSender)
          Icon(
            // Simplified icon logic for conversation list
            lastMessage.error
                ? Icons.error_outline // Error
                : lastMessage.delivered
                    ? Icons.done_all    // Delivered (Double Tick)
                    : Icons.schedule,   // Pending (Clock) - Or Icons.done for single tick if preferred
            size: 16,
            // Simplified color logic
            color: lastMessage.error
                ? Colors.red
                : Colors.grey, // Use grey for pending/delivered in list view
          ),
      ],
    );
  }

  Widget _buildFriendsList() {
    if (_isLoadingFriends) {
      return Center(child: CircularProgressIndicator());
    }
    if (_friendsError != null) {
      return ErrorDisplay(
        errorMessage: _friendsError!,
        onRetry: _loadFriends,
      );
    }
    if (_friends.isEmpty) {
      return _buildEmptyFriendsView();
    }

    // Filtering logic could be added here later
    final filteredFriends = _friends;

    return ListView.builder(
      itemCount: filteredFriends.length,
      itemBuilder: (context, index) {
        final friend = filteredFriends[index];
        return _buildFriendListTile(friend);
      },
    );
  }

  // Builds the view shown when there are no friends
  Widget _buildEmptyFriendsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No tienes amigos añadidos',
            style: Theme.of(context).textTheme.bodyMedium,
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

  Widget _buildFriendListTile(UserModel friend) {
    return ListTile(
      leading: UserAvatar(
        displayName: friend.displayName,
        size: 50,
      ),
      title: Text(friend.displayName),
      subtitle: Text('@${friend.username}'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(friend: friend),
          ),
        ).then((_) => setState(() {})); // Refresh on return
      },
    );
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),
          _buildDrawerNavigationItems(),
          Divider(),
          _buildDrawerActionItems(),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    final currentUser = _authService.user;
    if (currentUser == null) {
      return const SizedBox.shrink(); 
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 40.0, 16.0, 20.0), // Adjust top padding (consider safe area)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            displayName: currentUser.displayName,
            size: 60,
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UserProfileScreen()),
              );
            },
          ),
          SizedBox(height: 12),
          Text(
            currentUser.displayName,
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold, 
              color: AppColors.secondary, // Match app bar color
            ),
          ),
          SizedBox(height: 4),
          Text(
            '@${currentUser.username}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // Builds the main navigation items for the drawer
  Widget _buildDrawerNavigationItems() {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.person_outline), 
          title: Text('Mi perfil'),
          dense: true, // Make tile compact
          onTap: () {
            Navigator.pop(context); 
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UserProfileScreen()),
            );
          },
        ),
        ListTile(
          leading: Icon(Icons.search_outlined), 
          title: Text('Buscar usuarios'),
          dense: true, // Make tile compact
          onTap: () {
            Navigator.pop(context); 
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SearchUsersScreen()),
            ).then((_) => _loadFriends()); 
          },
        ),
        ListTile(
          leading: Icon(Icons.person_add_outlined), 
          title: Text('Solicitudes de amistad'),
          dense: true, // Make tile compact
          onTap: () {
            Navigator.pop(context); 
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FriendRequestsScreen()),
            ).then((_) => _loadFriends()); 
          },
        ),
      ],
    );
  }

  // Builds the action items (like sign out) for the drawer
  Widget _buildDrawerActionItems() {
    return Column(
      children: [
         ListTile(
          leading: Icon(Icons.logout_outlined), 
          title: Text('Cerrar sesión'),
          dense: true, // Make tile compact
          onTap: _signOut,
        ),
      ],
    );
  }

  // Update to handle nullable DateTime?
  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return "-"; // Or some other placeholder
    }
    
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
