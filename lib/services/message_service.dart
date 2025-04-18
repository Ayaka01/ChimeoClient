import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/conversation_model.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'local_storage_service.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

class MessageService with ChangeNotifier {
  AuthService _authService;
  LocalStorageService _storageService;
  WebSocketChannel? _wsChannel;
  final StreamController<MessageModel> _messageController =
      StreamController<MessageModel>.broadcast();
  final StreamController<String> _deliveryController =
      StreamController<String>.broadcast();
  // New controller for typing indicators
  final StreamController<Map<String, dynamic>> _typingController =
      StreamController<Map<String, dynamic>>.broadcast();
  Map<String, ConversationModel> _conversations = {};
  Timer? _reconnectTimer;
  Timer? _connectionMonitorTimer;
  bool _connected = false;
  bool _isOnline = true;
  // Queue for storing messages when offline
  List<Map<String, dynamic>> _offlineQueue = [];
  // Map to track typing indicator timers
  final Map<String, Timer> _typingTimers = {};
  // UUID generator for optimistic updates
  final _uuid = Uuid();
  final ErrorHandler _errorHandler = ErrorHandler();
  final Logger _logger = Logger();

  // Getters
  Stream<MessageModel> get messagesStream => _messageController.stream;
  Stream<String> get deliveryStream => _deliveryController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Map<String, ConversationModel> get conversations => _conversations;
  bool get isConnected => _connected;
  bool get isOnline => _isOnline;

  // Constructor
  MessageService(this._authService, this._storageService) {
    // Initialize by loading saved conversations
    _loadSavedConversations();
    
    // Load offline queue
    _loadOfflineQueue();

    // Setup connectivity monitoring
    _setupConnectivityMonitoring();

    // Connect to WebSocket if authenticated
    if (_authService.isAuthenticated) {
      connectToWebSocket();
    }
    
    // Listen to typing indicators
    _typingController.stream.listen((data) {
      final username = data['username'] as String;
      final isTyping = data['isTyping'] as bool;
      
      if (_conversations.containsKey(username)) {
        final conversation = _conversations[username]!;
        _conversations[username] = conversation.copyWith(
          isTyping: isTyping,
          typingTimestamp: isTyping ? DateTime.now() : null,
        );
        
        // Save to storage
        _saveConversations();
        notifyListeners();
      }
    });
  }

