class ApiConfig {
  // Base URLs for different environments
  static const String _devBaseUrl = 'http://10.0.2.2:8000'; // Android emulator
  static const String _devWsUrl = 'ws://10.0.2.2:8000';
  
  static const String _localBaseUrl = 'http://192.168.1.45:8000'; // Local network
  static const String _localWsUrl = 'ws://192.168.1.45:8000';
  
  static const String _prodBaseUrl = 'https://api.chimeo-app.example.com'; // Replace with actual production URL
  static const String _prodWsUrl = 'wss://api.chimeo-app.example.com';
  
  // Set environment - can be controlled via build arguments
  static const String _environment = String.fromEnvironment('ENV', defaultValue: 'local');
  
  // Determine which URLs to use based on environment
  static String get baseUrl {
    if (_environment == 'dev') return _devBaseUrl;
    if (_environment == 'prod') return _prodBaseUrl;
    return _localBaseUrl;
  }
  
  static String get wsUrl {
    if (_environment == 'dev') return _devWsUrl;
    if (_environment == 'prod') return _prodWsUrl;
    return _localWsUrl;
  }
  
  // API paths - helps with consistency
  static const String authPath = '/auth';
  static const String usersPath = '/users';
  static const String messagesPath = '/messages';
}