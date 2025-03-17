// lib/services/message_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/conversation_model.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'local_storage_service.dart';

class MessageService with ChangeNotifier {
  AuthService _authService;
  LocalStorageService _storageService;
  WebSocketChannel? _wsChannel;
  final StreamController<MessageModel> _messageController =
      StreamController<MessageModel>.broadcast();
  final StreamController<String> _deliveryController =
      StreamController<String>.broadcast();
  Map<String, ConversationModel> _conversations = {};
  Timer? _reconnectTimer;
  bool _connected = false;

  // Getters
  Stream<MessageModel> get messagesStream => _messageController.stream;
  Stream<String> get deliveryStream => _deliveryController.stream;
  Map<String, ConversationModel> get conversations => _conversations;
  bool get isConnected => _connected;

  // Constructor
  MessageService(this._authService, this._storageService) {
    // Initialize by loading saved conversations
    _loadSavedConversations();

    // Connect to WebSocket if authenticated
    if (_authService.isAuthenticated) {
      connectToWebSocket();
    }
  }

  // Update services (used by ProxyProvider)
  void updateServices(
    AuthService authService,
    LocalStorageService storageService,
  ) {
    _authService = authService;
    _storageService = storageService;
  }

  // Load saved conversations from local storage
  Future<void> _loadSavedConversations() async {
    try {
      final savedConversations = await _storageService.getConversations();
      if (savedConversations != null) {
        _conversations = savedConversations;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading saved conversations: $e');
    }
  }

  // Save conversations to local storage
  Future<void> _saveConversations() async {
    try {
      await _storageService.saveConversations(_conversations);
    } catch (e) {
      print('Error saving conversations: $e');
    }
  }

  // Connect to WebSocket
  void connectToWebSocket() {
    if (_authService.user == null || _authService.token == null) return;

    try {
      final wsUrl =
          '${ApiConfig.wsUrl}/messages/ws/${_authService.user!.username}';

      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _wsChannel!.stream.listen(
        (dynamic data) {
          final jsonData = json.decode(data);

          if (jsonData['type'] == 'new_message') {
            // Handle new message
            final message = MessageModel.fromJson(jsonData['data']);
            _handleNewMessage(message);
          } else if (jsonData['type'] == 'message_delivered') {
            // Handle message delivery confirmation
            final messageId = jsonData['data']['message_id'];
            _handleMessageDelivered(messageId);
          }
        },
        onDone: _handleDisconnect,
        onError: (error) {
          print('WebSocket error: $error');
          _handleDisconnect();
        },
      );

      // Send heartbeat every 30 seconds to keep connection alive
      Timer.periodic(Duration(seconds: 30), (timer) {
        if (_connected) {
          _wsChannel?.sink.add(json.encode({'type': 'ping'}));
        } else {
          timer.cancel();
        }
      });

      _connected = true;
      notifyListeners();

      print('Connected to WebSocket server');
    } catch (e) {
      print('WebSocket connection error: $e');
      _handleDisconnect();
    }
  }

  // Handle WebSocket disconnection
  void _handleDisconnect() {
    _connected = false;
    notifyListeners();

    // Try to reconnect after 5 seconds
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: 5), connectToWebSocket);
  }

  // Handle incoming message
  void _handleNewMessage(MessageModel message) {
    // Add message to stream
    _messageController.add(message);

    // Find the conversation or create a new one
    String conversationId = message.senderId;
    if (message.senderId == _authService.user!.username) {
      conversationId = message.recipientId;
    }

    if (!_conversations.containsKey(conversationId)) {
      // No existing conversation, create a new one
      // We'll need to fetch the user's name elsewhere
      _conversations[conversationId] = ConversationModel(
        friendUsername: conversationId,
        friendName: 'User', // Placeholder, should be updated later
        messages: [],
      );
    }

    // Add message to conversation
    _conversations[conversationId]!.addMessage(message);

    // Mark as delivered if we received it
    if (message.senderId != _authService.user!.username) {
      markMessageAsDelivered(message.id);
    }

    // Save to local storage
    _saveConversations();

    // Notify listeners
    notifyListeners();
  }

  // Handle message delivery confirmation
  void _handleMessageDelivered(String messageId) {
    // Notify through delivery stream
    _deliveryController.add(messageId);

    // Update message status in all conversations
    _conversations.forEach((friendId, conversation) {
      for (var message in conversation.messages) {
        if (message.id == messageId) {
          message.delivered = true;
          break;
        }
      }
    });

    // Save to local storage
    _saveConversations();

    // Notify listeners
    notifyListeners();
  }

  // Send a message
  Future<MessageModel?> sendMessage(String recipientId, String text) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/messages/'),
        headers: {
          'Authorization': 'Bearer ${_authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'recipient_id': recipientId, 'text': text}),
      );

      if (response.statusCode == 200) {
        final message = MessageModel.fromJson(json.decode(response.body));

        // Add to local conversation
        if (!_conversations.containsKey(recipientId)) {
          // Create new conversation if needed
          _conversations[recipientId] = ConversationModel(
            friendUsername: recipientId,
            friendName: 'User', // Placeholder, should be updated
            messages: [],
          );
        }

        _conversations[recipientId]!.addMessage(message);

        // Save to local storage
        _saveConversations();

        // Notify listeners
        notifyListeners();

        return message;
      }

      return null;
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  // Mark a message as delivered
  Future<bool> markMessageAsDelivered(String messageId) async {
    try {
      // Mark on server
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/messages/delivered/$messageId'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        // Also notify through WebSocket for real-time updates
        _wsChannel?.sink.add(
          json.encode({'type': 'message_delivered', 'message_id': messageId}),
        );

        return true;
      }

      return false;
    } catch (e) {
      print('Error marking message as delivered: $e');
      return false;
    }
  }

  // Get all pending messages from server
  Future<List<MessageModel>> getPendingMessages() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/messages/pending'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final messages =
            data.map((json) => MessageModel.fromJson(json)).toList();

        // Process each message
        for (var message in messages) {
          _handleNewMessage(message);

          // Mark as delivered
          markMessageAsDelivered(message.id);
        }

        return messages;
      }

      return [];
    } catch (e) {
      print('Error getting pending messages: $e');
      return [];
    }
  }

  // Fetch or create a conversation with a friend
  ConversationModel getOrCreateConversation(UserModel friend) {
    if (!_conversations.containsKey(friend.username)) {
      _conversations[friend.username] = ConversationModel(
        friendUsername: friend.username,
        friendName: friend.displayName,
        messages: [],
      );

      // Save to local storage
      _saveConversations();
      notifyListeners();
    } else {
      // Update friend name if it has changed
      if (_conversations[friend.username]!.friendName != friend.displayName) {
        _conversations[friend.username] = ConversationModel(
          friendUsername: friend.username,
          friendName: friend.displayName,
          messages: _conversations[friend.username]!.messages,
          lastMessageTime: _conversations[friend.username]!.lastMessageTime,
        );

        // Save to local storage
        _saveConversations();
        notifyListeners();
      }
    }

    return _conversations[friend.username]!;
  }

  // Delete a conversation
  Future<bool> deleteConversation(String friendId) async {
    if (_conversations.containsKey(friendId)) {
      _conversations.remove(friendId);

      // Save to local storage
      await _saveConversations();
      notifyListeners();
      return true;
    }
    return false;
  }

  // Delete a specific message
  Future<bool> deleteMessage(String friendId, String messageId) async {
    if (_conversations.containsKey(friendId)) {
      _conversations[friendId]!.messages.removeWhere((m) => m.id == messageId);

      // Save to local storage
      await _saveConversations();
      notifyListeners();
      return true;
    }
    return false;
  }

  // Clean up
  @override
  void dispose() {
    _wsChannel?.sink.close();
    _messageController.close();
    _deliveryController.close();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}
