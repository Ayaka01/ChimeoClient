// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '../constants/colors.dart';
import '../components/user_avatar.dart';
import '../utils/logger.dart';

class ChatScreen extends StatefulWidget {
  final UserModel friend;
  final String? highlightMessageId;

  const ChatScreen({
    super.key,
    required this.friend,
    this.highlightMessageId,
  });

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late MessageService _messageService;
  late AuthService _authService;
  late UserService _userService;
  late ConversationModel _conversation;
  late ScrollController _scrollController;
  bool _isSending = false;
  String? _highlightedMessageId;
  Timer? _typingTimer;
  bool _isTyping = false;
  
  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _authService = Provider.of<AuthService>(context, listen: false);
    _messageService = Provider.of<MessageService>(context, listen: false);
    _userService = Provider.of<UserService>(context, listen: false);

    // Get or create the conversation
    _conversation = _messageService.getOrCreateConversation(widget.friend);
    
    // Set initial highlighted message if provided
    _highlightedMessageId = widget.highlightMessageId;
    
    // Setup focus node and typing detection
    _messageFocusNode.addListener(_onFocusChange);
    
    // Setup controller listener for typing detection
    _messageController.addListener(_onTextChange);

    // Listen for new messages
    _messageService.messagesStream.listen((message) {
      // Filter only for this conversation
      if ((message.senderId == widget.friend.username &&
              message.recipientId == _authService.user!.username) ||
          (message.senderId == _authService.user!.username &&
              message.recipientId == widget.friend.username)) {
        setState(() {});
        
        // Scroll to bottom for new messages
        if (message.senderId == widget.friend.username) {
          _scrollToBottom();
        }
      }
    });

    // Listen for delivery confirmations
    _messageService.deliveryStream.listen((messageId) {
      setState(() {});
    });
    
    // Listen for typing indicators
    _messageService.typingStream.listen((data) {
      final username = data['username'] as String;
      
      // Only update if it's about our current friend
      if (username == widget.friend.username) {
        setState(() {});
      }
    });
    
