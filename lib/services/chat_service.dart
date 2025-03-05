// lib/services/chat_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message_model.dart';
import '../models/chat_room_model.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class ChatService {
  final AuthService _authService;
  WebSocketChannel? _wsChannel;
  final _messageController = StreamController<MessageModel>.broadcast();
  final Map<String, bool> _joinedRooms = {};

  Stream<MessageModel> get messagesStream => _messageController.stream;

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
              _messageController.add(message);
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

  String getChatRoomId(String user1, String user2) {
    // Create a consistent room ID regardless of who initiated the chat
    return user1.compareTo(user2) > 0 ? '$user1-$user2' : '$user2-$user1';
  }

  Future<List<MessageModel>> getMessages(String roomId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/messages/$roomId'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => MessageModel.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error getting messages: $e');
      return [];
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
        return MessageModel.fromJson(json.decode(response.body));
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
    _wsChannel?.sink.close();
  }
}
