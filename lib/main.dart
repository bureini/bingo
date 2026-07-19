import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const BingoApp());
}

class BingoApp extends StatelessWidget {
  const BingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Bingo Arena',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const BingoJoinLobbyPage(),
    );
  }
}

class BingoJoinLobbyPage extends StatefulWidget {
  const BingoJoinLobbyPage({super.key});

  @override
  State<BingoJoinLobbyPage> createState() => _BingoJoinLobbyPageState();
}

class _BingoJoinLobbyPageState extends State<BingoJoinLobbyPage> {
  final _roomController = TextEditingController(text: "ROOM101");
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _roomController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _navigateToRoom() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BingoGamePage(
            roomId: _roomController.text.trim().toUpperCase(),
            username: _nameController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Admin Gateway: Long-press this controller icon for 2 seconds to launch the override UI[cite: 6]
                    GestureDetector(
                      onLongPress: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BingoAdminDashboardPage()),
                        );
                      },
                      child: const Icon(Icons.sports_esports, size: 64, color: Colors.indigo),
                    ),
                    const SizedBox(height: 16),
                    const Text('My Bingo (6-Tickets)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _roomController,
                      decoration: const InputDecoration(labelText: 'Room Code', border: OutlineInputBorder()),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter room code' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _navigateToRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Join Playroom'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BingoAdminDashboardPage extends StatefulWidget {
  const BingoAdminDashboardPage({super.key});

  @override
  State<BingoAdminDashboardPage> createState() => _BingoAdminDashboardPageState();
}

class _BingoAdminDashboardPageState extends State<BingoAdminDashboardPage> {
  bool _isAuthenticated = false;
  final _passwordController = TextEditingController();
  final _roomTargetController = TextEditingController(text: "ROOM101");
  String _selectedCardType = "90-Ball (6-Ticket Book)";
  int _drawIntervalSeconds = 4;

  void _verifyAdminAccess() {
    if (_passwordController.text == "BingoAdmin2026") {
      setState(() => _isAuthenticated = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Admin Passphrase")));
    }
  }

  void _broadcastGlobalRulesUpdate() {
    final targetRoom = _roomTargetController.text.trim().toUpperCase();
    final adminUrl = 'wss://bingo-multiplayer-backend.onrender.com/ws/$targetRoom/SystemAdmin';
    try {
      final channel = WebSocketChannel.connect(Uri.parse(adminUrl));
      channel.sink.add(jsonEncode({
        'action': 'update_room_rules',
        'admin_secret': 'BingoAdmin2026',
        'card_type': _selectedCardType,
        'draw_interval': _drawIntervalSeconds,
      }));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rules pushed to room $targetRoom"), backgroundColor: Colors.green));
      Future.delayed(const Duration(seconds: 1), () => channel.sink.close());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _roomTargetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text("Admin Access Gate")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Security Token', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _verifyAdminAccess, child: const Text('Authenticate'))
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text("Game Rules Control UI")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: _roomTargetController, decoration: const InputDecoration(labelText: 'Target Room ID', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCardType,
              decoration: const InputDecoration(labelText: "Layout Selection", border: OutlineInputBorder()),
              items: ["90-Ball (6-Ticket Book)"]
                  .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _selectedCardType = val!),
            ),
            const SizedBox(height: 16),
            Slider(value: _drawIntervalSeconds.toDouble(), min: 2, max: 15, divisions: 13, onChanged: (val) => setState(() => _drawIntervalSeconds = val.toInt())),
            ListTile(title: Text("Draw Speed Tempo: $_drawIntervalSeconds sec")),
            ElevatedButton(onPressed: _broadcastGlobalRulesUpdate, child: const Text("Apply Dynamic Overrides")),
          ],
        ),
      ),
    );
  }
}

class BingoGamePage extends StatefulWidget {
  final String roomId;
  final String username;
  const BingoGamePage({super.key, required this.roomId, required this.username});

