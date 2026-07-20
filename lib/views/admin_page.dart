import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class BingoAdminDashboardPage extends StatefulWidget {
  const BingoAdminDashboardPage({super.key});

  @override
  State<BingoAdminDashboardPage> createState() => _BingoAdminDashboardPageState();
}

class _BingoAdminDashboardPageState extends State<BingoAdminDashboardPage> {
  bool _isAuthenticated = false;
  final _passwordController = TextEditingController();
  final _roomTargetController = TextEditingController(text: "ROOM101");
  final _announcementController = TextEditingController();

  String _selectedCardType = "90-Ball (6-Ticket Book)";
  String _winningPattern = "Full House";
  int _drawIntervalSeconds = 4;
  WebSocketChannel? _adminChannel;

  void _verifyAdminAccess() {
    // Basic Passphrase Check
    if (_passwordController.text == "BingoAdmin2026") {
      setState(() => _isAuthenticated = true);
      _connectAdminSocket();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Admin Security Token")),
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
    };

    try {
      _adminChannel?.sink.add(jsonEncode(payload));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Rules and Speed pushed to $targetRoom"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send command: $e")),
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
      const SnackBar(content: Text("Announcement sent to all players.")),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _roomTargetController.dispose();
    _announcementController.dispose();
    _adminChannel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text("Admin Security Gate")),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 350),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings, size: 64, color: Colors.indigo),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Admin Security Token',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _verifyAdminAccess,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Authenticate'),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bingo Control Center"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ROOM TARGET SELECTION ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Room Target Management", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _roomTargetController,
                      decoration: const InputDecoration(
                        labelText: 'Target Room Code',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.meeting_room),
                      ),
                      onChanged: (_) => _connectAdminSocket(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- GAME RULES & WINNING LOGIC OVERRIDES ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Winning Logic & Card Variants", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedCardType,
                      decoration: const InputDecoration(labelText: "Card Type Layout", border: OutlineInputBorder()),
                      items: ["90-Ball (6-Ticket Book)", "75-Ball (Single Grid)"]
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedCardType = val!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _winningPattern,
                      decoration: const InputDecoration(labelText: "Active Winning Rule", border: OutlineInputBorder()),
                      items: ["Full House", "1 Line", "2 Lines", "Corner Pattern"]
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) => setState(() => _winningPattern = val!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- BALL DRAW SPEED CONTROL ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Ball Draw Speed Tempo: $_drawIntervalSeconds seconds", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Slider(
                      value: _drawIntervalSeconds.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: "$_drawIntervalSeconds sec",
                      onChanged: (val) => setState(() => _drawIntervalSeconds = val.toInt()),
                    ),
                    ElevatedButton.icon(
                      onPressed: _broadcastGlobalRulesUpdate,
                      icon: const Icon(Icons.sync),
                      label: const Text("Apply Rules to Room"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- SYSTEM ANNOUNCEMENT BROADCASTER ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Broadcast System Announcement", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _announcementController,
                      decoration: const InputDecoration(
                        labelText: 'Message to all connected players',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _sendSystemAnnouncement,
                      icon: const Icon(Icons.campaign),
                      label: const Text("Send Announcement"),
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
          ],
        ),
      ),
    );
  }
}
