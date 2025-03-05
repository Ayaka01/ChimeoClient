// lib/config/api_config.dart
class ApiConfig {
  // Base API URL - replace with your actual server address
  // For local testing on Android emulator, use 10.0.2.2 instead of localhost
  static const String baseUrl = 'http://192.168.1.45:8000';
  //static const String baseUrl = 'http://10.0.2.2:8000';

  // WebSocket URL - replace with your actual server address
  static const String wsUrl = 'ws://192.168.1.45:8000';
  //static const String wsUrl = 'ws://10.0.2.2:8000';
}
