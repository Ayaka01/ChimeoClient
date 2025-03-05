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

    final requests = await _userService.getReceivedFriendRequests(
      status: 'pending',
    );

    setState(() {
      _receivedRequests = requests;
      _isLoadingReceived = false;
    });
  }

  Future<void> _loadSentRequests() async {
    setState(() {
      _isLoadingSent = true;
    });

    final requests = await _userService.getSentFriendRequests();

    setState(() {
      _sentRequests = requests;
      _isLoadingSent = false;
    });
  }

  Future<void> _respondToRequest(String requestId, String action) async {
    try {
      // Store mounted state before async operation
      final isWidgetMounted = mounted;

      final result = await _userService.respondToFriendRequest(
        requestId,
        action,
      );

      // Check if widget is still mounted after async operation
      if (!isWidgetMounted) return;

      if (result != null) {
        // Reload the lists
        _loadReceivedRequests();
        _loadSentRequests();

        // Show success message
        final message =
            action == 'accept'
                ? 'Solicitud aceptada. ¡Ahora son amigos!'
                : 'Solicitud rechazada.';

        // Check context is still valid before using ScaffoldMessenger
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    } catch (e) {
      // Check if widget is still mounted before showing error
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Solicitudes de amistad'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [Tab(text: 'Recibidas'), Tab(text: 'Enviadas')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildReceivedRequestsList(), _buildSentRequestsList()],
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
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          request.sender.displayName[0].toUpperCase(),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.sender.displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('@${request.sender.username}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            () => _respondToRequest(request.id, 'reject'),
                        child: Text(
                          'Rechazar',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed:
                            () => _respondToRequest(request.id, 'accept'),
                        child: Text('Aceptar'),
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
              child: Text(request.recipient.displayName[0].toUpperCase()),
            ),
            title: Text(request.recipient.displayName),
            subtitle: Text('@${request.recipient.username}'),
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
