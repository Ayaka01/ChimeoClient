// lib/screens/friend_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../models/friend_request_model.dart';
import '../components/user_avatar.dart';
import '../constants/colors.dart';
import '../components/error_display.dart';
import '../utils/logger.dart'; // Import Logger
import 'package:simple_messenger/utils/exceptions.dart'; // Ensure imported

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  FriendRequestsScreenState createState() => FriendRequestsScreenState();
}

class FriendRequestsScreenState extends State<FriendRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UserService _userService;
  List<FriendRequestModel> _receivedRequests = [];
  List<FriendRequestModel> _sentRequests = [];
  bool _isLoadingReceived = true;
  bool _isLoadingSent = true;
  String? _receivedError;
  String? _sentError;
  final Logger _logger = Logger(); // Instantiate Logger

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userService = context.read<UserService>();

    _loadReceivedRequests();
    _loadSentRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReceivedRequests() async {
    setState(() {
      _isLoadingReceived = true;
      _receivedError = null; // Clear previous error
    });

    try {
      final requests = await _userService.getReceivedFriendRequests();
      
      if (!mounted) return;
      
      setState(() {
        _receivedRequests = requests;
        _isLoadingReceived = false;
      });
    } catch (e) {
      if (!mounted) return;
      _logger.e('Error loading received requests', error: e, tag: 'FriendRequestsScreen');
      setState(() {
        _isLoadingReceived = false;
        _receivedError = e is Exception ? e.toString() : 'Error al cargar solicitudes recibidas.';
      });
    }
  }

  Future<void> _loadSentRequests() async {
    setState(() {
      _isLoadingSent = true;
      _sentError = null; // Clear previous error
    });

    try {
      final requests = await _userService.getSentFriendRequests();
      
      if (!mounted) return;
      
      setState(() {
        _sentRequests = requests;
        _isLoadingSent = false;
      });
    } catch (e) {
      if (!mounted) return;
      _logger.e('Error loading sent requests', error: e, tag: 'FriendRequestsScreen');
      setState(() {
        _isLoadingSent = false;
        _sentError = e is Exception ? e.toString() : 'Error al cargar solicitudes enviadas.';
      });
    }
  }

  Future<void> _respondToRequest(String requestId, String action) async {
    _logger.d('Attempting to respond ($action) to request $requestId', tag: 'FriendRequestsScreen');
    
    String errorTitle = 'Error al responder';
    String errorMessage = 'Ocurrió un error inesperado.'; // Default message

    try {
      await _userService.respondToFriendRequest(requestId, action);
      _logger.i('Response ($action) to request $requestId successful', tag: 'FriendRequestsScreen');
      if (!mounted) return;
      // Reload the lists on success
      _loadReceivedRequests();
      _loadSentRequests();
      return; // Exit on success

    // Catch specific known errors
    } on FriendRequestNotFoundException catch (e) {
        errorMessage = e.message;
    } on NotAuthorizedException catch (e) {
        errorMessage = e.message;
        errorTitle = 'No autorizado';
    } on InvalidFriendRequestStateException catch (e) {
        errorMessage = e.message;
        errorTitle = 'Acción inválida';
    } on Exception catch (e) { // Catch other general exceptions
      _logger.e('Error responding to request $requestId ($action)', error: e, tag: 'FriendRequestsScreen');
      errorMessage = e.toString(); // Use the exception's message
    }
      
    // Show dialog only if an error occurred
    if (mounted) { 
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text(errorTitle),
            content: Text(errorMessage), // Show specific or generic error message
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Solicitudes de amistad'),
      ),
      body: Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(splashColor: AppColors.primary),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Recibidas'), 
                Tab(text: 'Enviadas')
              ],
              labelColor: AppColors.secondary,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildReceivedRequestsList(), _buildSentRequestsList()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedRequestsList() {
    if (_isLoadingReceived) {
      return Center(child: CircularProgressIndicator());
    }
    if (_receivedError != null) {
      return ErrorDisplay(
        errorMessage: _receivedError!,
        onRetry: _loadReceivedRequests,
      );
    }
    if (_receivedRequests.isEmpty) {
      return _buildEmptyReceivedView();
    }
    return RefreshIndicator(
      onRefresh: _loadReceivedRequests,
      child: ListView.builder(
        itemCount: _receivedRequests.length,
        itemBuilder: (context, index) {
          final request = _receivedRequests[index];
          return _buildReceivedRequestTile(request);
        },
      ),
    );
  }

  Widget _buildEmptyReceivedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No tienes solicitudes pendientes',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedRequestTile(FriendRequestModel request) {
    return ListTile(
      leading: UserAvatar(
        displayName: request.senderUsername, 
        size: 45,
      ),
      title: Text(
        request.senderUsername,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('Quiere ser tu amigo'), 
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: () => _respondToRequest(request.id, 'reject'),
            child: Icon(Icons.close, size: 18, color: Colors.red),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size(40, 36),
              side: BorderSide(color: Colors.red.withAlpha((255 * 0.05).round())),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _respondToRequest(request.id, 'accept'),
            child: Icon(Icons.check, size: 18, color: Colors.green[700]),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green[700],
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size(40, 36),
              side: BorderSide(color: Colors.green.withAlpha((255 * 0.05).round())),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildSentRequestsList() {
    if (_isLoadingSent) {
      return Center(child: CircularProgressIndicator());
    }
    if (_sentError != null) {
      return ErrorDisplay(
        errorMessage: _sentError!,
        onRetry: _loadSentRequests,
      );
    }
    if (_sentRequests.isEmpty) {
      return _buildEmptySentView();
    }
    return RefreshIndicator(
      onRefresh: _loadSentRequests,
      child: ListView.builder(
        itemCount: _sentRequests.length,
        itemBuilder: (context, index) {
          final request = _sentRequests[index];
          return _buildSentRequestTile(request);
        },
      ),
    );
  }

  Widget _buildEmptySentView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.outgoing_mail, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No has enviado ninguna solicitud',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSentRequestTile(FriendRequestModel request) {
    return ListTile(
      leading: UserAvatar(
        displayName: request.recipientUsername, 
        size: 45,
      ),
      title: Text(
        request.recipientUsername,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('Solicitud enviada'),
      trailing: null,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