  @override
  State<BingoGamePage> createState() => _BingoGamePageState();
}

class _BingoGamePageState extends State<BingoGamePage> {
  List<List<List<bool>>> _bookDaubedStates = List.generate(6, (_) => List.generate(3, (_) => List.filled(9, false)));
  List<List<List<dynamic>>> _ticketBookNumbers = List.generate(6, (_) => List.generate(3, (_) => List.filled(9, 0)));
  WebSocketChannel? _channel;
  final List<int> _drawnNumbers = [];
  int? _currentDrawnNumber;
  String _gameStatusMessage = "Connecting...";

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    final wsUrl = 'wss://bingo-multiplayer-backend.onrender.com/ws/${widget.roomId}/${widget.username}';
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.stream.listen((message) {
        final data = jsonDecode(message);
        switch (data['event']) {
          case 'card_assigned':
            setState(() {
              _ticketBookNumbers = List<List<List<dynamic>>>.from(data['book']);
              _bookDaubedStates = List.generate(6, (_) => List.generate(3, (_) => List.filled(9, false)));
              _gameStatusMessage = "Room Connected: ${data['room_id']}";
            });
            break;
          case 'game_started':
            setState(() => _gameStatusMessage = "🎮 Game Live!");
            break;
          case 'number_drawn':
            setState(() {
              _currentDrawnNumber = data['number'];
              _drawnNumbers.clear();
              _drawnNumbers.addAll(List<int>.from(data['history']));
            });
            break;
          case 'room_rules_changed':
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
            break;
          case 'game_over':
            setState(() => _gameStatusMessage = data['winner'] != null ? "🏆 Winner: ${data['winner']}!" : "Game Over");
            break;
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bingo Playroom'), backgroundColor: Colors.indigo, foregroundColor: Colors.white, centerTitle: true),
      body: Column(
        children: [
          Container(width: double.infinity, color: Colors.indigo[900], padding: const EdgeInsets.all(8), child: Text(_gameStatusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  CircleAvatar(radius: 28, backgroundColor: Colors.amber[700], child: Text(_currentDrawnNumber != null ? '$_currentDrawnNumber' : '--', style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold))),
                  Text("Balls Called: ${_drawnNumbers.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: 6,
              itemBuilder: (context, ticketIndex) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 24.0), // Corrected framework padding constructor[cite: 6]
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
                        child: Text(
                          "TICKET ${ticketIndex + 1}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo[900], fontSize: 14, letterSpacing: 1.2),
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: AspectRatio(
                          aspectRatio: 9 / 3.2,
                          child: Table(
                            border: TableBorder.all(color: Colors.grey.shade400, width: 1.2),
                            children: List.generate(3, (r) {
                              return TableRow(
                                children: List.generate(9, (c) {
                                  var cellVal = _ticketBookNumbers[ticketIndex][r][c];
                                  String displayText = (cellVal == 0) ? "" : cellVal.toString();
                                  bool isDaubed = _bookDaubedStates[ticketIndex][r][c];
                                  
                                  return GestureDetector(
                                    onTap: () {
                                      if (displayText.isNotEmpty) {
                                        setState(() => _bookDaubedStates[ticketIndex][r][c] = !isDaubed);
                                      }
                                    },
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: Container(
                                        color: displayText.isEmpty ? Colors.grey.shade200 : Colors.white,
                                        alignment: Alignment.center,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Text(displayText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                            if (isDaubed && displayText.isNotEmpty)
                                              Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle, // Corrected framework shape property[cite: 6]
                                                  color: Colors.blue.withOpacity(0.45),
                                                  border: Border.all(color: Colors.blueAccent, width: 1)
                                                ),
                                                margin: const EdgeInsets.all(3),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => _channel?.sink.add(jsonEncode({'action': 'claim_bingo'})),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
              child: const Text("CLAIM BINGO!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
