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
                    const Text('My Bingo Multiplayer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _roomController,
                      decoration: const InputDecoration(labelText: 'Room Code', border: OutlineInputBorder(), prefixIcon: Icon(Icons.meeting_room)),
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
                      child: const Text('Connect to Server'),
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
  String _selectedCardType = "75-Ball (5x5 Grid)";
  int _drawIntervalSeconds = 5;

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
              items: ["75-Ball (5x5 Grid)", "90-Ball (3x9 Ticket Grid)"]
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
  List<List<bool>> _daubedStates = List.generate(5, (_) => List.filled(5, false));
  List<List<dynamic>> _bingoCardNumbers = List.generate(5, (_) => List.filled(5, ""));
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
              _bingoCardNumbers = List<List<dynamic>>.from(data['card']);
              int r = _bingoCardNumbers.length;
              int c = _bingoCardNumbers[0].length;
              _daubedStates = List.generate(r, (_) => List.filled(c, false));
              if (r == 5 && c == 5) _daubedStates[2][2] = true;
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
  Widget build(BuildContext context) {
    int rows = _bingoCardNumbers.length;
    int cols = _bingoCardNumbers[0].length;
    return Scaffold(
      appBar: AppBar(title: const Text('My Bingo Playroom'), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: Column(
        children: [
          Container(width: double.infinity, color: Colors.indigo[900], padding: const EdgeInsets.all(8), child: Text(_gameStatusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  CircleAvatar(radius: 32, backgroundColor: Colors.amber[700], child: Text(_currentDrawnNumber != null ? '$_currentDrawnNumber' : '--', style: const TextStyle(fontSize: 24, color: Colors.white))),
                  Text("Total Balls Call: ${_drawnNumbers.length}", style: const TextStyle(fontWeight: FontWeight.bold))
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: cols == 9
                  ? Table(
                      border: TableBorder.all(color: Colors.grey.shade400, width: 1.5),
                      children: List.generate(rows, (r) {
                        return TableRow(
                          children: List.generate(cols, (c) {
                            var cellVal = _bingoCardNumbers[r][c];
                            String txt = (cellVal == 0) ? "" : cellVal.toString();
                            bool isDaubed = _daubedStates[r][c];
                            return GestureDetector(
                              onTap: () { if (txt.isNotEmpty) setState(() => _daubedStates[r][c] = !isDaubed); },
                              child: Container(
                                height: 50, color: txt.isEmpty ? Colors.grey.shade200 : Colors.white,
                                alignment: Alignment.center,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(txt, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    if (isDaubed && txt.isNotEmpty) Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withOpacity(0.5)), margin: const EdgeInsets.all(4)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        );
                      }),
                    )
                  : GridView.builder(
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 6, mainAxisSpacing: 6),
                      itemCount: 25,
                      itemBuilder: (context, idx) {
                        int r = idx ~/ 5; int c = idx % 5;
                        var val = _bingoCardNumbers[r][c] == 0 ? "FREE" : _bingoCardNumbers[r][c].toString();
                        return GestureDetector(
                          onTap: () { if (val != "FREE") setState(() => _daubedStates[r][c] = !_daubedStates[r][c]); },
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.indigo.shade200)),
                            alignment: Alignment.center,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (_daubedStates[r][c]) Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withOpacity(0.4)), margin: const EdgeInsets.all(6))
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          ElevatedButton(onPressed: () => _channel?.sink.add(jsonEncode({'action': 'claim_bingo'})), child: const Text("CLAIM BINGO!")),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
