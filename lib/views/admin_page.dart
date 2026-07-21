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

  // Real-time WebSocket Controls
  final _roomTargetController = TextEditingController(text: "ROOM101");
  final _announcementController = TextEditingController();
  WebSocketChannel? _adminChannel;

  // Room Parameters & State
  String _selectedCardType = "UK 90-Ball (3x9)";
  String _winningPattern = "Full House";
  int _drawIntervalSeconds = 4;
  double _price1Line = 10.0;
  double _price2Lines = 25.0;
  double _priceFullHouse = 100.0;
  String _generatedPassphrase = "";

  // Live Room Stats (Received via WebSocket)
  int _activePlayerCount = 0;
  List<String> _connectedPlayers = [];
  List<int> _callHistory = [];
  bool _isGamePaused = false;
  final List<Map<String, dynamic>> _winnerLogs = [];

  // Interactive Pattern Grid (5x5 for US / Custom Patterns)
  final List<bool> _customPatternGrid = List.generate(25, (i) => i == 12);

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
    final targetRoom = _roomTargetController.text.trim().toUpperCase();
    final adminUrl = 'wss://bingo-multiplayer-backend.onrender.com/ws/$targetRoom/MasterAdmin';
    try {
      _adminChannel?.sink.close();
      _adminChannel = WebSocketChannel.connect(Uri.parse(adminUrl));
      _adminChannel!.stream.listen((message) {
        final data = jsonDecode(message);
        _handleAdminSocketEvents(data);
      }, onError: (_) {}, onDone: () {});
    } catch (_) {}
  }

  void _handleAdminSocketEvents(Map<String, dynamic> data) {
    setState(() {
      switch (data['event']) {
        case 'player_joined':
          _activePlayerCount = data['total_players'] ?? (_activePlayerCount + 1);
          if (data['username'] != null && !_connectedPlayers.contains(data['username'])) {
            _connectedPlayers.add(data['username']);
          }
          break;
        case 'number_drawn':
          if (data['number'] != null) {
            _callHistory.insert(0, data['number']);
          }
          break;
        case 'game_over':
          if (data['winner'] != null) {
            _winnerLogs.insert(0, {
              'player': data['winner'],
              'format': _selectedCardType,
              'room': _roomTargetController.text,
              'prize': '\$${_priceFullHouse.toStringAsFixed(2)}',
              'time': DateTime.now().toIso8601String().substring(11, 16),
            });
          }
          break;
      }
    });
  }

  void _sendAdminAction(String action, Map<String, dynamic> payload) {
    final fullPayload = {
      'action': action,
      'admin_secret': 'BingoAdmin2026',
      'target_room': _roomTargetController.text.trim().toUpperCase(),
      ...payload
    };
    try {
      _adminChannel?.sink.add(jsonEncode(fullPayload));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send command: $e"), backgroundColor: Colors.red),
      );
    }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Rules & Prize Pools pushed to ${_roomTargetController.text.toUpperCase()}"),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _sendSystemAnnouncement() {
    if (_announcementController.text.trim().isEmpty) return;
    _sendAdminAction('system_announcement', {
      'message': _announcementController.text.trim(),
    });
    _announcementController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Announcement broadcasted successfully."),
        backgroundColor: Color(0xFF6366F1),
      ),
    );
  }

  void _kickPlayer(String username) {
    _sendAdminAction('kick_player', {'player_to_kick': username});
    setState(() => _connectedPlayers.remove(username));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Kicked $username from room.")),
    );
  }

  void _togglePauseGame() {
    setState(() => _isGamePaused = !_isGamePaused);
    _sendAdminAction(_isGamePaused ? 'pause_game' : 'resume_game', {});
  }

  void _forceDrawNextBall() {
    _sendAdminAction('force_draw', {});
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
                      onSubmitted: (_) => _verifyAdminAccess(),
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
            Tab(icon: Icon(Icons.meeting_room), text: "Rooms"),
            Tab(icon: Icon(Icons.emoji_events), text: "Rules & Patterns"),
            Tab(icon: Icon(Icons.grid_on), text: "Card Generator"),
            Tab(icon: Icon(Icons.forum), text: "Chat & Mod"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(bgCard, accentIndigo),
          _buildRoomsTab(bgCard, accentIndigo),
          _buildRulesTab(bgCard, accentIndigo),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statCard("Active Room Players", "$_activePlayerCount", Colors.white, bgCard),
              const SizedBox(width: 12),
              _statCard("Target Room", _roomTargetController.text, accent, bgCard),
              const SizedBox(width: 12),
              _statCard("Total Balls Drawn", "${_callHistory.length}", Colors.amber, bgCard),
              const SizedBox(width: 12),
              _statCard("Est. Prize Pool", "\$${(_price1Line + _price2Lines + _priceFullHouse).toStringAsFixed(0)}", const Color(0xFF10B981), bgCard),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: bgCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Quick Action Game Controls", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _togglePauseGame,
                        icon: Icon(_isGamePaused ? Icons.play_arrow : Icons.pause),
                        label: Text(_isGamePaused ? "Resume Draw" : "Pause Draw"),
                        style: ElevatedButton.styleFrom(backgroundColor: _isGamePaused ? Colors.green : Colors.orange[800], foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _forceDrawNextBall,
                        icon: const Icon(Icons.skip_next),
                        label: const Text("Force Next Ball"),
                        style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: bgCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Live Winners Log", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _winnerLogs.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("No winners logged for this session yet.", style: TextStyle(color: Colors.grey)),
                        )
                      : DataTable(
                          columns: const [
                            DataColumn(label: Text("Player", style: TextStyle(color: Colors.grey))),
                            DataColumn(label: Text("Format", style: TextStyle(color: Colors.grey))),
                            DataColumn(label: Text("Room", style: TextStyle(color: Colors.grey))),
                            DataColumn(label: Text("Prize Won", style: TextStyle(color: Colors.grey))),
                            DataColumn(label: Text("Time", style: TextStyle(color: Colors.grey))),
                          ],
                          rows: _winnerLogs
                              .map(
                                (log) => DataRow(cells: [
                                  DataCell(Text(log['player'] ?? '', style: const TextStyle(color: Colors.white))),
                                  DataCell(Text(log['format'] ?? '', style: const TextStyle(color: Colors.indigoAccent))),
                                  DataCell(Text(log['room'] ?? '', style: const TextStyle(color: Colors.white70))),
                                  DataCell(Text(log['prize'] ?? '', style: const TextStyle(color: Color(0xFF10B981)))),
                                  DataCell(Text(log['time'] ?? '', style: const TextStyle(color: Colors.grey))),
                                ]),
                              )
                              .toList(),
                        ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, Color valColor, Color bgCard) {
    return Expanded(
      child: Card(
        color: bgCard,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(color: valColor, fontSize: 18, fontWeight: FontWeight.bold)),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: '1 Line Prize (\$)', labelStyle: TextStyle(color: Colors.grey)),
                          onChanged: (v) => _price1Line = double.tryParse(v) ?? _price1Line,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: '2 Lines Prize (\$)', labelStyle: TextStyle(color: Colors.grey)),
                          onChanged: (v) => _price2Lines = double.tryParse(v) ?? _price2Lines,
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
                    label: const Text("Push Rules & Speed Overrides"),
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
                  const Text("Winning Pattern Configuration", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _winningPattern,
                    dropdownColor: bgCard,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Active Win Rule", labelStyle: TextStyle(color: Colors.grey)),
                    items: ["Full House", "Single Line", "Two Lines", "Custom Pattern Grid"]
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (val) => setState(() => _winningPattern = val!),
                  ),
                  const SizedBox(height: 16),
                  if (_winningPattern == "Custom Pattern Grid") ...[
                    const Text("Custom 5x5 Grid Designer", style: TextStyle(color: Colors.white, fontSize: 13)),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 4, mainAxisSpacing: 4),
                      itemCount: 25,
                      itemBuilder: (context, idx) {
                        bool isFree = idx == 12;
                        bool isSelected = _customPatternGrid[idx];
                        return GestureDetector(
                          onTap: isFree ? null : () => setState(() => _customPatternGrid[idx] = !_customPatternGrid[idx]),
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
                    ),
                  ],
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
            Icon(Icons.style, size: 56, color: Colors.indigoAccent),
            SizedBox(height: 12),
            Text("UK 90-Ball 6-Ticket Sheet Generator", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Automatically creates 6 contiguous 3x9 tickets containing numbers 1-90 without duplicates.", style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildChatModTab(Color bgCard, Color accent) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
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
            ),
            const SizedBox(height: 16),
            Card(
              color: bgCard,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Connected Room Players", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _connectedPlayers.isEmpty
                        ? const Text("No active players connected in room state.", style: TextStyle(color: Colors.grey, fontSize: 12))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _connectedPlayers.length,
                            itemBuilder: (context, idx) {
                              final p = _connectedPlayers[idx];
                              return ListTile(
                                dense: true,
                                title: Text(p, style: const TextStyle(color: Colors.white)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.person_remove, color: Colors.redAccent, size: 20),
                                  onPressed: () => _kickPlayer(p),
                                  tooltip: "Kick Player",
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}