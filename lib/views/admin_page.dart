import 'dart:convert';
import 'package:flutter/material.dart';
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

  int _drawIntervalSeconds = 4;
  double _price5Numbers = 10.0;
  double _price10Numbers = 25.0;
  double _priceFullHouse = 100.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  void _verifyAdminAccess() {
    if (_passwordController.text == "BingoAdmin2026") {
      setState(() => _isAuthenticated = true);
      _connectAdminSocket();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Security Token"), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _connectAdminSocket() {
    final targetRoom = _roomTargetController.text.trim().toUpperCase();
    final adminUrl = 'wss://bingo-multiplayer-backend.onrender.com/ws/$targetRoom/SystemAdmin';
    try {
      _adminChannel = WebSocketChannel.connect(Uri.parse(adminUrl));
    } catch (_) {}
  }

  void _broadcastGlobalRulesUpdate() {
    final targetRoom = _roomTargetController.text.trim().toUpperCase();
    final payload = {
      'action': 'update_room_rules',
      'target_room': targetRoom,
      'card_type': 'UK 90-Ball (3x9)',
      'draw_interval': _drawIntervalSeconds,
      'price_5_numbers': _price5Numbers,
      'price_10_numbers': _price10Numbers,
      'price_fullhouse': _priceFullHouse,
    };

    try {
      _adminChannel?.sink.add(jsonEncode(payload));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Rules pushed to $targetRoom"), backgroundColor: const Color(0xFF10B981)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send command: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
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
                    const Text("Master Admin Gate", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart), text: "Overview"),
            Tab(icon: Icon(Icons.meeting_room), text: "Room Rules"),
            Tab(icon: Icon(Icons.grid_on), text: "Card Layout"),
            Tab(icon: Icon(Icons.forum), text: "Broadcaster"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(bgCard, accentIndigo),
          _buildRoomsTab(bgCard, accentIndigo),
          _buildCardGeneratorTab(bgCard, accentIndigo),
          _buildChatModTab(bgCard, accentIndigo),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Color bgCard, Color accent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Card(color: bgCard, child: const Padding(padding: EdgeInsets.all(16.0), child: Text("Active Games: UK 90-Ball", style: TextStyle(color: Colors.white))))),
            ],
          )
        ],
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
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: '5 Numbers Prize (\$)', labelStyle: TextStyle(color: Colors.grey)),
                          onChanged: (v) => _price5Numbers = double.tryParse(v) ?? _price5Numbers,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: '10 Numbers Prize (\$)', labelStyle: TextStyle(color: Colors.grey)),
                          onChanged: (v) => _price10Numbers = double.tryParse(v) ?? _price10Numbers,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Full House (\$)', labelStyle: TextStyle(color: Colors.grey)),
                          onChanged: (v) => _priceFullHouse = double.tryParse(v) ?? _priceFullHouse,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text("Ball Draw Speed: $_drawIntervalSeconds seconds", style: const TextStyle(color: Colors.white)),
                  Slider(
                    value: _drawIntervalSeconds.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: accent,
                    onChanged: (val) => setState(() => _drawIntervalSeconds = val.toInt()),
                  ),
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
    return const Center(
      child: Text("UK 90-Ball (3x9) - Active Layout Standard", style: TextStyle(color: Colors.white)),
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
                children: [
                  TextField(
                    controller: _announcementController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Broadcast Announcement', labelStyle: TextStyle(color: Colors.grey)),
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