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
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late MessageService _messageService;
  late AuthService _authService;
  late UserService _userService;
  late ConversationModel _conversation;
  late ScrollController _scrollController;
  bool _isSending = false;
  String? _highlightedMessageId;
  // Store the stream subscriptions
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _deliverySubscription; // Added for delivery stream

  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _authService = context.read<AuthService>();
    _messageService = context.read<MessageService>();
    _userService = context.read<UserService>();

    _conversation = _messageService.getOrCreateConversation(widget.friend);
    
    // Set initial highlighted message if provided
    _highlightedMessageId = widget.highlightMessageId;
    
    // Setup focus node 
    _messageFocusNode.addListener(_onFocusChange);

    // Assign the subscription to the variable
    _messagesSubscription = _messageService.messagesStream.listen((message) {
      // Filter only for this conversation
      final currentUserId = _authService.user!.username; // Get current user ID safely
      final friendUsername = widget.friend.username;

      bool isRelevant = (message.senderId == friendUsername && message.recipientId == currentUserId) ||
                        (message.senderId == currentUserId && message.recipientId == friendUsername);

      if (isRelevant) {
        // Log the message received from the stream
        _logger.d('ChatScreen listener received message update: ID=${message.id}, Delivered=${message.delivered}, Timestamp=${message.timestamp}', tag:'_ChatScreenState');
        
        // Explicitly fetch the latest conversation state within setState
        // to ensure the build uses the most up-to-date info.
        if (mounted) {
          final updatedConversation = _messageService.conversations[friendUsername];
          // Log the conversation state just before setState
          _logger.d('ChatScreen listener: Conversation for $friendUsername has ${updatedConversation?.messages.length ?? 0} messages just before setState.', tag:'_ChatScreenState');
          setState(() {
             // Update the local _conversation variable ONLY if the service has it
             if (updatedConversation != null) {
                _conversation = updatedConversation;
             }
          });
        }

        // If the message is from the friend (incoming), scroll to bottom.
        if (message.senderId == friendUsername && mounted) { 
          _scrollToBottom();
        }
      }
    });

    // Listen for delivery confirmations & store subscription
    _deliverySubscription = _messageService.deliveryStream.listen((messageId) {
      // Add mounted check here too for safety
      if (mounted) { 
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

  }
  
  void _onFocusChange() {
    if (_messageFocusNode.hasFocus) {
      // Scroll to bottom when focusing
      _scrollToBottom();
    }
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
        // Scroll to offset 0 (visual bottom when reversed)
        0, 
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      // If scroll controller doesn't have clients yet, schedule a scroll after the next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            // Scroll to offset 0 (visual bottom when reversed)
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
    _messageController.dispose();
    _messageFocusNode.removeListener(_onFocusChange);
    _messageFocusNode.dispose();
    _scrollController.dispose();
    // Cancel the subscriptions!
    _messagesSubscription?.cancel();
    _deliverySubscription?.cancel(); // Cancel delivery subscription
    
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

      final message = await _messageService.sendMessage(
        widget.friend.username,
        text,
      );

      // Check if widget is still mounted before using context
      if (!mounted) return;

      setState(() {
        _isSending = false;
      });
      
      // Scroll to bottom AFTER successful send/update 
      // (message will be non-null on success)
      _scrollToBottom();
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
      // Add rounded corners to the top of the sheet
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _buildMessageOptionsContent(message), // Use extracted builder
    );
  }

  // Builds the content for the message options bottom sheet
  Widget _buildMessageOptionsContent(MessageModel message) {
    // Get current user ID for conditional options
    final currentUserId = _authService.user?.username;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Add some vertical padding
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Add a drag handle (optional but common UI pattern)
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Example of a conditional action (e.g., Add All - maybe implement later)
          /* 
          ListTile(
            leading: Icon(Icons.playlist_add_outlined), // Use outlined icon
            title: Text('Add all messages'), 
            dense: true,
            onTap: () {
              Navigator.pop(context);
              // Implement the logic to add all messages
            },
          ),
          */

          // Copy Message Action
          ListTile(
            leading: Icon(Icons.copy_outlined, color: AppColors.primary), // Outlined icon
            title: Text('Copiar mensaje'),
            dense: true, // Make tiles compact
            onTap: () {
              Navigator.pop(context);
              _copyMessageToClipboard(message); 
            },
          ),
          
          // Delete Message Action (Only show if user sent the message)
          if (message.senderId == currentUserId) 
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red), // Outlined icon
              title: Text('Eliminar mensaje'),
              dense: true,
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message); 
              },
            ),
            
          // Add a small bottom padding/spacer
          SizedBox(height: 8),
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

  // Add confirmation dialog for removing all messages
  Future<void> _confirmRemoveAllMessages() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Eliminar todos los mensajes'),
          content: Text(
            '¿Estás seguro de que quieres eliminar todos los mensajes de esta conversación? Esta acción solo afecta a tu dispositivo y no se puede deshacer.',
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _removeAllMessagesLocally();
    }
  }

  // Method to actually clear messages locally (called after confirmation)
  void _removeAllMessagesLocally() {
    try {
      final friendUsername = widget.friend.username;
      // Call the service method to clear messages in the service and storage
      _messageService.clearLocalMessagesForConversation(friendUsername);
      
      // Fetch the updated (now empty) conversation object from the service
      final updatedConversation = _messageService.conversations[friendUsername];

      // Call setState to force a rebuild using the updated state
      setState(() {
         // Ensure the local state variable reflects the cleared conversation
         if (updatedConversation != null) {
            _conversation = updatedConversation; 
         } else {
             // Fallback: If the conversation somehow disappeared from the service map,
             // re-fetch/create it to ensure the UI shows an empty state.
             _conversation = _messageService.getOrCreateConversation(widget.friend); 
             _logger.w('Conversation was null after clearing for $friendUsername, re-created.', tag: 'ChatScreen');
         }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Todos los mensajes eliminados localmente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Handle potential errors from the service method if needed
      _logger.e('Error calling clearLocalMessagesForConversation', error: e, tag: 'ChatScreen');
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar mensajes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(Icons.delete_sweep_outlined, color: Colors.red),
              tooltip: 'Eliminar todos los mensajes',
              onPressed: _confirmRemoveAllMessages,
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

  Widget _buildAppBarTitle() {
    final friendDisplayName = _conversation.friendName;
    final friendAvatarUrl = _conversation.friendAvatarUrl;

    return Row(
      children: [
        UserAvatar(
          displayName: friendDisplayName,
          avatarUrl: friendAvatarUrl,
          size: 36,
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              friendDisplayName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Container(), // Keep a container for potential future use or consistent spacing
          ],
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    if (_conversation.messages.isEmpty) {
      return _buildEmptyChatView();
    }

    // Sort messages: oldest first, handle null timestamps
    final sortedMessages = List<MessageModel>.from(_conversation.messages)
      ..sort((a, b) {
        final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

    return ListView.builder(
      reverse: true,
      controller: _scrollController,
      itemCount: sortedMessages.length,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      itemBuilder: (context, index) {
        // REINSTATE manual index calculation - maybe needed with reverse:true updates?
        final messageIndex = sortedMessages.length - 1 - index; 
        final message = sortedMessages[messageIndex]; // Use calculated index
        final isFromMe = message.senderId == _authService.user!.username;
        final isHighlighted = message.id == _highlightedMessageId;

        return _buildMessageBubble(
          message,
          isFromMe,
          isHighlighted,
          key: ValueKey(message.id),
        );
      },
    );
  }

  Widget _buildEmptyChatView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Inicia la conversación',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Los mensajes que envíes aparecerán aquí.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    MessageModel message, 
    bool isFromMe, 
    bool isHighlighted,
    {Key? key}
  ) {
    return Container(
      key: key,
      // Use padding instead of margin for better gesture detection area
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 0), 
      child: Row(
        mainAxisAlignment: isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Show friend avatar on the left for received messages
          if (!isFromMe)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, bottom: 0), // Align with bottom of bubble
              child: UserAvatar(
                displayName: widget.friend.displayName,
                size: 28,
              ),
            ),
            
          // Flexible bubble container
          Flexible(
            child: GestureDetector( // GestureDetector on the bubble itself
              onLongPress: () => _showMessageOptions(message),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: _buildMessageBubbleDecoration(isFromMe, isHighlighted, message.error),
                child: _buildMessageContent(message, isFromMe), // Extracted content
              ),
            ),
          ),
          
          // Spacer for sent messages to align with left avatar
          if (isFromMe)
            SizedBox(width: 28 + 8), // Avatar size + padding
        ],
      ),
    );
  }

  // Builds the decoration for the message bubble
  BoxDecoration _buildMessageBubbleDecoration(bool isFromMe, bool isHighlighted, bool hasError) {
    return BoxDecoration(
      color: isHighlighted
          ? Colors.yellow[100] // Highlight color
          : isFromMe
              ? (hasError ? Colors.red[100] : AppColors.primary) // My message color (or error)
              : Colors.grey[200], // Friend message color
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(isFromMe ? 16 : 0), // Pointy corner
        bottomRight: Radius.circular(isFromMe ? 0 : 16), // Pointy corner
      ),
    );
  }

  // Builds the content inside the message bubble (text + status/time)
  Widget _buildMessageContent(MessageModel message, bool isFromMe) {
    final bool hasError = message.error;
    final Color textColor = isFromMe && !hasError ? Colors.white : Colors.black87;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Text should align left initially
      mainAxisSize: MainAxisSize.min, // Prevent column from taking full width
      children: [
        Text(
          message.text,
          style: TextStyle(color: textColor),
        ),
        SizedBox(height: 4),
        _buildTimestampAndStatus(message, isFromMe), // Extracted row
        // Show error message if applicable
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              message.errorMessage ?? 'Error al enviar',
              style: TextStyle(fontSize: 10, color: Colors.red[700]),
            ),
          ),
      ],
    );
  }

  // Builds the row containing the timestamp and delivery status icon
  Widget _buildTimestampAndStatus(MessageModel message, bool isFromMe) {
    // Log the status being used for the icon
    _logger.d('Building status icon for Msg ID: ${message.id}, isOffline: ${message.isOffline}, Delivered: ${message.delivered}, Error: ${message.error}', tag:'_ChatScreenState:BuildStatus');
      
    final bool hasError = message.error;
    final bool isOffline = message.isOffline;
    final bool isDelivered = message.delivered;

    final Color timeStatusColor = isFromMe && !hasError 
      ? Colors.white.withAlpha(180) // Lighter white for sent messages
      : Colors.black54;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end, // Align this row to the end
      children: [
        Text(
          _formatTime(message.timestamp),
          style: TextStyle(fontSize: 10, color: timeStatusColor),
        ),
        // Add status icon only for messages sent by the current user
        if (isFromMe)
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Icon(
              // --> Updated Logic: Error -> Offline -> Delivered -> Sent <--
              hasError
                  ? Icons.error_outline // 1. Error Icon
                  : isOffline
                      ? Icons.access_time // 2. Offline/Pending Icon (Clock)
                      : isDelivered 
                          ? Icons.done_all  // 3. Delivered Icon (Double Tick)
                          : Icons.done,     // 4. Sent to server, not delivered (Single Tick)
              size: 14,
              // Adjust color based on state
              color: hasError
                  ? Colors.red[700] // Error color
                  : isOffline 
                      ? timeStatusColor.withAlpha(120) // Dimmer color for clock
                      : timeStatusColor, // Default color for Sent and Delivered ticks
            ),
          ),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Slightly more vertical padding
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // Use theme card color
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).round()), // Replaced withOpacity
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea( // Ensure input isn't obscured by notches/nav bars
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end, // Align items to bottom
          children: [
            // Message input
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5, // Allow multi-line input
                decoration: _buildInputDecoration(), // Use extracted decoration
                onTap: _scrollToBottom, // Scroll when tapped
                keyboardType: TextInputType.multiline, // Ensure multiline keyboard
              ),
            ),
            SizedBox(width: 8),
            // Send button
            // Use CircleAvatar for a round button look
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary,
              child: IconButton(
                icon: _isSending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white), // White indicator
                        ),
                      )
                    : Icon(Icons.send, color: Colors.white, size: 20), // White icon
                tooltip: 'Enviar mensaje', // Tooltip
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the InputDecoration for the message input field
  InputDecoration _buildInputDecoration() {
    return InputDecoration(
      hintText: 'Escribe un mensaje...',
      hintStyle: TextStyle(color: Colors.grey[500]), // Slightly lighter hint
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24), // Rounded corners
        borderSide: BorderSide.none, // No border
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none, // No border even when focused (rely on fill color)
      ),
      filled: true,
      fillColor: Colors.grey[100], // Lighter fill color
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10, // Adjust vertical padding
      ),
      isDense: true, // Reduces intrinsic height
    );
  }

  // Format time, handle null timestamp for optimistic messages
  String _formatTime(DateTime? time) {
    if (time == null) {
      return "--:--"; // Placeholder for optimistic messages
    }
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
