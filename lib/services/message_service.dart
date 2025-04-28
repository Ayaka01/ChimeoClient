import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
import '../repositories/message_repository.dart';

class MessageService with ChangeNotifier {
  AuthService _authService;
  LocalStorageService _storageService;
  MessageRepository _messageRepository;

  WebSocketChannel? _wsChannel;

  final StreamController<MessageModel> _messageController =
      StreamController<MessageModel>.broadcast();
  final StreamController<String> _deliveryController =
      StreamController<String>.broadcast();

  Map<String, ConversationModel> _conversations = {};
  Timer? _reconnectTimer;
  Timer? _connectionMonitorTimer;
  bool _connected = false;
  bool _isOnline = true;

  List<Map<String, dynamic>> _offlineQueue = [];

  final _uuid = Uuid();

  final ErrorHandler _errorHandler = ErrorHandler();
  final Logger _logger = Logger();

  // Getters
  Stream<MessageModel> get messagesStream => _messageController.stream;
  Stream<String> get deliveryStream => _deliveryController.stream;
  Map<String, ConversationModel> get conversations => _conversations;
  bool get isConnected => _connected;
  bool get isOnline => _isOnline;

  // Constructor
  MessageService(
    this._authService,
    this._storageService,
    this._messageRepository,
  ) {
    _loadSavedConversations();

    _loadOfflineQueue();

    _setupConnectivityMonitoring();

    if (_authService.isAuthenticated) {
      connectToWebSocket();
    }
  }

