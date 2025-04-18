// lib/repositories/message_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../models/message_model.dart';
import 'base_repository.dart';

/// Repository for handling message-related data access
class MessageRepository extends BaseRepository {
  /// Singleton instance
  static final MessageRepository _instance = MessageRepository._internal();
  
  /// WebSocket channel for real-time messages
  WebSocketChannel? _wsChannel;
  
  /// Private constructor
  MessageRepository._internal();
  
  /// Factory constructor to return the singleton instance
  factory MessageRepository() => _instance;
  
  /// Connect to WebSocket for real-time messaging
  Future<WebSocketChannel?> connectToWebSocket(String username, String token) async {
    return await executeSafe<WebSocketChannel>(() async {
      final wsUrl = '${ApiConfig.wsUrl}${ApiConfig.messagesPath}/ws/$username';
      
      // Add authentication token to the WebSocket connection
      final uri = Uri.parse(wsUrl);
      final uriWithAuth = uri.replace(
        queryParameters: {'token': token},
      );

      final channel = WebSocketChannel.connect(uriWithAuth);
      _wsChannel = channel;
      return channel;
    });
  }
  
  /// Close WebSocket connection
  void closeWebSocket() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }
  
  /// Send a message through WebSocket
  void sendWebSocketMessage(Map<String, dynamic> data) {
    if (_wsChannel != null) {
      _wsChannel!.sink.add(json.encode(data));
    }
  }
  
  /// Send typing indicator
  void sendTypingIndicator(String recipientId, bool isTyping, String token) {
    sendWebSocketMessage({
      'type': 'typing_indicator',
      'data': {
        'recipient': recipientId,
        'is_typing': isTyping
      }
    });
  }
  
  /// Send message to server
  Future<MessageModel?> sendMessage(String recipientId, String text, String token) async {
    return await executeSafe<MessageModel>(() async {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesPath}/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'recipient_username': recipientId, 'text': text}),
      );

      if (response.statusCode == 200) {
        return MessageModel.fromJson(json.decode(response.body));
      }
      
      throw Exception('Failed to send message: ${response.statusCode}');
    });
  }
  
  /// Mark message as delivered
  Future<bool> markMessageAsDelivered(String messageId, String token) async {
    return await executeSafeBool(() async {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesPath}/delivered/$messageId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark message as delivered: ${response.statusCode}');
      }
    });
  }
  
  /// Get pending messages
  Future<List<MessageModel>> getPendingMessages(String token) async {
    final result = await executeSafe<List<MessageModel>>(() async {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesPath}/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => MessageModel.fromJson(json)).toList();
      }
      
      throw Exception('Failed to get pending messages: ${response.statusCode}');
    });
    
    return result ?? [];
  }
} 