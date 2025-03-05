// lib/services/chat_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message_model.dart';
import '../models/chat_room_model.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'local_storage_service.dart';

class ChatService {
  final AuthService _authService;
  final LocalStorageService _localStorageService = LocalStorageService();
  WebSocketChannel? _wsChannel;
  final _messageController = StreamController<MessageModel>.broadcast();
  final _deliveryController = StreamController<String>.broadcast();
  final Map<String, bool> _joinedRooms = {};

  Stream<MessageModel> get messagesStream => _messageController.stream;
  Stream<String> get deliveryStream => _deliveryController.stream;

  ChatService(this._authService) {
    _initWebSocket();
  }

  void _initWebSocket() {
    if (_authService.user != null && _authService.token != null) {
      try {
        _wsChannel = WebSocketChannel.connect(
          Uri.parse('${ApiConfig.wsUrl}/messages/ws/${_authService.user!.id}'),
        );

        _wsChannel!.stream.listen(
          (dynamic data) {
            final jsonData = json.decode(data);

            if (jsonData['type'] == 'new_message') {
              final message = MessageModel.fromJson(jsonData['data']);

              // Save the message locally
              _localStorageService.saveMessage(message);

              // Forward to UI
              _messageController.add(message);

              // Send delivery confirmation to server
              _markAsDelivered(message.id);
            } else if (jsonData['type'] == 'message_delivered') {
              final messageId = jsonData['data']['message_id'];

              // Notify UI that a message was delivered
              _deliveryController.add(messageId);
            }
          },
          onDone: () {
            // Connection closed, try to reconnect
            Future.delayed(Duration(seconds: 5), _initWebSocket);
          },
          onError: (error) {
            print('WebSocket error: $error');
            // Try to reconnect
            Future.delayed(Duration(seconds: 5), _initWebSocket);
          },
        );
      } catch (e) {
        print('WebSocket connection error: $e');
        // Try to reconnect
        Future.delayed(Duration(seconds: 5), _initWebSocket);
      }
    }
  }

  void joinChatRoom(String roomId) {
    if (_wsChannel != null && !_joinedRooms.containsKey(roomId)) {
      _wsChannel!.sink.add(
        json.encode({'type': 'join_room', 'room_id': roomId}),
      );
      _joinedRooms[roomId] = true;
    }
  }

  void leaveChatRoom(String roomId) {
    if (_wsChannel != null && _joinedRooms.containsKey(roomId)) {
      _wsChannel!.sink.add(
        json.encode({'type': 'leave_room', 'room_id': roomId}),
      );
      _joinedRooms.remove(roomId);
    }
  }

  Future<List<MessageModel>> getMessages(String roomId) async {
    try {
      // First, get locally stored messages
      List<MessageModel> localMessages = await _localStorageService.getMessages(
        roomId,
      );

      // Then, get any undelivered messages from the server
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/messages/$roomId'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<MessageModel> serverMessages =
            data.map((json) => MessageModel.fromJson(json)).toList();

        // Save server messages locally
        for (var message in serverMessages) {
          await _localStorageService.saveMessage(message);

          // Mark messages as delivered
          await _markAsDelivered(message.id);
        }

        // Combine and re-sort all messages
        localMessages.addAll(serverMessages);
        localMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return localMessages;
      }

      // Return local messages if server request fails
      return localMessages;
    } catch (e) {
      print('Error getting messages: $e');

      // Return locally stored messages in case of error
      return await _localStorageService.getMessages(roomId);
    }
  }

  Future<void> _markAsDelivered(String messageId) async {
    try {
      // Send delivery confirmation to server
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/messages/$messageId/delivered'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      // Update message in local storage
      // First we need to find the message
      List<String> chatRooms = await _localStorageService.getAllChatRooms();

      for (String roomId in chatRooms) {
        List<MessageModel> messages = await _localStorageService.getMessages(
          roomId,
        );
        MessageModel? message = messages.firstWhere(
          (msg) => msg.id == messageId,
          orElse:
              () => MessageModel(
                id: '',
                senderId: '',
                text: '',
                timestamp: DateTime.now(),
                chatRoomId: '',
              ),
        );

        if (message.id.isNotEmpty) {
          message.delivered = true;
          await _localStorageService.updateMessage(message);
          break;
        }
      }
    } catch (e) {
      print('Error marking message as delivered: $e');
    }
  }

  Future<MessageModel?> sendMessage(
    String text,
    String roomId,
    String recipientId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/messages/'),
        headers: {
          'Authorization': 'Bearer ${_authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'text': text,
          'chat_room_id': roomId,
          'recipient_id': recipientId,
        }),
      );

      if (response.statusCode == 200) {
        MessageModel message = MessageModel.fromJson(
          json.decode(response.body),
        );

        // Save message locally
        await _localStorageService.saveMessage(message);

        return message;
      }

      return null;
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  Future<List<ChatRoomModel>> getUserChatRooms() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat-rooms/'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ChatRoomModel.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error getting chat rooms: $e');
      return [];
    }
  }

  Future<ChatRoomModel?> createChatRoom(String recipientId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chat-rooms/$recipientId'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        return ChatRoomModel.fromJson(json.decode(response.body));
      }

      return null;
    } catch (e) {
      print('Error creating chat room: $e');
      return null;
    }
  }

  void dispose() {
    _messageController.close();
    _deliveryController.close();
    _wsChannel?.sink.close();
  }
}