  // Monitor connectivity changes
  void _setupConnectivityMonitoring() async {
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _isOnline = result != ConnectivityResult.none;
      
      if (_isOnline) {
        _logger.i('Device is online, reconnecting and sending queued messages...', tag: 'MessageService');
        connectToWebSocket();
        _processOfflineQueue();
      } else {
        _logger.i('Device is offline, will queue messages', tag: 'MessageService');
        _wsChannel?.sink.close();
        _connected = false;
        notifyListeners();
      }
    });
    
    // Check initial connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    _isOnline = connectivityResult != ConnectivityResult.none;
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
        
        // Reset typing indicators on app start
        _conversations.forEach((key, conversation) {
          if (conversation.isTyping) {
            _conversations[key] = conversation.copyWith(isTyping: false);
          }
        });
        
        notifyListeners();
      }
    } catch (e) {
      _logger.e('Error loading saved conversations', error: e, tag: 'MessageService');
    }
  }
  
  // Load offline message queue
  Future<void> _loadOfflineQueue() async {
    try {
      final queue = await _storageService.getOfflineQueue();
      if (queue != null) {
        _offlineQueue = queue;
      }
    } catch (e) {
      _logger.e('Error loading offline queue', error: e, tag: 'MessageService');
    }
  }
  
  // Save offline queue
  Future<void> _saveOfflineQueue() async {
    try {
      await _storageService.saveOfflineQueue(_offlineQueue);
    } catch (e) {
      _logger.e('Error saving offline queue', error: e, tag: 'MessageService');
    }
  }

  // Process offline queue when online
  Future<void> _processOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;
    
    _logger.i('Processing ${_offlineQueue.length} queued messages', tag: 'MessageService');
    
    // Make a copy to avoid modification during iteration
    final queueCopy = List<Map<String, dynamic>>.from(_offlineQueue);
    
    for (final item in queueCopy) {
      if (item['type'] == 'message') {
        final recipientId = item['recipient'];
        final text = item['text'];
        final tempId = item['temp_id'];
        
        // Try to send the message
        final message = await _sendMessageToServer(recipientId, text, tempId);
        
        if (message != null) {
          _offlineQueue.remove(item);
        }
      }
    }
    
    // Save the updated queue
    await _saveOfflineQueue();
  }

  // Save conversations to local storage
  Future<void> _saveConversations() async {
    try {
      await _storageService.saveConversations(_conversations);
    } catch (e) {
      _logger.e('Error saving conversations', error: e, tag: 'MessageService');
    }
  }

  // Connect to WebSocket
  void connectToWebSocket() {
    if (_authService.user == null || _authService.token == null || !_isOnline) return;

    try {
      final wsUrl = '${ApiConfig.wsUrl}${ApiConfig.messagesPath}/ws/${_authService.user!.username}';
      
      // Add authentication token to the WebSocket connection
      final uri = Uri.parse(wsUrl);
      final uriWithAuth = uri.replace(
        queryParameters: {'token': _authService.token},
      );

      _wsChannel = WebSocketChannel.connect(uriWithAuth);

      _wsChannel!.stream.listen(
        (dynamic data) {
          _logger.i('Received WebSocket message: $data', tag: 'MessageService');
          final jsonData = json.decode(data);

          if (jsonData['type'] == 'new_message') {
            // Handle new message
            final message = MessageModel.fromJson(jsonData['data']);
            _handleNewMessage(message);
          } else if (jsonData['type'] == 'message_delivered') {
            // Handle message delivery confirmation
            final messageId = jsonData['data']['message_id'];
            _handleMessageDelivered(messageId);
          } else if (jsonData['type'] == 'typing_indicator') {
            // Handle typing indicator
            final username = jsonData['data']['username'];
            final isTyping = jsonData['data']['is_typing'];
            
            _typingController.add({
              'username': username,
              'isTyping': isTyping,
            });
          } else if (jsonData['type'] == 'pong') {
            // Heartbeat response, connection is alive
            _logger.d('Heartbeat response received', tag: 'MessageService');
          }
        },
        onDone: _handleDisconnect,
        onError: (error) {
          _logger.e('WebSocket error', error: error, tag: 'MessageService');
          _handleDisconnect();
        },
      );

      // Send authentication message
      _wsChannel?.sink.add(
        json.encode({
          'type': 'authenticate',
          'token': _authService.token,
        }),
      );

      // Setup heartbeat to detect connection issues early
      _connectionMonitorTimer?.cancel();
      _connectionMonitorTimer = Timer.periodic(Duration(seconds: 30), (timer) {
        if (_connected) {
          _wsChannel?.sink.add(json.encode({'type': 'ping'}));
        } else {
          timer.cancel();
        }
      });

      _connected = true;
      notifyListeners();

      _logger.i('Connected to WebSocket server', tag: 'MessageService');
      
      // Process any queued offline messages
      _processOfflineQueue();
    } catch (e) {
      _logger.e('WebSocket connection error', error: e, tag: 'MessageService');
      _handleDisconnect();
    }
  }

  // Handle WebSocket disconnection
  void _handleDisconnect() {
    _connected = false;
    notifyListeners();

    // Only try to reconnect if online
    if (_isOnline) {
      // Try to reconnect after 5 seconds
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: 5), connectToWebSocket);
    }
  }

  // Handle incoming message
  void _handleNewMessage(MessageModel message) {
    // Check if we already have this message (for optimistic updates)
    bool messageExists = false;
    String conversationId = message.senderId;
    
    if (message.senderId == _authService.user!.username) {
      conversationId = message.recipientId;
    }
    
    if (_conversations.containsKey(conversationId)) {
      messageExists = _conversations[conversationId]!.messages.any((m) => 
        m.id == message.id || (m.isOffline && m.text == message.text));
      
      // If it was an optimistic update, remove the temporary message
      if (messageExists) {
        _conversations[conversationId]!.messages.removeWhere((m) => 
          m.isOffline && m.text == message.text);
      }
    }
    
    // Add message to stream if it's new
    if (!messageExists) {
      _messageController.add(message);
    }

    // Find the conversation or create a new one
    if (!_conversations.containsKey(conversationId)) {
      // No existing conversation, create a new one
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
      
      // Reset typing indicator when a message is received
      _typingController.add({
        'username': message.senderId,
        'isTyping': false,
      });
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
  
  // Send typing indicator
  void sendTypingIndicator(String recipientId, bool isTyping) {
    if (!_isOnline || !_connected) return;
    
    try {
      // Cancel existing timer if any
      _typingTimers[recipientId]?.cancel();
      
      // Send typing indicator via WebSocket
      _wsChannel?.sink.add(json.encode({
        'type': 'typing_indicator', 
        'data': {
          'recipient': recipientId,
          'is_typing': isTyping
        }
      }));
      
      // If typing, set a timer to automatically turn it off after 3 seconds
      if (isTyping) {
        _typingTimers[recipientId] = Timer(Duration(seconds: 3), () {
          sendTypingIndicator(recipientId, false);
        });
      }
    } catch (e) {
      _logger.e('Error sending typing indicator', error: e, tag: 'MessageService');
    }
  }

  // Send a message with optimistic updates
  Future<MessageModel?> sendMessage(String recipientId, String text) async {
    // Generate a temporary ID for optimistic update
    final tempId = 'temp_${_uuid.v4()}';
    
    // Create temporary message for optimistic UI
    final tempMessage = MessageModel(
      id: tempId,
      senderId: _authService.user!.username,
      recipientId: recipientId,
      text: text,
      timestamp: DateTime.now(),
      delivered: false,
      read: false,
      isOffline: !_isOnline,
    );
    
    // Add to local conversation immediately (optimistic)
    if (!_conversations.containsKey(recipientId)) {
      _conversations[recipientId] = ConversationModel(
        friendUsername: recipientId,
        friendName: 'User', // Placeholder
        messages: [],
      );
    }
    
    _conversations[recipientId]!.addMessage(tempMessage);
    notifyListeners();
    await _saveConversations();
    
    // Clear any typing indicator
    sendTypingIndicator(recipientId, false);
    
    // If offline, queue the message and return the temp message
    if (!_isOnline) {
      _logger.i('Device offline, queueing message to $recipientId', tag: 'MessageService');
      
      // Add to the offline queue
      _offlineQueue.add({
        'type': 'message',
        'recipient': recipientId, 
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
        'temp_id': tempId,
      });
      
      // Save the queue
      await _saveOfflineQueue();
      
      return tempMessage;
    }

    // Try to send to server
    return await _sendMessageToServer(recipientId, text, tempId);
  }
  
  // Send message to server
  Future<MessageModel?> _sendMessageToServer(String recipientId, String text, String tempId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesPath}/'),
        headers: {
          'Authorization': 'Bearer ${_authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'recipient_username': recipientId,
          'text': text
        }),
      );

      if (response.statusCode == 200) {
        // Get the real message back from the server
        final MessageModel serverMessage = MessageModel.fromJson(json.decode(response.body));
        
        // Replace the temporary message with the server one
        if (_conversations.containsKey(recipientId)) {
          _conversations[recipientId]!.replaceMessage(tempId, serverMessage);
          notifyListeners();
          await _saveConversations();
        }
        
        return serverMessage;
      } else {
        // Mark the message as failed
        if (_conversations.containsKey(recipientId)) {
          final messageIndex = _conversations[recipientId]!.messages.indexWhere((m) => m.id == tempId);
          if (messageIndex >= 0) {
            final updatedMessage = _conversations[recipientId]!.messages[messageIndex].copyWith(error: true);
            _conversations[recipientId]!.messages[messageIndex] = updatedMessage;
            notifyListeners();
            await _saveConversations();
          }
        }
        
        _logger.e('HTTP Error sending message: ${response.statusCode}', tag: 'MessageService');
        return null;
      }
    } catch (e) {
      // Mark the message as failed
      if (_conversations.containsKey(recipientId)) {
        final messageIndex = _conversations[recipientId]!.messages.indexWhere((m) => m.id == tempId);
        if (messageIndex >= 0) {
          final updatedMessage = _conversations[recipientId]!.messages[messageIndex].copyWith(error: true);
          _conversations[recipientId]!.messages[messageIndex] = updatedMessage;
          notifyListeners();
          await _saveConversations();
        }
      }
      
      _logger.e('Error sending message to server', error: e, tag: 'MessageService');
      return null;
    }
  }

  // Search across all conversations
  Map<String, List<MessageModel>> searchMessages(String query) {
    if (query.isEmpty) return {};
    
    final result = <String, List<MessageModel>>{};
    final queryLower = query.toLowerCase();
    
    try {
      // Search through in-memory conversations instead of loading from storage
      _conversations.forEach((conversationId, conversation) {
        final matchingMessages = conversation.messages
            .where((msg) => msg.text.toLowerCase().contains(queryLower))
            .toList();
        
        if (matchingMessages.isNotEmpty) {
          result[conversationId] = matchingMessages;
        }
      });
      
      return result;
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace: stackTrace);
      return {};
    }
  }

  // Mark a message as delivered
  Future<bool> markMessageAsDelivered(String messageId) async {
    try {
      // Mark on server
      final response = await http.post(
        Uri.parse('$ApiConfig.baseUrl${ApiConfig.messagesPath}/delivered/$messageId'),
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
      _logger.e('Error marking message as delivered', error: e, tag: 'MessageService');
      return false;
    }
  }

  // Get all pending messages from server
  Future<List<MessageModel>> getPendingMessages() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesPath}/pending'),
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
      _logger.e('Error getting pending messages', error: e, tag: 'MessageService');
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
        friendAvatarUrl: friend.avatarUrl,
      );

      // Save to local storage
      _saveConversations();
      notifyListeners();
    } else {
      // Update friend info if it has changed
      final currentConversation = _conversations[friend.username]!;
      
      if (currentConversation.friendName != friend.displayName || 
          currentConversation.friendAvatarUrl != friend.avatarUrl) {
        
        _conversations[friend.username] = currentConversation.copyWith(
          friendName: friend.displayName,
          friendAvatarUrl: friend.avatarUrl,
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

  // Clear all conversations from local storage
  Future<bool> clearAllLocalConversations() async {
    try {
      _conversations = {};
      await _storageService.clearAllConversations();
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace: stackTrace);
      return false;
    }
  }

  // Disconnect WebSocket and clear timers
  void disconnectWebSocket() {
    _wsChannel?.sink.close();
    _wsChannel = null;
    _connected = false;
    _reconnectTimer?.cancel();
    _connectionMonitorTimer?.cancel();
    notifyListeners();
  }

  // Clear in-memory data
  void clearData() {
    _conversations.clear();
    _offlineQueue.clear();
    _typingTimers.forEach((key, timer) => timer.cancel());
    _typingTimers.clear();
    notifyListeners();
  }

  // Clean up
  @override
  void dispose() {
    _wsChannel?.sink.close();
    _messageController.close();
    _deliveryController.close();
    _typingController.close();
    _reconnectTimer?.cancel();
    _connectionMonitorTimer?.cancel();
    
    // Cancel all typing timers
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    
    super.dispose();
  }
}
