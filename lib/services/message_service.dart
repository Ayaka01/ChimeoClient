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

        final message = await _sendMessageToServer(recipientId, text, tempId);

        if (message != null) {
          _offlineQueue.remove(item);
        }
      }
    }

    await _saveOfflineQueue();
  }

  Future<void> _saveConversations() async {
    try {
      await _storageService.saveConversations(_conversations);
    } catch (e) {
      _logger.e('Error saving conversations', error: e, tag: 'MessageService');
    }
  }

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
        _onWebSocketData,
        onDone: _handleDisconnect,
        onError: (error) {
          _logger.e('WebSocket error', error: error, tag: 'MessageService');
          _handleDisconnect();
        },
      );

      // Setup heartbeat
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

      _processOfflineQueue();
      getPendingMessages();
    } catch (e) {
      _logger.e('WebSocket connection error', error: e, tag: 'MessageService');
      _handleDisconnect();
    }
  }

  void _onWebSocketData(dynamic data) {
    _logger.i('Received WebSocket message: $data', tag: 'MessageService');
    try {
      final jsonData = json.decode(data);
      final messageType = jsonData['type'];

      if (messageType == 'new_message') {
        final message = MessageModel.fromJson(jsonData['data']);
        _handleNewMessage(message);
      } else if (messageType == 'message_delivered') {
        final messageId = jsonData['data']['message_id'];
        _handleMessageDelivered(messageId);
      } else if (messageType == 'pong') {
        _logger.d('Heartbeat response received', tag: 'MessageService');
      } else {
        _logger.w('Received unknown WebSocket message type: $messageType', tag: 'MessageService');
      }
    } catch (e) {
      _logger.e('Error processing WebSocket message', error: e, tag: 'MessageService', stackTrace: StackTrace.current);
    }
  }

  void _handleDisconnect() {
    if (!_connected) return;

    _logger.i('Disconnected from WebSocket server', tag: 'MessageService');
    _connected = false;
    _wsChannel = null;
    _connectionMonitorTimer?.cancel();
    notifyListeners();

    if (_isOnline && _reconnectTimer == null) {
      _logger.i('Scheduling WebSocket reconnection...', tag: 'MessageService');
      _reconnectTimer = Timer(Duration(seconds: 5), () {
        _reconnectTimer = null;
        connectToWebSocket();
      });
    }
  }

  void _handleNewMessage(MessageModel message) {
    final friendId = message.senderId == _authService.user?.username
        ? message.recipientId
        : message.senderId;

    _conversations.putIfAbsent(
      friendId,
      () => ConversationModel(
        friendUsername: friendId,
        friendName: friendId,
        messages: [],
      ),
    );

    final conversation = _conversations[friendId]!;

    final existingIndex = conversation.messages.indexWhere((m) => m.id == message.id);
    if (existingIndex == -1) {
      conversation.messages.add(message);
      _logger.i('Handled new message ${message.id}, added to end.', tag:'MessageService');
    } else {
      conversation.messages[existingIndex] = message;
    }

    // Sort messages: oldest first, handle null timestamps (treat as oldest)
    conversation.messages.sort((a, b) {
      final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });

    _messageController.add(message);
    _saveConversations();
    notifyListeners();
  }

  void _handleMessageDelivered(String messageId) {
    bool updated = false;
    for (var conversation in _conversations.values) {
      final messageIndex = conversation.messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        if (!conversation.messages[messageIndex].delivered) {
          conversation.messages[messageIndex].delivered = true;
          _messageController.add(conversation.messages[messageIndex]);
          updated = true;
          break;
        }
      }
    }
    if (updated) {
      _logger.i('Marked message $messageId as delivered', tag: 'MessageService');
      _saveConversations();
      _deliveryController.add(messageId);
      notifyListeners();
    } else {
      _logger.w('Received delivery confirmation for unknown or already delivered message $messageId', tag: 'MessageService');
    }
  }

  Future<void> getPendingMessages() async {
    if (!_authService.isAuthenticated) {
       _logger.w('User not authenticated, skipping getPendingMessages', tag: 'MessageService');
       return;
    }

    try {
      final result = await _messageRepository.getPendingMessages();
      if (result.isSuccess) {
        final messages = result.value;
        if (messages.isNotEmpty) {
          _logger.i('Fetched ${messages.length} pending messages', tag: 'MessageService');
          for (final message in messages) {
            _handleNewMessage(message);
          }
        }
      } else {
        final errorMessage = _errorHandler.handleError(result.error);
        _logger.e(
          'Error fetching pending messages: $errorMessage',
          error: result.error,
          tag: 'MessageService',
        );
      }
    } catch (e) {
      final errorMessage = _errorHandler.handleError(e);
      _logger.e(
        'Exception fetching pending messages: $errorMessage',
        error: e,
        tag: 'MessageService',
      );
    }
  }

  Future<MessageModel?> sendMessage(String recipientId, String text) async {
    if (!_authService.isAuthenticated || _authService.user == null) {
      throw Exception('User not authenticated');
    }

    final tempId = _uuid.v4();
    final optimisticMessage = MessageModel(
      id: tempId,
      senderId: _authService.user!.username,
      recipientId: recipientId,
      text: text,
      delivered: false,
      timestamp: DateTime.now(),
    );

    _handleNewMessage(optimisticMessage);

    if (!_isOnline) {
      _logger.i('Offline: Queuing message to $recipientId', tag: 'MessageService');
      _offlineQueue.add({
        'type': 'message',
        'recipient': recipientId,
        'text': text,
        'temp_id': tempId,
      });
      await _saveOfflineQueue();
      return optimisticMessage;
    }

    return await _sendMessageToServer(recipientId, text, tempId);
  }

  Future<MessageModel?> _sendMessageToServer(String recipientId, String text, String tempId) async {
    try {
      final result = await _messageRepository.sendMessageViaHttp(recipientId, text);

      if (result.isSuccess) {
        final sentMessage = result.value;
        _updateOptimisticMessage(tempId, sentMessage);
        return sentMessage;
      } else {
        final errorMessage = _errorHandler.handleError(result.error);
        _logger.e(
          'Failed to send message via HTTP: $errorMessage',
          error: result.error,
          tag: 'MessageService',
        );
        _markMessageAsFailed(tempId, errorMessage);
        return null;
      }
    } catch (e) {
      final errorMessage = _errorHandler.handleError(e);
      _logger.e(
        'Exception sending message to $recipientId: $errorMessage',
        error: e,
        tag: 'MessageService',
      );
      _markMessageAsFailed(tempId, errorMessage);
      return null;
    }
  }

  void _updateOptimisticMessage(String tempId, MessageModel serverMessage) {
    bool updated = false;
    ConversationModel? targetConversation;

    // Find the conversation containing the optimistic message
    for (var conversation in _conversations.values) {
      final index = conversation.messages.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        // Remove the optimistic message by tempId
        conversation.messages.removeAt(index);
        // Add the confirmed message from the server
        conversation.messages.add(serverMessage); 
        targetConversation = conversation;
        updated = true;
        break;
      }
    }

    // Log server message details before update attempt
    _logger.i('Attempting to update optimistic message $tempId. Server data: ${jsonEncode(serverMessage.toJson())}', tag: 'MessageService'); 

    if (updated && targetConversation != null) {
      // Sort messages: oldest first, handle null timestamps
      targetConversation.messages.sort((a, b) {
         final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
         final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
         return aTime.compareTo(bTime);
      });
      // Ensure the map is updated *before* notifying listeners
      _saveConversations(); 
      // Notify listeners AFTER state is fully updated
      _logger.i('Pushing updated message ${serverMessage.id} to stream.', tag: 'MessageService');
      _messageController.add(serverMessage); 
      notifyListeners(); 
      _logger.i('Updated optimistic message $tempId with server ID ${serverMessage.id}', tag: 'MessageService');
    } else {
      _logger.w('Could not find optimistic message with temp ID $tempId to update.', tag: 'MessageService');
    }
  }

  void _markMessageAsFailed(String tempId, String errorMessage) {
    bool updated = false;
    ConversationModel? targetConversation;
    MessageModel? targetMessage;

    for (var conversation in _conversations.values) {
      final index = conversation.messages.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        if (!conversation.messages[index].error) {
          conversation.messages[index].error = true;
          conversation.messages[index].errorMessage = errorMessage;
          targetConversation = conversation;
          targetMessage = conversation.messages[index];
          updated = true;
          break;
        }
      }
    }

    if (updated && targetConversation != null && targetMessage != null) {
      _messageController.add(targetMessage);
      _saveConversations();
      notifyListeners();
      _logger.i('Marked optimistic message $tempId as failed.', tag: 'MessageService');
    } else {
      _logger.w('Could not find optimistic message with temp ID $tempId to mark as failed.', tag: 'MessageService');
    }
  }

  ConversationModel getOrCreateConversation(UserModel friend) {
    final existingConversation = _conversations[friend.username];

    if (existingConversation != null &&
        existingConversation.friendName == (friend.displayName ?? friend.username) &&
        existingConversation.friendAvatarUrl == null) {
      return existingConversation;
    }

    final newConversation = ConversationModel(
      friendUsername: friend.username,
      friendName: friend.displayName ?? friend.username,
      messages: existingConversation?.messages ?? [],
    );

    _conversations[friend.username] = newConversation;
    _saveConversations();
    return newConversation;
  }

  Future<void> deleteMessage(String friendId, String messageId) async {
    if (_conversations.containsKey(friendId)) {
      _conversations[friendId]!.messages.removeWhere((m) => m.id == messageId);
      await _saveConversations();
      notifyListeners();
      _logger.i('Deleted message $messageId locally from conversation $friendId', tag: 'MessageService');
    } else {
      _logger.w('Cannot delete message $messageId: Conversation $friendId not found', tag: 'MessageService');
    }
  }

  Future<void> clearLocalMessagesForConversation(String friendId) async {
    if (_conversations.containsKey(friendId)) {
      _conversations[friendId]!.messages.clear();
      await _saveConversations();
      notifyListeners();
      _logger.i('Cleared all local messages for conversation $friendId', tag: 'MessageService');
    } else {
      _logger.w('Cannot clear messages: Conversation $friendId not found', tag: 'MessageService');
    }
  }

  Future<bool> clearAllLocalConversations() async {
    try {
      _conversations.clear();
      await _storageService.clearAllConversations();
      notifyListeners();
      _logger.i('Cleared all local conversations', tag: 'MessageService');
      return true;
    } catch (e) {
      _logger.e('Error clearing all local conversations', error: e, tag: 'MessageService');
      return false;
    }
  }

  // Add a public method to disconnect the WebSocket
  void disconnect() {
    _logger.i('Explicitly disconnecting WebSocket...', tag: 'MessageService');
    _handleDisconnect();
  }

  @override
  void dispose() {
    _messageController.close();
    _deliveryController.close();
    _reconnectTimer?.cancel();
    _connectionMonitorTimer?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }
}
