import 'dart:async';
import 'dart:convert';
// import 'package:http/http.dart' as http; // Remove http
import 'package:dio/dio.dart'; // Import dio
import 'package:simple_messenger/utils/exceptions.dart';
import '../config/api_config.dart';
import '../models/message_model.dart';
// import 'base_repository.dart'; // Remove base repository
import '../utils/result.dart';
import '../utils/logger.dart';
import '../utils/dio_client.dart'; // Import global dio

// class MessageRepository extends BaseRepository {
class MessageRepository {
  // static final MessageRepository _instance = MessageRepository._internal();
  // factory MessageRepository() => _instance;
  final Logger _logger = Logger();
  final Dio _dio = dio; // Use global dio

  // Remove internal constructor if not singleton
  // MessageRepository._internal();

  // Constructor (can be default or accept Dio if needed later)
  MessageRepository();

  Future<Result<void>> markMessageAsDelivered(String messageId) async {
    _logger.d('Marking message $messageId as delivered (HTTP)', tag: 'MessageRepository');
    try {
      final response = await _dio.post(
        '${ApiConfig.messagesPath}/delivered/$messageId',
      );

      // Dio throws for non-200 status codes by default
      _logger.i('Message $messageId marked as delivered successfully', tag: 'MessageRepository');
      return Result.success(null); // Return success with null value for void

    } on DioException catch (e) {
      _logger.e('DioException marking message $messageId delivered', error: e, tag: 'MessageRepository');
      // Use the centralized mapping function
      return Result.failure(mapDioExceptionToApiException(e));
    } catch (e) {
      _logger.e('Unexpected error marking message $messageId delivered', error: e, tag: 'MessageRepository');
      if (e is Exception) {
         return Result.failure(e);
      }
      return Result.failure(RepositoryException('Failed to mark message delivered: ${e.toString()}'));
    }
  }

  Future<Result<List<MessageModel>>> getPendingMessages() async {
    _logger.d('Getting pending messages (HTTP)', tag: 'MessageRepository');
     try {
        final response = await _dio.get(
          '${ApiConfig.messagesPath}/pending',
      );

        if (response.statusCode == 200 && response.data is List) {
            final List<dynamic> data = response.data;
        final messages = data.map((json) => MessageModel.fromJson(json)).toList();
        _logger.i('Fetched ${messages.length} pending messages successfully', tag: 'MessageRepository');
            return Result.success(messages);
        } else {
             _logger.w('Get pending messages returned non-200 or invalid data: ${response.statusCode}', tag: 'MessageRepository');
             // Throw ApiException for consistency
             throw ApiException(message: 'Failed to get pending messages: Unexpected response format', statusCode: response.statusCode);
        }

     } on DioException catch (e) {
        _logger.e('DioException getting pending messages', error: e, tag: 'MessageRepository');
         // Use the centralized mapping function
        return Result.failure(mapDioExceptionToApiException(e));
     } catch (e) {
       _logger.e('Unexpected error getting pending messages', error: e, tag: 'MessageRepository');
       if (e is Exception) {
          return Result.failure(e);
       }
       return Result.failure(RepositoryException('Failed to get pending messages: ${e.toString()}'));
      }
  }

  Future<Result<MessageModel>> sendMessageViaHttp(String recipientId, String text) async {
    _logger.d('Sending message to $recipientId via HTTP', tag: 'MessageRepository');
    try {
      _logger.d('Sending message via HTTP - recipientId: $recipientId, text: "$text"');
      final response = await _dio.post(
        '${ApiConfig.messagesPath}/', // Use relative path
        data: json.encode({
          'recipient_username': recipientId,
          'text': text,
        }),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
          final sentMessage = MessageModel.fromJson(response.data);
          _logger.i('Message sent successfully via HTTP, ID: ${sentMessage.id}', tag: 'MessageRepository');
          return Result.success(sentMessage);
      } else {
          _logger.w('Send message returned non-200 or invalid data: ${response.statusCode}', tag: 'MessageRepository');
          // Throw ApiException for consistency
          throw ApiException(message: 'Failed to send message: Unexpected response format', statusCode: response.statusCode);
      }

    } on DioException catch (e) {
      _logger.e('DioException sending message', error: e, tag: 'MessageRepository');
      // Use the centralized mapping function
      return Result.failure(mapDioExceptionToApiException(e));
    } catch (e) {
      _logger.e('Unexpected error sending message', error: e, tag: 'MessageRepository');
      if (e is Exception) {
         return Result.failure(e);
      }
      return Result.failure(RepositoryException('Failed to send message: ${e.toString()}'));
    }
  }
}