// lib/screens/friend_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../models/friend_request_model.dart';

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
      final result = await _userService.respondToFriendRequest(
        requestId,
        action,
      );

      // Check if widget is still mounted after async operation
      if (!mounted) return;

      if (result != null) {
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
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

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
            data: Theme.of(context).copyWith(splashColor: Color(0xFFFFD700)),
            child: TabBar(
              controller: _tabController,
              tabs: [Tab(text: 'Recibidas'), Tab(text: 'Enviadas')],
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorColor: Color(0xFFFFD700),
              labelColor: Colors.black,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No tienes solicitudes de amistad pendientes',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReceivedRequests,
      child: ListView.builder(
        itemCount: _receivedRequests.length,
        itemBuilder: (context, index) {
          final request = _receivedRequests[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        request.senderUsername,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _respondToRequest(request.id, 'accept'),
                        child: Text('Accept'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSentRequestsList() {
    if (_isLoadingSent) {
      return Center(child: CircularProgressIndicator());
    }

    if (_sentRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_disabled, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No has enviado solicitudes de amistad',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSentRequests,
      child: ListView.builder(
        itemCount: _sentRequests.length,
        itemBuilder: (context, index) {
          final request = _sentRequests[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(request.recipientUsername[0].toUpperCase()),
            ),
            title: Text(request.recipientUsername),
            subtitle: Text('@${request.recipientUsername}'),
            trailing: _getStatusChip(request.status),
          );
        },
      ),
    );
  }

  Widget _getStatusChip(String status) {
    Color chipColor;
    Icon chipIcon;
    String statusText;

    switch (status) {
      case 'pending':
        chipColor = Colors.orange;
        chipIcon = Icon(Icons.hourglass_empty, size: 16, color: Colors.white);
        statusText = 'Pendiente';
        break;
      case 'accepted':
        chipColor = Colors.green;
        chipIcon = Icon(Icons.check, size: 16, color: Colors.white);
        statusText = 'Aceptada';
        break;
      case 'rejected':
        chipColor = Colors.red;
        chipIcon = Icon(Icons.close, size: 16, color: Colors.white);
        statusText = 'Rechazada';
        break;
      default:
        chipColor = Colors.blue;
        chipIcon = Icon(Icons.info, size: 16, color: Colors.white);
        statusText = status;
    }

    return Chip(
      backgroundColor: chipColor,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chipIcon,
          SizedBox(width: 4),
          Text(statusText, style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
