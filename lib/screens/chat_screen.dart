// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String otherUserName;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  late ChatService _chatService;
  late AuthService _authService;
  List<MessageModel> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _chatService = Provider.of<ChatService>(context, listen: false);

    // Join chat room for WebSocket updates
    _chatService.joinChatRoom(widget.chatRoomId);

    // Load existing messages
    _loadMessages();

    // Listen for new messages
    _chatService.messagesStream.listen((message) {
      if (message.chatRoomId == widget.chatRoomId) {
        setState(() {
          _messages.insert(0, message);
        });
      }
    });
  }

  @override
  void dispose() {
    // Leave chat room
    _chatService.leaveChatRoom(widget.chatRoomId);
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    final messages = await _chatService.getMessages(widget.chatRoomId);

    setState(() {
      _messages = messages;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherUserName)),
      body: Column(
        children: [
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? Center(child: Text('No messages yet'))
                    : ListView.builder(
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMyMessage =
                            message.senderId == _authService.user!.id;

                        return Align(
                          alignment:
                              isMyMessage
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 10,
                            ),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  isMyMessage
                                      ? Colors.blue[100]
                                      : Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(message.text),
                                SizedBox(height: 5),
                                Text(
                                  _formatTimestamp(message.timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final text = _messageController.text.trim();
    _messageController.clear();

    final newMessage = await _chatService.sendMessage(
      text,
      widget.chatRoomId,
      widget.otherUserId,
    );

    if (newMessage != null) {
      setState(() {
        _messages.insert(0, newMessage);
      });
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day - 1,
    );
    final dateToCheck = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    String time =
        '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';

    if (dateToCheck == today) {
      return time;
    } else if (dateToCheck == yesterday) {
      return 'Yesterday, $time';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}, $time';
    }
  }
}
