// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '../constants/colors.dart';

class ChatScreen extends StatefulWidget {
  final UserModel friend;

  const ChatScreen({super.key, required this.friend});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  late MessageService _messageService;
  late AuthService _authService;
  late ConversationModel _conversation;
  late ScrollController _scrollController;
  // bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _authService = Provider.of<AuthService>(context, listen: false);
    _messageService = Provider.of<MessageService>(context, listen: false);

    // Get or create the conversation
    _conversation = _messageService.getOrCreateConversation(widget.friend);

    // Listen for new messages
    _messageService.messagesStream.listen((message) {
      // Filter only for this conversation
      if ((message.senderId == widget.friend.id &&
              message.recipientId == _authService.user!.id) ||
          (message.senderId == _authService.user!.id &&
              message.recipientId == widget.friend.id)) {
        setState(() {});
      }
    });

    // Listen for delivery confirmations
    _messageService.deliveryStream.listen((messageId) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Clear text field before sending to avoid duplicate send
      _messageController.clear();

      final message = await _messageService.sendMessage(widget.friend.id, text);

      setState(() {
        _isSending = false;
      });

      if (message != null) {
        // Scroll to bottom on new message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        // Show error if message wasn't sent
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo enviar el mensaje. Comprueba tu conexión.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMessageOptions(MessageModel message) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Eliminar mensaje'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ],
          ),
    );
  }

  void _deleteMessage(MessageModel message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Eliminar mensaje'),
            content: Text(
              '¿Estás seguro de que quieres eliminar este mensaje? Esta acción solo afecta a tu dispositivo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  await _messageService.deleteMessage(
                    widget.friend.id,
                    message.id,
                  );
                  Navigator.pop(context);
                  setState(() {});
                },
                child: Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the updated conversation
    _conversation =
        _messageService.conversations[widget.friend.id] ??
        ConversationModel(
          friendId: widget.friend.id,
          friendName: widget.friend.displayName,
          messages: [],
        );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              radius: 16,
              child: Text(
                widget.friend.displayName[0].toUpperCase(),
                style: TextStyle(fontSize: 14),
              ),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.friend.displayName, style: TextStyle(fontSize: 16)),
                Text(
                  '@${widget.friend.username}',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _showDeleteConversationDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child:
                _conversation.messages.isEmpty
                    ? _buildEmptyConversation()
                    : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      itemCount: _conversation.messages.length,
                      itemBuilder: (context, index) {
                        final message = _conversation.messages[index];
                        final isMyMessage =
                            message.senderId == _authService.user!.id;

                        return GestureDetector(
                          onLongPress: () => _showMessageOptions(message),
                          child: _buildMessageBubble(message, isMyMessage),
                        );
                      },
                    ),
          ),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // Message input
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                // Send button
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon:
                        _isSending
                            ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConversation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No hay mensajes aún',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Envía el primer mensaje para iniciar la conversación',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMyMessage) {
    return Align(
      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMyMessage ? Colors.blue[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text, style: TextStyle(fontSize: 16)),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTimestamp(message.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (isMyMessage) ...[
                  SizedBox(width: 4),
                  Icon(
                    message.delivered ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.delivered ? Colors.blue : Colors.grey[600],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConversationDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Eliminar conversación'),
            content: Text(
              '¿Estás seguro de que quieres eliminar esta conversación? Se borrarán todos los mensajes de este dispositivo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  await _messageService.deleteConversation(widget.friend.id);
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to home screen
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

    final time =
        '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';

    if (dateToCheck == today) {
      return time;
    } else if (dateToCheck == yesterday) {
      return 'Ayer, $time';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}, $time';
    }
  }
}
