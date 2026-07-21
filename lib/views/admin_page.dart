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

  // Active Real-time Controls
  final _roomTargetController = TextEditingController(text: "ROOM101");
  final _announcementController = TextEditingController();
  WebSocketChannel? _adminChannel;

  // Real-time Room State Tracking
  bool _isConnected = false;
  bool _isGamePaused = false;
  String _lastServerEvent = "Disconnected";

  // Room Form Parameters
  String _selectedCardType = "UK 90-Ball (3x9)";
  String _winningPattern = "Full House";
  int _drawIntervalSeconds = 4;
  double _price1Line = 10.0;
  double _price2Lines = 25.0;
  double _priceFullHouse = 100.0;
  String _generatedPassphrase = "";

  // Pattern Designer State (US 75-Ball 5x5 Grid)
  final List<bool> _usPatternGrid = List.generate(25, (i) => i == 12);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    _adminChannel?.sink.close();
    final targetRoom = _roomTargetController.text.trim().toUpperCase();
    final adminUrl = 'wss://bingo-multiplayer-backend.onrender.com/ws/$targetRoom/MasterAdmin';
    
    try {
      _adminChannel = WebSocketChannel.connect(Uri.parse(adminUrl));
      setState(() {
        _isConnected = true;
        _lastServerEvent = "Connected to $targetRoom";
      });

      _adminChannel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          setState(() {
            _lastServerEvent = data['event'] ?? 'message_received';
            if (data['event'] == 'game_paused') _isGamePaused = true;
            if (data['event'] == 'game_resumed') _isGamePaused = false;
          });
        },
        onError: (err) {
          setState(() => _isConnected = false);
        },
        onDone: () {
          setState(() => _isConnected = false);
        },
      );
    } catch (_) {
      setState(() => _isConnected = false);
    }
  }

  void _sendAdminAction(String action, [Map<String, dynamic>? extraData]) {
    if (!_isConnected || _adminChannel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Admin Socket is not connected to a room!"), backgroundColor: Colors.red),
      );
      return;
    }

    final targetRoom = _roomTargetController.text.trim().toUpperCase();
    final payload = {
      'action': action,
      'admin_secret': 'BingoAdmin2026',
      'target_room': targetRoom,
      ...?extraData,
    };

    _adminChannel?.sink.add(jsonEncode(payload));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Command '$action' sent to $targetRoom"),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _togglePauseGame() {
    if (_isGamePaused) {
      _sendAdminAction('resume_game');
      setState(() => _isGamePaused = false);
    } else {
      _sendAdminAction('pause_game');
      setState(() => _isGamePaused = true);
    }
  }

  void _resetGamePrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151D2A),
        title: const Text("Confirm Match Reset", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This action will clear all drawn numbers, reset all player daubs, and start a fresh round. Continue?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _sendAdminAction('reset_game');
            },
            child: const Text("Reset Match", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _broadcastGlobalRulesUpdate() {
    _sendAdminAction('update_room_rules', {
      'card_type': _selectedCardType,
      'winning_pattern': _winningPattern,
      'draw_interval': _drawIntervalSeconds,
      'price_1line': _price1Line,
      'price_2lines': _price2Lines,
      'price_fullhouse': _priceFullHouse,
      'passphrase': _generatedPassphrase,
    });
  }

  void _sendSystemAnnouncement() {
    if (_announcementController.text.trim().isEmpty) return;
    _sendAdminAction('system_announcement', {
      'message': _announcementController.text.trim(),
    });
    _announcementController.clear();
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
          indicatorColor: accentIndigo,
          labelColor: accentIndigo,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.play_circle_filled), text: "Live Control"),
            Tab(icon: Icon(Icons.meeting_room), text: "Room Rules"),
            Tab(icon: Icon(Icons.grid_on), text: "Pattern Studio"),
            Tab(icon: Icon(Icons.campaign), text: "Broadcaster"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLiveControlTab(bgCard, accentIndigo),
          _buildRoomsTab(bgCard, accentIndigo),
          _buildRulesTab(bgCard, accentIndigo),
          _buildChatModTab(bgCard, accentIndigo),
        ],
      ),
    );
  }

  Widget _buildLiveControlTab(Color bgCard, Color accent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection & Status Banner
          Card(
            color: bgCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.sensors : Icons.sensors_off,
                    color: _isConnected ? Colors.greenAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Target Room: ${_roomTargetController.text.toUpperCase()}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          "Last Event: $_lastServerEvent",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _connectAdminSocket,
                    style: ElevatedButton.styleFrom(backgroundColor: accent),
                    child: const Text("Reconnect", style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Pause / Resume / Reset Action Grid
          Card(
            color: bgCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Match Operations", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _togglePauseGame,
                          icon: Icon(_isGamePaused ? Icons.play_arrow : Icons.pause),
                          label: Text(_isGamePaused ? "RESUME MATCH" : "PAUSE MATCH"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isGamePaused ? Colors.green : Colors.orange[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _resetGamePrompt,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text("RESET MATCH"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCardType,
                    dropdownColor: bgCard,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Card Type Layout", labelStyle: TextStyle(color: Colors.grey)),
                    items: ["UK 90-Ball (3x9)", "US 75-Ball (5x5)"]
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCardType = val!),
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

  Widget _buildRulesTab(Color bgCard, Color accent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: bgCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("US 75-Ball Pattern Grid Designer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 4, mainAxisSpacing: 4),
                    itemCount: 25,
                    itemBuilder: (context, idx) {
                      bool isFree = idx == 12;
                      bool isSelected = _usPatternGrid[idx];
                      return GestureDetector(
                        onTap: isFree ? null : () => setState(() => _usPatternGrid[idx] = !_usPatternGrid[idx]),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isFree ? Colors.amber : (isSelected ? accent : Colors.black26),
                            border: Border.all(color: Colors.grey.shade800),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isFree ? "FREE" : "${idx + 1}",
                            style: TextStyle(color: isFree ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  )
                ],
              ),
            ),
          )
        ],
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