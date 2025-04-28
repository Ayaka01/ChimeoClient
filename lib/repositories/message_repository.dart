import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:simple_messenger/utils/exceptions.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../models/message_model.dart';
import 'base_repository.dart';
import '../utils/result.dart';
import '../utils/logger.dart';

class MessageRepository extends BaseRepository {
  static final MessageRepository _instance = MessageRepository._internal();
  factory MessageRepository() => _instance;
  final Logger _logger = Logger();

  MessageRepository._internal();

  // Holds the active WebSocket connection if connected. Null otherwise.
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;


  Future<Result<WebSocketChannel>> connectToWebSocket(String username, String token) async {
    _logger.i('Attempting WebSocket connection for user: $username', tag: 'MessageRepository');
    if (_wsChannel != null) {
        return Result.success(_wsChannel!);
    }

    // If no connection exists
    final Result<WebSocketChannel> connectionResult = await executeSafe<WebSocketChannel>(() async {
      final wsUrl = '${ApiConfig.wsUrl}${ApiConfig.messagesPath}/ws/$username';
      final uri = Uri.parse(wsUrl);
      final uriWithAuth = uri.replace(
        queryParameters: {'token': token},
      );
      final channel = WebSocketChannel.connect(uriWithAuth);
      return channel;
    });

    connectionResult.onSuccess((WebSocketChannel channel) {
      _wsChannel = channel;
      _setupListener();
    });

    connectionResult.onFailure((Exception _) {
      _wsChannel = null;
    });

    return connectionResult;
  }

  void _setupListener() {
    if (_wsChannel == null) {
      _logger.w('Cannot setup listener, WebSocket channel is null', tag: 'MessageRepository');
      return;
    }
    _logger.d('Setting up WebSocket listener', tag: 'MessageRepository');

    _wsSubscription?.cancel();
    _wsSubscription = _wsChannel!.stream.listen(
          (message) {
        _logger.d('WebSocket message received: $message', tag: 'MessageRepository');
        // TODO: Implement actual message handling
      },
      onError: (error) {
        _logger.e('WebSocket error - Connection Lost!', error: error, tag: 'MessageRepository');
        _handleConnectionEnd();
      },
      onDone: () {
        _logger.i('WebSocket connection closed by server.', tag: 'MessageRepository');
        _handleConnectionEnd();
      },
    );
  }

  void _handleConnectionEnd() {
    _logger.d('Handling WebSocket connection end', tag: 'MessageRepository');
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _wsChannel = null;
  }

  void closeWebSocket() {
    _logger.i('Closing WebSocket connection', tag: 'MessageRepository');
    if (_wsChannel == null) {
      return;
    }
    _wsChannel?.sink.close();
    _handleConnectionEnd();
  }

   void sendWebSocketMessage(Map<String, dynamic> data) {
    if (_wsChannel != null) {
      _logger.d('Sending WebSocket message: ${json.encode(data)}', tag: 'MessageRepository');
      try {
        _wsChannel!.sink.add(json.encode(data));
      } catch (e) {
        _logger.e('Failed to send message via WebSocket sink', error: e, tag: 'MessageRepository');
        _handleConnectionEnd();
      }
    } else {
      _logger.w('Tried to send WebSocket message, but channel is null.', tag: 'MessageRepository');
    }
  }


  Future<Result<void>> markMessageAsDelivered(String messageId, String token) async {
    _logger.d('Marking message $messageId as delivered (HTTP)', tag: 'MessageRepository');
    return await executeSafe<void>(() async {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesPath}/delivered/$messageId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        // TODO: Implement more specific exceptions based on status code
        throw Exception('Failed to mark message as delivered: ${response.statusCode} ${response.reasonPhrase}');
      }
      _logger.i('Message $messageId marked as delivered successfully', tag: 'MessageRepository');
    });
  }

  Future<Result<List<MessageModel>>> getPendingMessages(String token) async {
    _logger.d('Getting pending messages (HTTP)', tag: 'MessageRepository');
    return await executeSafe<List<MessageModel>>(() async {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesPath}/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final messages = data.map((json) => MessageModel.fromJson(json)).toList();
        _logger.i('Fetched ${messages.length} pending messages successfully', tag: 'MessageRepository');
        return messages;
      } else {
        // TODO: Implement more specific exceptions based on status code
        throw Exception('Failed to get pending messages: ${response.statusCode} ${response.reasonPhrase}');
      }
    });
  }

  Future<Result<MessageModel>> sendMessageViaHttp(String recipientId, String text, String token) async {
    _logger.d('Sending message to $recipientId via HTTP', tag: 'MessageRepository');
    return await executeSafe<MessageModel>(() async {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesPath}/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'recipient_id': recipientId,
          'text': text,
        }),
      );

      if(response.statusCode == 422) {
        throw ValidationDataError("Data Validation Error");
      }

      if(response.statusCode == 500) {
        throw InternalServerErrorException();
      }

      final sentMessage = MessageModel.fromJson(json.decode(response.body));
      _logger.i('Message sent successfully via HTTP, ID: ${sentMessage.id}', tag: 'MessageRepository');
      return sentMessage;
    });
  }
}