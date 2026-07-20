import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'views/admin_page.dart'; // LINKED ADMIN PAGE COMPONENT

void main() {
  runApp(const BingoApp());
}

class BingoApp extends StatelessWidget {
  const BingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Bingo',
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
                        // NAVIGATES TO EXTRACTED admin_page.dart
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
      backgroundColor: Colors.grey[300],
      appBar: AppBar(title: const Text('My Bingo Playroom'), backgroundColor: Colors.indigo, foregroundColor: Colors.white, centerTitle: true),
      body: Column(
        children: [
          Container(width: double.infinity, color: Colors.indigo[900], padding: const EdgeInsets.all(4), child: Text(_gameStatusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(
                      children: [
                        const Text('BALL: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                        CircleAvatar(radius: 14, backgroundColor: Colors.amber[700], child: Text(_currentDrawnNumber != null ? '$_currentDrawnNumber' : '--', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    Text("Drawn: ${_drawnNumbers.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
                  ],
                ),
              ),
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double dynamicCellHeight = (constraints.maxHeight - 24) / 18;
                  if (dynamicCellHeight < 16) dynamicCellHeight = 16; 

                  return InteractiveViewer(
                    minScale: 0.3,
                    maxScale: 2.5,
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (ticketIndex) {
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 2.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.indigo.shade400, width: 1.0),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Table(
                                border: TableBorder.all(color: Colors.grey.shade300, width: 0.8),
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
                                        child: Container(
                                          height: dynamicCellHeight,
                                          color: displayText.isEmpty ? Colors.grey.shade100 : Colors.white,
                                          alignment: Alignment.center,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Text(displayText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                                              if (isDaubed && displayText.isNotEmpty)
                                                Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.blue.withOpacity(0.4),
                                                    border: Border.all(color: Colors.blueAccent, width: 0.8)
                                                  ),
                                                  margin: const EdgeInsets.all(1),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  );
                                }),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: ElevatedButton(
              onPressed: () => _channel?.sink.add(jsonEncode({'action': 'claim_bingo'})),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
              child: const Text("CLAIM BINGO!", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
