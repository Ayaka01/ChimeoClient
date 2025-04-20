import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../models/message_model.dart';
import 'base_repository.dart';
import '../utils/result.dart';

/// Repository for handling message-related data access
class MessageRepository extends BaseRepository {
  static final MessageRepository _instance = MessageRepository._internal();
  factory MessageRepository() => _instance;
  MessageRepository._internal();

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;


  Future<Result<WebSocketChannel>> connectToWebSocket(String username, String token) async {
    if (_wsChannel != null) {
      print("DEBUG: WebSocket channel reference found. Returning existing one as Success.");
        return Result.success(_wsChannel!);
    }

    print("DEBUG: No active WebSocket channel. Attempting new connection...");
    final connectionResult = await executeSafe<WebSocketChannel>(() async {
      final wsUrl = '${ApiConfig.wsUrl}${ApiConfig.messagesPath}/ws/$username';
      final uri = Uri.parse(wsUrl);
      final uriWithAuth = uri.replace(
        queryParameters: {'token': token},
      );
      print("DEBUG: Connecting to WebSocket at $uriWithAuth ...");
      final channel = WebSocketChannel.connect(uriWithAuth);
      print("DEBUG: WebSocket connection established via connect().");
      return channel;
    });

    connectionResult.onSuccess((channel) {
      print("DEBUG: Storing new channel reference and setting up listener.");
      _wsChannel = channel;
      _setupListener();
    });

    connectionResult.onFailure((error) {
      print("ERROR: Failed to connect WebSocket: $error");
      _wsChannel = null;
    });

    return connectionResult;
  }

  void _setupListener() {
    if (_wsChannel == null) {
      print("ERROR: _setupListener called but _wsChannel is null.");
      return;
    }
    print("DEBUG: Setting up WebSocket stream listener...");
    _wsSubscription?.cancel();
    _wsSubscription = _wsChannel!.stream.listen(
          (message) {
        print("Message received: $message");
        // TODO: Implement actual message handling
      },
      onError: (error) {
        print("WebSocket Error: $error - Connection Lost!");
        _handleConnectionEnd(isError: true, error: error);
      },
      onDone: () {
        print("WebSocket Done: Server closed connection.");
        _handleConnectionEnd(isError: false);
      },
      cancelOnError: true,
    );
  }

  void _handleConnectionEnd({required bool isError, Object? error}) {
    print("DEBUG: Cleaning up WebSocket state (isError: $isError)...");
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _wsChannel = null;
    // TODO: Optionally notify rest of app about disconnection
  }

  void closeWebSocket() {
    if (_wsChannel == null) {
      print("DEBUG: closeWebSocket called but channel is already null.");
      return;
    }
    print("DEBUG: Initiating client-side WebSocket close...");
    _wsChannel?.sink.close().catchError((error) {
      print("WARN: Error while closing WebSocket sink: $error");
    });
    _handleConnectionEnd(isError: false);
  }

   void sendWebSocketMessage(Map<String, dynamic> data) {
    if (_wsChannel != null) {
      print("DEBUG: Sending WebSocket message: ${json.encode(data)}");
      try {
        _wsChannel!.sink.add(json.encode(data));
      } catch (e) {
        print("ERROR: Failed to send message via WebSocket sink: $e");
        _handleConnectionEnd(isError: true, error: e);
      }
    } else {
      print("WARN: Tried to send WebSocket message, but channel is null.");
    }
  }

  Future<Result<MessageModel>> sendMessage(String recipientId, String text, String token) async {
    print("DEBUG: Sending HTTP message to $recipientId");
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
      } else {
        // TODO: Implement more specific exceptions based on status code
        throw Exception('Failed to send message: ${response.statusCode} ${response.reasonPhrase}');
      }
    });
  }

  Future<Result<void>> markMessageAsDelivered(String messageId, String token) async {
    print("DEBUG: Marking message $messageId as delivered (HTTP)");
    return await executeSafe<void>(() async {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesPath}/delivered/$messageId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        // TODO: Implement more specific exceptions based on status code
        throw Exception('Failed to mark message as delivered: ${response.statusCode} ${response.reasonPhrase}');
      }
    });
  }

  Future<Result<List<MessageModel>>> getPendingMessages(String token) async {
    print("DEBUG: Getting pending messages (HTTP)");
    return await executeSafe<List<MessageModel>>(() async {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesPath}/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => MessageModel.fromJson(json)).toList();
      } else {
        // TODO: Implement more specific exceptions based on status code
        throw Exception('Failed to get pending messages: ${response.statusCode} ${response.reasonPhrase}');
      }
    });
  }
}