  // Monitor connectivity changes
  void _setupConnectivityMonitoring() async {
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _isOnline = result != ConnectivityResult.none;

      if (_isOnline) {
        _logger.i(
          'Device is online, reconnecting and sending queued messages...',
          tag: 'MessageService',
        );
        connectToWebSocket();
        _processOfflineQueue();
      } else {
        _logger.i(
          'Device is offline, will queue messages',
          tag: 'MessageService',
        );
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
    MessageRepository messageRepository,
  ) {
    _authService = authService;
    _storageService = storageService;
    _messageRepository = messageRepository;
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
      _logger.e(
        'Error loading saved conversations',
        error: e,
        tag: 'MessageService',
      );
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

    _logger.i(
      'Processing ${_offlineQueue.length} queued messages',
      tag: 'MessageService',
    );

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
    if (_authService.user == null || _authService.token == null || !_isOnline)
      return;
    if (_connected || _reconnectTimer != null) return;

    _logger.i('Attempting to connect to WebSocket...', tag: 'MessageService');

    try {
      final wsUrl =
          '${ApiConfig.wsUrl}${ApiConfig.messagesPath}/ws/${_authService.user!.username}';
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
        json.encode({'type': 'authenticate', 'token': _authService.token}),
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
      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      _logger.i('Connected to WebSocket server', tag: 'MessageService');

      // Process offline queue and fetch pending messages without awaiting
      _logger.i(
        'Processing offline queue & fetching pending messages concurrently...',
        tag: 'MessageService',
      );
      _processOfflineQueue();
      getPendingMessages();
    } catch (e) {
      _logger.e('WebSocket connection error', error: e, tag: 'MessageService');
      _handleDisconnect();
    }
  }

  // Handle WebSocket disconnection
  void _handleDisconnect() {
    _logger.w('WebSocket disconnected.', tag: 'MessageService');
    _connected = false;
    _wsChannel = null; // Clear the channel
    _connectionMonitorTimer?.cancel(); // Stop heartbeat
    notifyListeners();

    // Only try to reconnect if online and not already trying
    if (_isOnline && _reconnectTimer == null) {
      _logger.i(
        'Scheduling WebSocket reconnection in 5 seconds...',
        tag: 'MessageService',
      );
      _reconnectTimer = Timer(Duration(seconds: 5), () {
        _reconnectTimer = null; // Clear timer before attempting connect
        connectToWebSocket();
      });
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
      messageExists = _conversations[conversationId]!.messages.any(
        (m) => m.id == message.id || (m.isOffline && m.text == message.text),
      );

      // If it was an optimistic update, remove the temporary message
      if (messageExists) {
        _conversations[conversationId]!.messages.removeWhere(
          (m) => m.isOffline && m.text == message.text,
        );
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

  // TODO: MOVE TO REPOSITORY
  Future<MessageModel?> sendMessage(String recipientId, String text) async {
    final tempId = 'temp_${_uuid.v4()}';

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

    if (!_isOnline) {
      _logger.i(
        'Device offline, queueing message to $recipientId',
        tag: 'MessageService',
      );

      _offlineQueue.add({
        'type': 'message',
        'recipient': recipientId,
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
        'temp_id': tempId,
      });

      await _saveOfflineQueue();

      return tempMessage;
    }

    return await _sendMessageToServer(recipientId, text, tempId);
  }

  // Send message to server
  Future<MessageModel?> _sendMessageToServer(
    String recipientId,
    String text,
    String tempId,
  ) async {
    if (_authService.token == null) {
      _logger.w(
        'Attempted to send message without auth token',
        tag: 'MessageService',
      );
      return null;
    }

    final result = await _messageRepository.sendMessageViaHttp(
      recipientId,
      text,
      _authService.token!,
    );

    if (result.isSuccess) {
      final sentMessage = result.value;
      String conversationId = sentMessage.recipientId; // Assume we are the sender
      if (_conversations.containsKey(conversationId)) {
        _conversations[conversationId]!.messages.removeWhere((m) => m.id == tempId);
        _conversations[conversationId]!.addMessage(sentMessage);
        
        notifyListeners();
        await _saveConversations();
      } else {
         _logger.w('Conversation not found after sending message', tag: 'MessageService');
         _messageController.add(sentMessage);
      }
      return sentMessage;
    } else {
      _logger.e(
        'Failed to send message via HTTP',
        error: result.error,
        tag: 'MessageService',
      );
      String conversationId = recipientId;
      if (_conversations.containsKey(conversationId)) {
        final messageIndex = _conversations[conversationId]!.messages.indexWhere((m) => m.id == tempId);
        if (messageIndex != -1) {
          _conversations[conversationId]!.messages[messageIndex] = 
              _conversations[conversationId]!.messages[messageIndex].copyWith(
                error: true, 
                errorMessage: result.error.toString() // Store error message
              );
           notifyListeners();
           await _saveConversations();
        }
      }
      return null;
    }
  }

  Future<void> markMessageAsDelivered(String messageId) async {
    if (_authService.token == null) {
      _logger.w(
        'Attempted to mark message delivered without auth token',
        tag: 'MessageService',
      );
      return;
    }
    final result = await _messageRepository.markMessageAsDelivered(
      messageId,
      _authService.token!,
    );

    if (result.isSuccess) {
      _logger.i('Message $messageId marked as delivered via HTTP', tag: 'MessageService');
      // Find conversation and message to update locally (optional, WS should confirm)
    } else {
      _logger.e(
        'Failed to mark message $messageId as delivered via HTTP',
        error: result.error,
        tag: 'MessageService',
      );
    }
  }

  // Method to get pending messages (uses repository)
  Future<void> getPendingMessages() async {
    if (_authService.token == null) {
      _logger.w(
        'Attempted to get pending messages without auth token',
        tag: 'MessageService',
      );
      return;
    }
    final result = await _messageRepository.getPendingMessages(_authService.token!);

    if (result.isSuccess) {
      final pendingMessages = result.value;
      _logger.i(
        'Fetched ${pendingMessages.length} pending messages',
        tag: 'MessageService',
      );
      for (final message in pendingMessages) {
        // Process each pending message, likely adding it via _handleNewMessage
        _handleNewMessage(message); 
      }
    } else {
      _logger.e(
        'Failed to get pending messages',
        error: result.error,
        tag: 'MessageService',
      );
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
      // Update friend info if it has changed
      final currentConversation = _conversations[friend.username]!;

      if (currentConversation.friendName != friend.displayName) {
        _conversations[friend.username] = currentConversation.copyWith(
          friendName: friend.displayName,
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
    notifyListeners();
  }

  // Clean up
  @override
  void dispose() {
    _wsChannel?.sink.close();
    _messageController.close();
    _deliveryController.close();
    _reconnectTimer?.cancel();
    _connectionMonitorTimer?.cancel();

    super.dispose();
  }

  // Clear all locally stored messages for a specific conversation
  Future<void> clearLocalMessagesForConversation(String friendUsername) async {
    if (_conversations.containsKey(friendUsername)) {
      final currentConversation = _conversations[friendUsername]!;
      // Create a new conversation instance with messages cleared
      // Assuming ConversationModel has a copyWith method
      _conversations[friendUsername] = currentConversation.copyWith(
        messages: [],
      );

      // Persist the change
      await _saveConversations();

      // Notify listeners (like ChatScreen) to rebuild
      notifyListeners();
      _logger.i(
        'Cleared local messages for conversation with $friendUsername',
        tag: 'MessageService',
      );
    } else {
      _logger.w(
        'Attempted to clear messages for non-existent conversation: $friendUsername',
        tag: 'MessageService',
      );
    }
  }
}
