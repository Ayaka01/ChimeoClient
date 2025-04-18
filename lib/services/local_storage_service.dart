// lib/services/local_storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation_model.dart';
import '../utils/logger.dart';

/// Service for interacting with local storage
class LocalStorageService {
  static const String conversationsKey = 'conversations';
  static const String offlineQueueKey = 'offline_queue';
  static final LocalStorageService _instance = LocalStorageService._internal();
  SharedPreferences? _preferences;

  // Private constructor
  LocalStorageService._internal();
  
  // Factory constructor to return the singleton instance
  factory LocalStorageService() => _instance;
  
  /// Initialize the shared preferences instance
  Future<void> init() async {
    _preferences ??= await SharedPreferences.getInstance();
  }
  
  /// Get a string from storage
  String? getString(String key) {
    _ensureInitialized();
    return _preferences?.getString(key);
  }
  
  /// Set a string in storage
  Future<bool> setString(String key, String value) async {
    await _ensureInitialized();
    return await _preferences!.setString(key, value);
  }
  
  /// Remove a key from storage
  Future<bool> remove(String key) async {
    await _ensureInitialized();
    return await _preferences!.remove(key);
  }
  
  /// Clear all data from storage
  Future<bool> clear() async {
    await _ensureInitialized();
    return await _preferences!.clear();
  }
  
  /// Ensure the preferences instance is initialized
  Future<void> _ensureInitialized() async {
    if (_preferences == null) {
      await init();
    }
  }

  // Conversations methods
  Future<Map<String, ConversationModel>?> getConversations() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? conversationsJson = prefs.getString(conversationsKey);

      if (conversationsJson == null) {
        return {};
      }

      final Map<String, dynamic> conversationsMap = json.decode(conversationsJson);
      final Map<String, ConversationModel> conversations = {};

      conversationsMap.forEach((key, value) {
        conversations[key] = ConversationModel.fromJson(value);
      });

      return conversations;
    } catch (e) {
      Logger().e('Error getting conversations from storage', error: e, tag: 'LocalStorageService');
      return {};
    }
  }

  Future<bool> saveConversations(Map<String, ConversationModel> conversations) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> conversationsMap = {};

      conversations.forEach((key, value) {
        conversationsMap[key] = value.toJson();
      });

      final String conversationsJson = json.encode(conversationsMap);
      return await prefs.setString(conversationsKey, conversationsJson);
    } catch (e) {
      Logger().e('Error saving conversations to storage', error: e, tag: 'LocalStorageService');
      return false;
    }
  }

  Future<bool> clearAllConversations() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return await prefs.remove(conversationsKey);
    } catch (e) {
      Logger().e('Error clearing conversations from storage', error: e, tag: 'LocalStorageService');
      return false;
    }
  }
  
  // Offline queue methods
  Future<List<Map<String, dynamic>>?> getOfflineQueue() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? queueJson = prefs.getString(offlineQueueKey);

      if (queueJson == null) {
        return [];
      }

      final List<dynamic> queueList = json.decode(queueJson);
      return queueList.cast<Map<String, dynamic>>();
    } catch (e) {
      Logger().e('Error getting offline queue from storage', error: e, tag: 'LocalStorageService');
      return [];
    }
  }

  Future<bool> saveOfflineQueue(List<Map<String, dynamic>> queue) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String queueJson = json.encode(queue);
      return await prefs.setString(offlineQueueKey, queueJson);
    } catch (e) {
      Logger().e('Error saving offline queue to storage', error: e, tag: 'LocalStorageService');
      return false;
    }
  }

  Future<bool> clearOfflineQueue() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return await prefs.remove(offlineQueueKey);
    } catch (e) {
      Logger().e('Error clearing offline queue from storage', error: e, tag: 'LocalStorageService');
      return false;
    }
  }
}
