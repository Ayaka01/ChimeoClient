// lib/screens/friend_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../models/friend_request_model.dart';
import '../components/user_avatar.dart';
import '../constants/colors.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userService = Provider.of<UserService>(context, listen: false);

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
      
      setState(() {
        _isLoadingReceived = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar solicitudes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadSentRequests() async {
    setState(() {
      _isLoadingSent = true;
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
      
      setState(() {
        _isLoadingSent = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar solicitudes enviadas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _respondToRequest(String requestId, String action) async {
    try {
      // Now expects a boolean indicating success
      final bool success = await _userService.respondToFriendRequest(
        requestId,
        action,
      );

      // Check if widget is still mounted after async operation
      if (!mounted) return;

      // Check the boolean result
      if (success) { 
        // Reload the lists
        _loadReceivedRequests();
        _loadSentRequests();

        // Show success message
        final message =
            action == 'accept'
                ? 'Solicitud aceptada. ¡Ahora son amigos!'
                : 'Solicitud rechazada.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: action == 'accept' ? Colors.green : null,
          ),
        );
      } else {
         // Show generic failure message if service returned false
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('No se pudo ${action == 'accept' ? 'aceptar' : 'rechazar'} la solicitud.'),
             backgroundColor: Colors.red,
           )
         );
      }
    } catch (e) { // Catch any unexpected exceptions from the service call itself
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  /* // Comment out until UserService.cancelFriendRequest is available
  Future<void> _cancelSentRequest(String requestId) async {
    try {
      // Assuming a UserService method exists
      await _userService.cancelFriendRequest(requestId); 
      
      if (!mounted) return;
      
      // Reload sent requests list
      _loadSentRequests(); 

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solicitud cancelada'),
          backgroundColor: Colors.grey[600], // Neutral color
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cancelar: ${e.toString()}'),
          backgroundColor: Colors.red,
        )
      );
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
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
            style: TextStyle(fontSize: 16, color: Colors.grey),
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
              side: BorderSide(color: Colors.red.withOpacity(0.5)),
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
              side: BorderSide(color: Colors.green.withOpacity(0.5)),
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
            style: TextStyle(fontSize: 16, color: Colors.grey),
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
