import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/error_handler.dart';
import 'local_storage_service.dart';

class OfflineQueueService with ChangeNotifier {
  final LocalStorageService _storageService;
  final ErrorHandler _errorHandler = ErrorHandler();
  List<Map<String, dynamic>> _offlineQueue = [];
  
  // Stream controller for items ready to be processed
  final StreamController<Map<String, dynamic>> _queueItemController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Getters
  List<Map<String, dynamic>> get offlineQueue => List.unmodifiable(_offlineQueue);
  Stream<Map<String, dynamic>> get queueItemStream => _queueItemController.stream;
  
  OfflineQueueService(this._storageService) {
    _loadOfflineQueue();
  }
  
  // Load offline message queue
  Future<void> _loadOfflineQueue() async {
    try {
      final queue = await _storageService.getOfflineQueue();
      _offlineQueue = queue ?? [];
      notifyListeners();
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace: stackTrace);
      _offlineQueue = [];
    }
  }
  
  // Save offline queue
  Future<bool> _saveOfflineQueue() async {
    try {
      final success = await _storageService.saveOfflineQueue(_offlineQueue);
      if (!success) {
         _errorHandler.logError('Failed to save offline queue');
      }
      return success;
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace: stackTrace);
      return false;
    }
  }
  
  // Add item to queue
  Future<bool> addToQueue(Map<String, dynamic> item) async {
    try {
      _offlineQueue.add(item);
      await _saveOfflineQueue();
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace: stackTrace);
      return false;
    }
  }
  
  // Remove item from queue
  Future<bool> removeFromQueue(Map<String, dynamic> item) async {
    try {
      _offlineQueue.remove(item);
      await _saveOfflineQueue();
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace: stackTrace);
      return false;
    }
  }
  
  // Process the queue when online
  Future<void> processQueue() async {
    if (_offlineQueue.isEmpty) return;
    
    // Make a copy to avoid modification during iteration
    final queueCopy = List<Map<String, dynamic>>.from(_offlineQueue);
    
    for (final item in queueCopy) {
      // Emit each item through the stream for MessageService to process
      _queueItemController.add(item);
    }
  }
  
  // Mark an item as processed
  Future<bool> markAsProcessed(Map<String, dynamic> item) async {
    return await removeFromQueue(item);
  }
  
  // Clear the entire queue
  Future<bool> clearQueue() async {
    try {
      _offlineQueue = [];
      final success = await _storageService.clearOfflineQueue();
      if (!success) {
         _errorHandler.logError('Failed to clear offline queue');
      }
      notifyListeners();
      return success;
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace: stackTrace);
      return false;
    }
  }
  
  // Clean up
  @override
  void dispose() {
    _queueItemController.close();
    super.dispose();
  }
} 