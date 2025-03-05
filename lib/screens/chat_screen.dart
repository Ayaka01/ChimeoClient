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

  // Track message delivery status updates
  final Map<String, bool> _deliveryStatus = {};

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
          // Check if this message is already in our list
          bool exists = _messages.any((m) => m.id == message.id);
          if (!exists) {
            _messages.insert(0, message);
          }
        });
      }
    });

    // Listen for delivery confirmations
    _chatService.deliveryStream.listen((messageId) {
      setState(() {
        _deliveryStatus[messageId] = true;

        // Update the actual message in our list
        int index = _messages.indexWhere((msg) => msg.id == messageId);
        if (index >= 0) {
          _messages[index].delivered = true;
        }
      });
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

    // Initialize delivery status tracking
    for (var message in messages) {
      _deliveryStatus[message.id] = message.delivered;
    }

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
                        final isDelivered =
                            _deliveryStatus[message.id] ?? message.delivered;

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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatTimestamp(message.timestamp),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    // Show delivery status for sent messages
                                    if (isMyMessage) ...[
                                      SizedBox(width: 5),
                                      Icon(
                                        isDelivered
                                            ? Icons
                                                .done_all // Double check mark
                                            : Icons.done, // Single check mark
                                        size: 12,
                                        color:
                                            isDelivered
                                                ? Colors.blue
                                                : Colors.grey[600],
                                      ),
                                    ],
                                  ],
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
        _deliveryStatus[newMessage.id] = newMessage.delivered;
      });
    }
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
