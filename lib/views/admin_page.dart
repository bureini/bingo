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

  // Real-time Controls
  final _roomTargetController = TextEditingController(text: "ROOM101");
  final _announcementController = TextEditingController();
  WebSocketChannel? _adminChannel;

  // Room Form Parameters
  String _selectedCardType = "UK 90-Ball (3x9)";
  String _winningPattern = "Full House";
  int _drawIntervalSeconds = 4;
  double _price1Line = 10.0;
  double _price2Lines = 25.0;
  double _priceFullHouse = 100.0;
  String _generatedPassphrase = "";

  // Pattern Designer State
  List<bool> _usPatternGrid = List.generate(25, (i) => i == 12);
  List<bool> _ukPatternGrid = List.generate(27, (_) => false);

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
          content: Text("Invalid Admin Security Token"),
          backgroundColor: Colors.redAccent,
        ),
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
      'admin_secret': 'BingoAdmin2026',
      'target_room': targetRoom,
      'card_type': _selectedCardType,
      'winning_pattern': _winningPattern,
      'draw_interval': _drawIntervalSeconds,
      'price_1line': _price1Line,
      'price_2lines': _price2Lines,
      'price_fullhouse': _priceFullHouse,
      'passphrase': _generatedPassphrase,
    };

    try {
      _adminChannel?.sink.add(jsonEncode(payload));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Rules & Prize Pools pushed to $targetRoom"),
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
      'admin_secret': 'BingoAdmin2026',
      'message': _announcementController.text.trim(),
    };

    _adminChannel?.sink.add(jsonEncode(payload));
    _announcementController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Announcement broadcasted to all connected players."),
        backgroundColor: Color(0xFF6366F1),
      ),
    );
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
                        labelText: 'Admin Passphrase',
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

  // --- TAB 1: OVERVIEW ---
  Widget _buildOverviewTab(Color bgCard, Color accent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              _statCard("Active Players", "2,841", Colors.white, bgCard),
              const SizedBox(width: 12),
              _statCard("US Rooms", "5 Active", accent, bgCard),
              const SizedBox(width: 12),
              _statCard("UK Rooms", "4 Active", Colors.amber, bgCard),
              const SizedBox(width: 12),
              _statCard("Revenue", "\$8,910", const Color(0xFF10B981), bgCard),
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
                  const Text("Recent Winners Log", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DataTable(
                    columns: const [
                      DataColumn(label: Text("Player", style: TextStyle(color: Colors.grey))),
                      DataColumn(label: Text("Format", style: TextStyle(color: Colors.grey))),
                      DataColumn(label: Text("Room", style: TextStyle(color: Colors.grey))),
                      DataColumn(label: Text("Prize Won", style: TextStyle(color: Colors.grey))),
                    ],
                    rows: const [
                      DataRow(cells: [
                        DataCell(Text("JohnDoe99", style: TextStyle(color: Colors.white))),
                        DataCell(Text("US 75-Ball", style: TextStyle(color: Colors.indigoAccent))),
                        DataCell(Text("Liberty Bell 75", style: TextStyle(color: Colors.white70))),
                        DataCell(Text("\$35.00 (2 Lines)", style: TextStyle(color: Color(0xFF10B981)))),
                      ]),
                      DataRow(cells: [
                        DataCell(Text("Emma_UK", style: TextStyle(color: Colors.white))),
                        DataCell(Text("UK 90-Ball", style: TextStyle(color: Colors.amber))),
                        DataCell(Text("Royal Crown UK 90", style: TextStyle(color: Colors.white70))),
                        DataCell(Text("\$350.00 (Full House)", style: TextStyle(color: Color(0xFF10B981)))),
                      ]),
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

  // --- TAB 2: ROOM MANAGEMENT ---
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

  // --- TAB 3: RULES & PATTERNS ---
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
                  const Text("US 75-Ball 5x5 Pattern Grid Designer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // --- TAB 4: CARD GENERATOR PREVIEW ---
  Widget _buildCardGeneratorTab(Color bgCard, Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.style, size: 48, color: Colors.indigoAccent),
            const SizedBox(height: 12),
            const Text("UK 90-Ball 6-Ticket Book Layout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Auto-generated 3x9 tickets containing all numbers 1-90 without duplicates.", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // --- TAB 5: CHAT & MODERATION ---
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