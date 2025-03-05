// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../models/chat_room_model.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ChatService _chatService;
  late UserService _userService;
  late AuthService _authService;
  List<ChatRoomModel> _chatRooms = [];
  List<UserModel> _users = [];
  bool _isLoadingChats = true;
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _chatService = Provider.of<ChatService>(context, listen: false);
    _userService = Provider.of<UserService>(context, listen: false);

    _loadChatRooms();
    _loadUsers();
  }

  Future<void> _loadChatRooms() async {
    setState(() {
      _isLoadingChats = true;
    });

    final chatRooms = await _chatService.getUserChatRooms();

    setState(() {
      _chatRooms = chatRooms;
      _isLoadingChats = false;
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    final users = await _userService.getAllUsers();

    setState(() {
      _users = users;
      _isLoadingUsers = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_authService.isAuthenticated) {
      return LoginScreen();
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Chimeo'),
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () async {
                await _authService.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
          bottom: TabBar(tabs: [Tab(text: 'Chats'), Tab(text: 'Users')]),
        ),
        body: TabBarView(children: [_buildChatsList(), _buildUsersList()]),
      ),
    );
  }

  Widget _buildChatsList() {
    if (_isLoadingChats) {
      return Center(child: CircularProgressIndicator());
    }

    if (_chatRooms.isEmpty) {
      return Center(child: Text('No conversations yet'));
    }

    return RefreshIndicator(
      onRefresh: _loadChatRooms,
      child: ListView.builder(
        itemCount: _chatRooms.length,
        itemBuilder: (context, index) {
          final chatRoom = _chatRooms[index];

          // Get the other participant (not the current user)
          final otherUser = chatRoom.participants.firstWhere(
            (user) => user.id != _authService.user!.id,
            orElse:
                () => UserModel(
                  id: 'unknown',
                  displayName: 'Unknown User',
                  email: '',
                  lastSeen: DateTime.now(),
                ),
          );

          return ListTile(
            leading: CircleAvatar(child: Text(otherUser.displayName[0])),
            title: Text(otherUser.displayName),
            subtitle: Text(chatRoom.lastMessage ?? 'No messages yet'),
            trailing:
                chatRoom.lastMessageTime != null
                    ? Text(_formatTimestamp(chatRoom.lastMessageTime!))
                    : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => ChatScreen(
                        chatRoomId: chatRoom.id,
                        otherUserName: otherUser.displayName,
                        otherUserId: otherUser.id,
                      ),
                ),
              ).then((_) => _loadChatRooms());
            },
          );
        },
      ),
    );
  }

  Widget _buildUsersList() {
    if (_isLoadingUsers) {
      return Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return Center(child: Text('No users found'));
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return ListTile(
            leading: CircleAvatar(child: Text(user.displayName[0])),
            title: Text(user.displayName),
            subtitle: Text('Last seen: ${_formatTimestamp(user.lastSeen)}'),
            onTap: () async {
              // Create chat room if not exists
              final chatRoom = await _chatService.createChatRoom(user.id);

              if (chatRoom != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ChatScreen(
                          chatRoomId: chatRoom.id,
                          otherUserName: user.displayName,
                          otherUserId: user.id,
                        ),
                  ),
                ).then((_) => _loadChatRooms());
              }
            },
          );
        },
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
      return 'Yesterday';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
