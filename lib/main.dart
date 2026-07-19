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
      title: 'Multiplayer Bingo Arena',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const BingoJoinLobbyPage(),
    );
  }
}

// --- DYNAMIC LOBBY INTERFACE ---
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
                    // PROTECTED ACCESSIBILITY LAYER HINT:
                    // Long-press the controller icon below to trigger the protected Admin Control panel.
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
                    const Text(
                      'Join a Bingo Arena',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Your Username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _roomController,
                      decoration: const InputDecoration(
                        labelText: 'Room Code',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.meeting_room),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a room code' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _navigateToRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Connect to Server', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

// --- SECURE SYSTEM ADMINISTRATIVE INTERFACE ---
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Credentials Provided"), backgroundColor: Colors.red),
      );
    }
  }

  void _broadcastGlobalRulesUpdate() {
    // Establishing dedicated ad-hoc socket linkage to issue authoritative adjustments
    final String targetRoom = _roomTargetController.text.trim().toUpperCase();
    final String adminUrl = 'wss://bingo-multiplayer-backend.onrender.com/ws/$targetRoom/SystemAdmin';
    
    try {
      final channel = WebSocketChannel.connect(Uri.parse(adminUrl));
      channel.stream.listen((_) {}, onError: (_) {}, onDone: () {});
      
      channel.sink.add(jsonEncode({
        'action': 'update_room_rules',
        'admin_secret': 'BingoAdmin2026',
        'card_type': _selectedCardType,
        'draw_interval': _drawIntervalSeconds,
      }));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Successfully updated configurations for room: $targetRoom"), backgroundColor: Colors.green),
      );
      
      Future.delayed(const Duration(seconds: 1), () => channel.sink.close());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Transmission failure: $e"), backgroundColor: Colors.red),
      );
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
        appBar: AppBar(title: const Text("Admin Gatekeeper"), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_person, size: 48, color: Colors.indigo),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Admin Security Token', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _verifyAdminAccess,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      child: const Text('Unlock Configurations'),
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
      appBar: AppBar(title: const Text("Game Control Center"), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Global Rules & Architecture Override', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                const SizedBox(height: 16),
                TextField(
                  controller: _roomTargetController,
                  decoration: const InputDecoration(labelText: 'Target Room ID Code', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCardType,
                  decoration: const InputDecoration(labelText: "Active Card Geometry", border: OutlineInputBorder()),
                  items: ["75-Ball (5x5 Grid)", "90-Ball (3x9 Ticket Grid)"]
                      .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setState(() => _selectedCardType = val!),
                ),
                const SizedBox(height: 16),
                Text("Draw Tempo Interval: $_drawIntervalSeconds seconds"),
                Slider(
                  value: _drawIntervalSeconds.toDouble(), min: 2, max: 15, divisions: 13,
                  onChanged: (val) => setState(() => _drawIntervalSeconds = val.toInt()),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _broadcastGlobalRulesUpdate,
                  icon: const Icon(Icons.rocket_launch),
                  label: const Text("Apply Operational System Overrides"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- GAME ROOM RENDERING ENGINE WITH CUSTOM MATRIX EXTENSIONS ---
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
  bool _isConnected = false;
  bool _gameStarted = false;
  String _gameStatusMessage = "Connecting to game server...";

  final List<Map<String, String>> _chatMessages = [];
  final _chatTextController = TextEditingController();
  final _chatScrollController = ScrollController();

  String get _wsUrl => 'wss://bingo-multiplayer-backend.onrender.com/ws/${widget.roomId}/${widget.username}';

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      setState(() => _isConnected = true);

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            final String event = data['event'];

            switch (event) {
              case 'card_assigned':
                setState(() {
                  _bingoCardNumbers = List<List<dynamic>>.from(data['card']);
                  int rows = _bingoCardNumbers.length;
                  int cols = _bingoCardNumbers[0].length;
                  _daubedStates = List.generate(rows, (_) => List.filled(cols, false));
                  
                  if (rows == 5 && cols == 5) {
                    _daubedStates[2][2] = true; // Flag the layout FREE token[cite: 5]
                  }
                  _gameStatusMessage = "Connected to Room: ${data['room_id']}";
                });
                break;

              case 'player_joined':
                setState(() {
                  _gameStatusMessage = "Lobby: ${data['total_players']} Player(s) inside. Waiting for game start...";
                });
                break;

              case 'game_started':
                setState(() {
                  _gameStarted = true;
                  _gameStatusMessage = "⚡ Game Live! Room: ${widget.roomId}";
                });
                break;

              case 'number_drawn':
                setState(() {
                  int newNumber = data['number'];
                  _currentDrawnNumber = newNumber;
                  _drawnNumbers.clear();
                  _drawnNumbers.addAll(List<int>.from(data['history']));
                });
                break;

              case 'chat_message':
                setState(() {
                  _chatMessages.add({'sender': data['sender'], 'message': data['message']});
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_chatScrollController.hasClients) {
                    _chatScrollController.animateTo(
                      _chatScrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                });
                break;

              case 'room_rules_changed':
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(data['message']), backgroundColor: Colors.purple[700]),
                );
                break;

              case 'game_over':
                setState(() {
                  _gameStarted = false;
                  _gameStatusMessage = data['winner'] != null 
                      ? "🏆 Winner: ${data['winner']}!" 
                      : "Game Over";
                });
                break;

              case 'invalid_claim':
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(data['message']), backgroundColor: Colors.orange[800]),
                );
                break;
            }
          } catch (e) {
            debugPrint("Parsing error: $e");
          }
        },
        onError: (error) => setState(() => _isConnected = false),
        onDone: () => setState(() => _isConnected = false),
      );
    } catch (e) {
      setState(() => _isConnected = false);
    }
  }

  void _sendChatMessage() {
    final text = _chatTextController.text.trim();
    if (text.isEmpty || _channel == null || !_isConnected) return;
    
    _channel!.sink.add(jsonEncode({'action': 'send_message', 'message': text}));
    _chatTextController.clear();
  }

  void _claimBingo() {
    if (_channel == null || !_isConnected) return;
    _channel!.sink.add(jsonEncode({'action': 'claim_bingo'}));
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _chatTextController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.height < 780;
    int rows = _bingoCardNumbers.length;
    int cols = _bingoCardNumbers[0].length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isConnected ? 'Bingo Arena 🎰' : 'Connecting...'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Badge(label: Text('Chat'), child: Icon(Icons.chat_bubble)),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Column(
          children: [
            Container(
              color: Colors.indigo, width: double.infinity, padding: const EdgeInsets.all(20),
              child: const Text('Room Chat Log', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: _chatScrollController, padding: const EdgeInsets.all(12),
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final msg = _chatMessages[index];
                  final isMe = msg['sender'] == widget.username;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: isMe ? Colors.indigo[100] : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(msg['sender']!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo[900])),
                          const SizedBox(height: 2),
                          Text(msg['message']!, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatTextController,
                      decoration: const InputDecoration(hintText: 'Type message...', border: OutlineInputBorder()),
                      onSubmitted: (_) => _sendChatMessage(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send, color: Colors.indigo), onPressed: _sendChatMessage),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity, color: Colors.indigo[900], padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_gameStatusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 16.0), elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('CURRENT BALL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                CircleAvatar(
                                  radius: 32, backgroundColor: Colors.amber[700],
                                  child: Text(_currentDrawnNumber != null ? '$_currentDrawnNumber' : '--', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('RECENT DRAWS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Row(
                                  children: _drawnNumbers.reversed.skip(1).take(4).map((num) => Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(color: Color(0xFFE8EAF6), shape: BoxShape.circle),
                                    child: Text('$num', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                  )).toList(),
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    if (cols == 5) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const ['B', 'I', 'N', 'G', 'O'].map((letter) => Expanded(
                          child: Center(child: Text(letter, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.indigo))),
                        )).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // --- CONDITIONAL ADAPTIVE GRID LAYOUT RENDERER ---
                    cols == 9
                        ? Table(
                            border: TableBorder.all(color: Colors.grey.shade400, width: 1.5),
                            children: List.generate(rows, (r) {
                              return TableRow(
                                children: List.generate(cols, (c) {
                                  var cellVal = _bingoCardNumbers[r][c];
                                  String displayText = (cellVal == 0 || cellVal == "") ? "" : cellVal.toString();
                                  bool isDaubed = _daubedStates[r][c];
                                  return GestureDetector(
                                    onTap: () {
                                      if (displayText.isNotEmpty) {
                                        setState(() => _daubedStates[r][c] = !_daubedStates[r][c]);
                                      }
                                    },
                                    child: Container(
                                      height: 50,
                                      color: displayText.isEmpty ? Colors.grey.shade200 : Colors.white,
                                      alignment: Alignment.center,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Text(displayText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          if (isDaubed && displayText.isNotEmpty)
                                            Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withOpacity(0.55)), margin: const EdgeInsets.all(4)),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              );
                            }),
                          )
                        : AspectRatio(
                            aspectRatio: 1,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 6, mainAxisSpacing: 6),
                              itemCount: 25,
                              itemBuilder: (context, index) {
                                int r = index ~/ 5; int c = index % 5;
                                var rawVal = _bingoCardNumbers[r][c];
                                String val = rawVal == 0 ? "FREE" : rawVal.toString();
                                bool isDaubed = _daubedStates[r][c];
                                return GestureDetector(
                                  onTap: () {
                                    if (r == 2 && c == 2) return;
                                    setState(() => _daubedStates[r][c] = !isDaubed);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFC5CAE9), width: 1.5)),
                                    alignment: Alignment.center,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Text(val, style: TextStyle(fontSize: val == "FREE" ? 12 : 18, fontWeight: FontWeight.bold, color: val == "FREE" ? Colors.amber[900] : Colors.black87)),
                                        if (isDaubed) Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withOpacity(0.45)), margin: const EdgeInsets.all(6)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0), child: ElevatedButton(
              onPressed: _gameStarted ? _claimBingo : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 54)),
              child: const Text('BINGO!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
