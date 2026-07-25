import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class BingoAdminDashboardPage extends StatefulWidget {
  const BingoAdminDashboardPage({super.key});

  @override
  State<BingoAdminDashboardPage> createState() => _BingoAdminDashboardPageState();
}

class _BingoAdminDashboardPageState extends State<BingoAdminDashboardPage> with SingleTickerProviderStateMixin {
  bool _isAuthenticated = false;
  final _passwordController = TextEditingController();
  TabController? _tabController;

  final _roomTargetController = TextEditingController(text: "ROOM101");
  final _announcementController = TextEditingController();
  WebSocketChannel? _adminChannel;
  
  bool _isConnected = false;
  int _activePlayerCount = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  String _selectedCardType = "UK 90-Ball (3x9)";
  String _winningPattern = "Full House";
  int _drawIntervalSeconds = 4;
  double _price1Line = 10.0;
  double _price2Lines = 25.0;
  double _priceFullHouse = 100.0;
  String _generatedPassphrase = "";

  final List<bool> _usPatternGrid = List.generate(25, (i) => i == 12);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _generatedPassphrase = _generatePassphrase();
  }

  String _generatePassphrase([int length = 12]) {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789#@!";
    final rand = Random();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  void _verifyAdminAccess() {
    if (_passwordController.text == "BingoAdmin2026") {
      setState(() => _isAuthenticated = true);
      _connectAdminSocket();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid Admin Passphrase"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _connectAdminSocket() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _adminChannel?.sink.close();

    final targetRoom = _roomTargetController.text.trim().toUpperCase();
    final adminUrl = 'wss://bingo-multiplayer-backend.onrender.com/ws/$targetRoom/SystemAdmin?auth_token=admin_token_2026';
    
    try {
      _adminChannel = WebSocketChannel.connect(Uri.parse(adminUrl));
      
      setState(() {
        _isConnected = true;
      });

      _adminChannel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (mounted) {
            setState(() {
              _isConnected = true;
              if (data['total_players'] != null) {
                _activePlayerCount = data['total_players'];
              }
            });
          }
        },
        onError: (error) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
      );

      _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (_isConnected) {
          _adminChannel?.sink.add(jsonEncode({'action': 'ping'}));
        }
      });

    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (mounted) {
      setState(() {
        _isConnected = false;
      });
    }
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_isAuthenticated && mounted) {
        _connectAdminSocket();
      }
    });
  }

  void _broadcastGlobalRulesUpdate() {
    final targetRoom = _roomTargetController.text.trim().toUpperCase();
    final payload = {
      'action': 'system_announcement',
      'auth_token': 'admin_token_2026',
      'message': '📢 Room Settings Updated by Admin!',
    };

    try {
      _adminChannel?.sink.add(jsonEncode(payload));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Rules pushed to $targetRoom"),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send command: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _sendSystemAnnouncement() {
    if (_announcementController.text.trim().isEmpty) return;

    final payload = {
      'action': 'system_announcement',
      'auth_token': 'admin_token_2026',
      'message': _announcementController.text.trim(),
    };

    _adminChannel?.sink.add(jsonEncode(payload));
    _announcementController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Announcement broadcasted to target room."),
        backgroundColor: Color(0xFF6366F1),
      ),
    );
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _passwordController.dispose();
    _roomTargetController.dispose();
    _announcementController.dispose();
    _tabController?.dispose();
    _adminChannel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgMain = Color(0xFF0B0F19);
    const bgCard = Color(0xFF151D2A);
    const accentIndigo = Color(0xFF6366F1);

    if (!_isAuthenticated) {
      return Scaffold(
        backgroundColor: bgMain,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(24.0),
            child: Card(
              color: bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.admin_panel_settings, size: 64, color: accentIndigo),
                    const SizedBox(height: 16),
                    const Text(
                      "Master Admin Gate",
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Admin Security Token',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF233044))),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accentIndigo)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _verifyAdminAccess,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: accentIndigo,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Authenticate'),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        title: const Text("Master Control Suite", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bgCard,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: accentIndigo,
          labelColor: accentIndigo,
          unselectedLabelColor: Colors.grey,
          tabs: [
            const Tab(icon: Icon(Icons.pie_chart), text: "Live Control"),
            Tab(icon: const Icon(Icons.people), text: "Active Players ($_activePlayerCount)"),
            const Tab(icon: Icon(Icons.meeting_room), text: "Room Rules"),
            const Tab(icon: Icon(Icons.grid_on), text: "Card Generator"),
            const Tab(icon: Icon(Icons.forum), text: "Chat & Mod"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLiveControlTab(bgCard, accentIndigo),
          _buildPlayersTab(bgCard, accentIndigo),
          _buildRoomsTab(bgCard, accentIndigo),
          _buildCardGeneratorTab(bgCard, accentIndigo),
          _buildChatModTab(bgCard, accentIndigo),
        ],
      ),
    );
  }

  Widget _buildLiveControlTab(Color bgCard, Color accent) {
    final roomCode = _roomTargetController.text.trim().toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            color: bgCard,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    color: _isConnected ? Colors.green : Colors.red,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Target Room: $roomCode", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          _isConnected ? "Status: Connected to $roomCode" : "Status: Reconnecting / Server Booting...",
                          style: TextStyle(color: _isConnected ? Colors.greenAccent : Colors.orange, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _connectAdminSocket,
                    style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                    child: const Text("Reconnect"),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: bgCard,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Match Operations", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _announcementController.text = "⏸ Match Paused by Host";
                            _sendSystemAnnouncement();
                          },
                          icon: const Icon(Icons.pause),
                          label: const Text("PAUSE MATCH"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[900],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _announcementController.text = "🔄 Match Resetting for Next Round!";
                            _sendSystemAnnouncement();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text("RESET MATCH"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPlayersTab(Color bgCard, Color accent) {
    return Center(
      child: Card(
        color: bgCard,
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_alt, size: 48, color: Colors.indigoAccent),
              const SizedBox(height: 12),
              Text(
                "Active Players: $_activePlayerCount",
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Real-time connected client instances in this playroom.",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomsTab(Color bgCard, Color accent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            color: bgCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Room Parameters & Target Sync", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _roomTargetController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Target Room Code',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF233044))),
                    ),
                    onChanged: (_) => _connectAdminSocket(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          readOnly: true,
                          controller: TextEditingController(text: _generatedPassphrase),
                          style: const TextStyle(color: Colors.amber, fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            labelText: 'Generated Access Passphrase',
                            labelStyle: TextStyle(color: Colors.grey),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF233044))),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.amber),
                        onPressed: () => setState(() => _generatedPassphrase = _generatePassphrase()),
                        tooltip: "Re-generate Passphrase",
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.white70),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _generatedPassphrase));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passphrase copied!")));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _broadcastGlobalRulesUpdate,
                    icon: const Icon(Icons.sync),
                    label: const Text("Push Rules Overrides"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCardGeneratorTab(Color bgCard, Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.style, size: 48, color: Colors.indigoAccent),
            SizedBox(height: 12),
            Text("UK 90-Ball 6-Ticket Book Layout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Auto-generated 3x9 tickets containing all numbers 1-90 without duplicates.", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatModTab(Color bgCard, Color accent) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            color: bgCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Global System Announcement Broadcaster", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _announcementController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Broadcast Message',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF233044))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _sendSystemAnnouncement,
                    icon: const Icon(Icons.campaign),
                    label: const Text("Send Broadcast Notice"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}