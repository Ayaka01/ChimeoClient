import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart';
import '../repositories/message_repository.dart';
import '../repositories/user_repository.dart';
import '../utils/error_handler.dart';

/// Controller for the chat screen that manages message handling logic
class ChatController extends ChangeNotifier {
  final String _authToken;
  final UserModel _friend;
  final MessageRepository _messageRepo = MessageRepository();
  final UserRepository _userRepo = UserRepository();
  final ErrorHandler _errorHandler = ErrorHandler();
  
  ConversationModel? _conversation;
  String? _highlightedMessageId;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _isSending = false;
  
  /// Constructor
  ChatController({
    required String authToken,
    required UserModel currentUser,
    required UserModel friend,
    String? highlightMessageId,
    ConversationModel? initialConversation,
  }) : 
    _authToken = authToken,
    _friend = friend,
    _highlightedMessageId = highlightMessageId,
    _conversation = initialConversation;
  
  /// Get the friend user model
  UserModel get friend => _friend;
  
  /// Get the conversation model
  ConversationModel? get conversation => _conversation;
  
  /// Get the highlighted message ID
  String? get highlightedMessageId => _highlightedMessageId;
  
  /// Get the sending status
  bool get isSending => _isSending;
  
  /// Set the conversation model
  set conversation(ConversationModel? value) {
    _conversation = value;
    notifyListeners();
  }
  
  /// Clear the highlighted message ID
  void clearHighlightedMessage() {
    _highlightedMessageId = null;
    notifyListeners();
  }
  
  /// Load or refresh friend data
  Future<void> loadFriendData() async {
    try {
      final friend = await _userRepo.getUserProfile(_friend.username, _authToken);
      if (friend != null) {
        // Use the updated friend data but keep the username from the original
        _conversation = ConversationModel(
          friendUsername: _friend.username,
          friendName: friend.displayName,
          friendAvatarUrl: friend.avatarUrl,
          messages: _conversation?.messages ?? [],
          isTyping: _conversation?.isTyping ?? false,
          typingTimestamp: _conversation?.typingTimestamp,
        );
        notifyListeners();
      }
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace: stackTrace);
    }
  }
  
  /// Send a message
  Future<MessageModel?> sendMessage(String text) async {
    if (text.trim().isEmpty) return null;
    
    try {
      _isSending = true;
      notifyListeners();
      
      // Reset typing indicator
      resetTypingIndicator();
      
      final message = await _messageRepo.sendMessage(_friend.username, text, _authToken);
      
      _isSending = false;
      notifyListeners();
      
      return message;
    } catch (e, stackTrace) {
      _isSending = false;
      notifyListeners();
      _errorHandler.logError(e, stackTrace: stackTrace);
      return null;
    }
  }
  
  /// Handle text change for typing indicator
  void handleTextChange(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      sendTypingIndicator(true);
    }
    
    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 3), resetTypingIndicator);
  }
  
  /// Reset typing indicator
  void resetTypingIndicator() {
    if (_isTyping) {
      _isTyping = false;
      sendTypingIndicator(false);
      _typingTimer?.cancel();
    }
  }
  
  /// Send typing indicator
  void sendTypingIndicator(bool isTyping) {
    _messageRepo.sendTypingIndicator(_friend.username, isTyping, _authToken);
  }
  
  /// Delete a message
  Future<bool> deleteMessage(String messageId) async {
    try {
      // Keep a local reference to conversation in case it changes during the operation
      final currentConversation = _conversation;
      if (currentConversation == null) return false;
      
      // Find the message first
      final messageIndex = currentConversation.messages.indexWhere((m) => m.id == messageId);
      if (messageIndex == -1) return false;
      
      // Create a new list without the message
      final updatedMessages = List<MessageModel>.from(currentConversation.messages);
      updatedMessages.removeAt(messageIndex);
      
      // Update the conversation
      _conversation = ConversationModel(
        friendUsername: currentConversation.friendUsername,
        friendName: currentConversation.friendName,
        friendAvatarUrl: currentConversation.friendAvatarUrl,
        messages: updatedMessages,
        isTyping: currentConversation.isTyping,
        typingTimestamp: currentConversation.typingTimestamp,
      );
      
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace: stackTrace);
      return false;
    }
  }
  
  @override
  void dispose() {
    _typingTimer?.cancel();
    resetTypingIndicator();
    super.dispose();
  }
} 