import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/api_config.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

enum ConnectionState {
  disconnected,
  connecting,
  connected
}

class WebSocketService with ChangeNotifier {
  WebSocketChannel? _wsChannel;
  Timer? _connectionMonitorTimer;
  ConnectionState _connectionState = ConnectionState.disconnected;
  bool _isOnline = true;
  final ErrorHandler _errorHandler = ErrorHandler();
  final Logger _logger = Logger();
  
  // Controllers for different message types
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Getters
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  ConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == ConnectionState.connected;
  bool get isOnline => _isOnline;
  
  WebSocketService() {
    _setupConnectivityMonitoring();
  }
  
  // Setup connectivity monitoring
  void _setupConnectivityMonitoring() async {
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _isOnline = result != ConnectivityResult.none;
      
      if (_isOnline && _connectionState == ConnectionState.disconnected) {
        _logger.i('Device is online, reconnecting...', tag: 'WebSocketService');
        // Connection will be handled by connect() when called by MessageService
      } else if (!_isOnline) {
        _logger.i('Device is offline', tag: 'WebSocketService');
        disconnect();
        _connectionState = ConnectionState.disconnected;
        notifyListeners();
      }
    });
    
    // Check initial connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    _isOnline = connectivityResult != ConnectivityResult.none;
  }
  
  // Connect to WebSocket
  void connect(String username, String token) {
    if (!_isOnline || token.isEmpty || username.isEmpty) return;
    
    try {
      _connectionState = ConnectionState.connecting;
      notifyListeners();
      
      final wsUrl = '${ApiConfig.wsUrl}${ApiConfig.messagesPath}/ws/$username';
      
      // Add authentication token to the WebSocket connection
      final uri = Uri.parse(wsUrl);
      final uriWithAuth = uri.replace(
        queryParameters: {'token': token},
      );

      _wsChannel = WebSocketChannel.connect(uriWithAuth);

      _wsChannel!.stream.listen(
        (dynamic data) {
          final jsonData = json.decode(data);
          _messageController.add(jsonData);
        },
        onDone: _handleDisconnect,
        onError: (error, stackTrace) {
          _errorHandler.logError(error, stackTrace: stackTrace);
          _handleDisconnect();
        },
      );

      // Send authentication message
      _wsChannel?.sink.add(
        json.encode({
          'type': 'authenticate',
          'token': token,
        }),
      );

      // Setup heartbeat to detect connection issues early
      _connectionMonitorTimer?.cancel();
      _connectionMonitorTimer = Timer.periodic(Duration(seconds: 30), (timer) {
        if (_connectionState == ConnectionState.connected) {
          _wsChannel?.sink.add(json.encode({'type': 'ping'}));
        } else {
          timer.cancel();
        }
      });

      _connectionState = ConnectionState.connected;
      notifyListeners();

      _logger.i('Connected to WebSocket server', tag: 'WebSocketService');
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace: stackTrace);
      _handleDisconnect();
    }
  }
  
  // Send a message through the WebSocket
  void send(Map<String, dynamic> message) {
    if (_connectionState == ConnectionState.connected) {
      try {
        _wsChannel?.sink.add(json.encode(message));
      } catch (e, stackTrace) {
        _errorHandler.logError(e, stackTrace: stackTrace);
      }
    }
  }
  
  // Handle WebSocket disconnection
  void _handleDisconnect() {
    _connectionState = ConnectionState.disconnected;
    notifyListeners();

    // Only try to reconnect if online
    if (_isOnline) {
      // Reconnection will be handled by the service that owns this
      // The parent service needs to call connect() when appropriate
    }
  }
  
  // Disconnect WebSocket
  void disconnect() {
    _wsChannel?.sink.close();
    _connectionMonitorTimer?.cancel();
    _connectionState = ConnectionState.disconnected;
    notifyListeners();
  }
  
  // Clean up
  @override
  void dispose() {
    disconnect();
    _messageController.close();
    super.dispose();
  }
} 