    // If there's a highlighted message, scroll to it after build
    if (_highlightedMessageId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToHighlightedMessage();
      });
    } else {
      // Otherwise scroll to bottom on first load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
    
    // Get friend status update
    _loadFriendData();
  }
  
  void _loadFriendData() async {
    try {
      final friend = await _userService.getUserProfile(widget.friend.username);
      if (friend != null && mounted) {
        _messageService.getOrCreateConversation(friend);
        setState(() {});
      }
    } catch (e) {
      _logger.e('Error loading friend data', error: e, tag: 'ChatScreen');
    }
  }
  
  void _onFocusChange() {
    if (_messageFocusNode.hasFocus) {
      // Scroll to bottom when focusing
      _scrollToBottom();
    }
  }
  
  void _onTextChange() {
    // Send typing indicator when user starts typing
    if (_messageController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _messageService.sendTypingIndicator(widget.friend.username, true);
    }
    
    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 3), () {
      if (_isTyping) {
        _isTyping = false;
        _messageService.sendTypingIndicator(widget.friend.username, false);
      }
    });
  }
  
  void _scrollToHighlightedMessage() {
    if (_highlightedMessageId == null) return;
    
    final index = _conversation.messages.indexWhere(
      (msg) => msg.id == _highlightedMessageId
    );
    
    if (index != -1) {
      final itemPosition = index * 80.0; // Estimated height of each message
      _scrollController.jumpTo(
        _scrollController.position.maxScrollExtent - itemPosition
      );
      
      // Highlight briefly and then remove highlight
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    }
  }
  
  void _scrollToBottom() {
    // Only scroll if we have a scroll controller with clients
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      // If scroll controller doesn't have clients yet, schedule a scroll after the next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChange);
    _messageController.dispose();
    _messageFocusNode.removeListener(_onFocusChange);
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    
    // Ensure typing indicator is off when leaving
    _messageService.sendTypingIndicator(widget.friend.username, false);
    
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
      
      // Reset typing indicator
      _isTyping = false;
      _typingTimer?.cancel();
      _messageService.sendTypingIndicator(widget.friend.username, false);

      final message = await _messageService.sendMessage(
        widget.friend.username,
        text,
      );

      // Check if widget is still mounted before using context
      if (!mounted) return;

      setState(() {
        _isSending = false;
      });
      
      // Scroll to bottom on new message (even if optimistic UI already added it)
      _scrollToBottom();

      if (message == null) {
        // Message failed to send despite optimistic update
        // The MessageService will have marked it as failed
      }
    } catch (e) {
      // Check if widget is still mounted before using context
      if (!mounted) return;

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
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.add_comment),
            title: Text('Add all messages'),
            onTap: () {
              Navigator.pop(context);
              // Implement the logic to add all messages
            },
          ),
          ListTile(
            leading: Icon(Icons.copy, color: AppColors.primary),
            title: Text('Copiar mensaje'),
            onTap: () {
              Navigator.pop(context);
              _copyMessageToClipboard(message);
            },
          ),
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
  
  void _copyMessageToClipboard(MessageModel message) {
    // Copy to clipboard functionality would go here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mensaje copiado al portapapeles'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _deleteMessage(MessageModel message) {
    // Create a local function to handle the deletion process
    Future<void> performDeletion(BuildContext dialogContext) async {
      try {
        await _messageService.deleteMessage(widget.friend.username, message.id);

        // It's safe to use dialogContext here since we're in a closure that captures it
        if (dialogContext.mounted) {
          Navigator.pop(dialogContext);
        }

        // Check if the widget is still mounted before calling setState
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        // Handle any errors that might occur during deletion
        if (dialogContext.mounted) {
          Navigator.pop(dialogContext);
          ScaffoldMessenger.of(dialogContext).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar el mensaje: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    // Show the confirmation dialog
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Eliminar mensaje'),
            content: Text(
              '¿Estás seguro de que quieres eliminar este mensaje? Esta acción solo afecta a tu dispositivo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Cancelar'),
              ),
              TextButton(
                // Pass the dialogContext to our local function
                onPressed: () => performDeletion(dialogContext),
                child: Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get updated conversation (for typing indicators)
    _conversation = _messageService.conversations[widget.friend.username] ?? _conversation;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            UserAvatar(
              displayName: widget.friend.displayName,
              avatarUrl: widget.friend.avatarUrl,
              status: widget.friend.status,
              size: 32,
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.friend.displayName,
                  style: TextStyle(fontSize: 16),
                ),
                _conversation.isTyping
                    ? Text(
                        'Escribiendo...',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      )
                    : Container(),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(Icons.delete_forever, color: Colors.red),
              onPressed: _removeAllMessages,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: _buildMessageList(),
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_conversation.messages.isEmpty) {
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
              'Envía un mensaje para iniciar la conversación',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Sort messages by timestamp (newest at the bottom)
    final sortedMessages = List<MessageModel>.from(_conversation.messages)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.builder(
      // For chat UI, we want the most recent messages at the bottom
      reverse: true,
      controller: _scrollController,
      itemCount: sortedMessages.length,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final message = sortedMessages[index];
        final isFromMe = message.senderId == _authService.user!.username;
        final isHighlighted = message.id == _highlightedMessageId;
        
        return _buildMessageBubble(message, isFromMe, isHighlighted);
      },
    );
  }
  
  Widget _buildMessageBubble(
    MessageModel message, 
    bool isFromMe, 
    bool isHighlighted
  ) {
    final isOffline = message.isOffline;
    final hasError = message.error;
    
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment:
              isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isFromMe)
              UserAvatar(
                displayName: widget.friend.displayName,
                avatarUrl: widget.friend.avatarUrl,
                size: 28,
              ),
              
            SizedBox(width: 8),
            
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? Colors.yellow[100]
                      : isFromMe
                          ? hasError 
                              ? Colors.amber[100]
                              : AppColors.primary.withAlpha(230)
                          : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: 
                      isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isFromMe && !hasError 
                            ? Colors.white 
                            : Colors.black,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: isFromMe && !hasError 
                                ? Colors.white.withAlpha(179) 
                                : Colors.black54,
                          ),
                        ),
                        SizedBox(width: 4),
                        if (isFromMe)
                          hasError
                              ? Icon(Icons.error_outline, size: 12, color: Colors.red)
                              : message.delivered
                                  ? Icon(Icons.done_all, size: 12, 
                                      color: message.read 
                                          ? Colors.blue 
                                          : Colors.white.withAlpha(179))
                                  : Icon(Icons.done, size: 12, 
                                      color: Colors.white.withAlpha(179)),
                      ],
                    ),
                    if (hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          message.errorMessage ?? 'Error al enviar',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            SizedBox(width: 8),
            
            if (isFromMe)
              SizedBox(width: 28), // To align with avatar on the left
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Message input
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onTap: _scrollToBottom,
            ),
          ),
          // Send button
          IconButton(
            icon: _isSending
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  )
                : Icon(Icons.send),
            color: AppColors.primary,
            onPressed: _isSending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _removeAllMessages() {
    // Implement the logic to remove all messages from the conversation
    setState(() {
      _conversation.messages.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All messages removed'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
