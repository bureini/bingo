import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'views/admin_page.dart';

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
  final _tokenController = TextEditingController(text: "usr_token_123");
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _roomController.dispose();
    _nameController.dispose();
    _tokenController.dispose();
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
            authToken: _tokenController.text.trim(),
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
  final String authToken;

  const BingoGamePage({
    super.key,
    required this.roomId,
    required this.username,
    required this.authToken,
  });

  @override
  State<BingoGamePage> createState() => _BingoGamePageState();
}

class _BingoGamePageState extends State<BingoGamePage> {
  List<List<List<bool>>> _bookDaubedStates = List.generate(6, (_) => List.generate(3, (_) => List.filled(9, false)));
  List<List<List<dynamic>>> _ticketBookNumbers = List.generate(6, (_) => List.generate(3, (_) => List.filled(9, 0)));
  WebSocketChannel? _channel;
  final List<int> _drawnNumbers = [];
  int? _currentDrawnNumber;
  
  bool _autoDaubEnabled = true;

  String _gameStatusMessage = "Connecting...";
  String _currentStage = "1_line";
  final Map<String, String?> _winners = {"1_line": null, "2_lines": null, "full_house": null};

  // Restored Live Chat & System Announcement State
  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  String? _activeAnnouncement;

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    final wsUrl = 'wss://bingo-multiplayer-backend.onrender.com/ws/${widget.roomId}/${widget.username}?auth_token=${widget.authToken}';
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.stream.listen((message) {
        final data = jsonDecode(message);
        switch (data['event']) {
          case 'card_assigned':
            setState(() {
              _ticketBookNumbers = List<List<List<dynamic>>>.from(data['book']);
              _bookDaubedStates = List.generate(6, (_) => List.generate(3, (_) => List.filled(9, false)));
              _currentStage = data['stage'] ?? "1_line";
              _gameStatusMessage = "Room Connected: ${data['room_id']}";
            });
            break;
          case 'game_started':
            setState(() => _gameStatusMessage = "Game Live! Target: 1 Line");
            break;
          case 'number_drawn':
            setState(() {
              _currentDrawnNumber = data['number'];
              _drawnNumbers.clear();
              _drawnNumbers.addAll(List<int>.from(data['history']));
              if (data['stage'] != null) _currentStage = data['stage'];
              
              if (_autoDaubEnabled) {
                _performAutoDaub(_currentDrawnNumber!);
              }
            });
            break;
          case 'chat_message':
            setState(() {
              _chatMessages.add({
                'sender': data['sender'],
                'message': data['message'],
                'is_admin': data['is_admin'] ?? false,
              });
            });
            break;
          case 'system_announcement':
            setState(() {
              _activeAnnouncement = data['message'];
              _chatMessages.add({
                'sender': '📢 ANNOUNCEMENT',
                'message': data['message'],
                'is_admin': true,
              });
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("📢 [ADMIN]: ${data['message']}"),
                backgroundColor: Colors.orange[800],
                duration: const Duration(seconds: 5),
              ),
            );
            break;
          case 'stage_won':
            setState(() {
              _currentStage = data['next_stage'];
              _winners[data['stage_completed']] = data['winner'];
            });
            _showNotificationDialog("Stage Claimed!", data['message']);
            break;
          case 'game_over':
            setState(() {
              _gameStatusMessage = "Game Completed!";
              _winners[data['stage_completed']] = data['winner'];
            });
            _showNotificationDialog("Game Over!", data['message']);
            break;
          case 'invalid_claim':
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message']), backgroundColor: Colors.red),
            );
            break;
        }
      });
    } catch (_) {}
  }

  void _performAutoDaub(int drawnNumber) {
    for (int t = 0; t < 6; t++) {
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 9; c++) {
          if (_ticketBookNumbers[t][r][c] == drawnNumber) {
            _bookDaubedStates[t][r][c] = true;
          }
        }
      }
    }
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty) {
      _channel?.sink.add(jsonEncode({
        'action': 'send_chat',
        'auth_token': widget.authToken,
        'message': text,
      }));
      _chatController.clear();
    }
  }

  void _showNotificationDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  void _claimBingo() {
    _channel?.sink.add(jsonEncode({
      'action': 'claim_bingo',
      'auth_token': widget.authToken,
    }));
  }

  @override
  void dispose() {
    _chatController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  String _getStageTitle(String stageKey) {
    switch (stageKey) {
      case "1_line": return "1 Line";
      case "2_lines": return "2 Lines";
      case "full_house": return "Full House";
      default: return stageKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent5Drawn = _drawnNumbers.reversed.take(5).toList();

    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        title: Text('Bingo Room (${_getStageTitle(_currentStage)})'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          Row(
            children: [
              const Text("Auto", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              Switch(
                value: _autoDaubEnabled,
                activeColor: Colors.amber,
                onChanged: (val) => setState(() => _autoDaubEnabled = val),
              ),
            ],
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: 'Open Chat',
            ),
          )
        ],
      ),
      endDrawer: Drawer(
        child: Column(
          children: [
            Container(
              color: Colors.indigo,
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              width: double.infinity,
              child: const Row(
                children: [
                  Icon(Icons.forum, color: Colors.white),
                  SizedBox(width: 8),
                  Text("Live Room Chat", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final msg = _chatMessages[index];
                  bool isAdmin = msg['is_admin'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isAdmin ? Colors.amber[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isAdmin ? Colors.amber : Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['sender'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isAdmin ? Colors.orange[900] : Colors.indigo[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(msg['message'], style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      ],
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
                      controller: _chatController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (_) => _sendChatMessage(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.indigo),
                    onPressed: _sendChatMessage,
                  )
                ],
              ),
            )
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.indigo[900],
            padding: const EdgeInsets.all(4),
            child: Text(
              _gameStatusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          
          if (_activeAnnouncement != null)
            Container(
              width: double.infinity,
              color: Colors.amber[800],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.campaign, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _activeAnnouncement!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _activeAnnouncement = null),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  )
                ],
              ),
            ),

          // Progressive Stages Status Bar
          Container(
            color: Colors.indigo[700],
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ["1_line", "2_lines", "full_house"].map((stg) {
                bool isCurrent = _currentStage == stg;
                bool isWon = _winners[stg] != null;
                return Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    isWon ? Icons.check_circle : (isCurrent ? Icons.play_arrow : Icons.lock),
                    color: Colors.white, size: 14,
                  ),
                  label: Text("${_getStageTitle(stg)}: ${_winners[stg] ?? (isCurrent ? 'Active' : 'Locked')}"),
                  backgroundColor: isWon ? Colors.green[700] : (isCurrent ? Colors.amber[800] : Colors.grey[700]),
                  labelStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
          ),

          // Recent Balls Ticker Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
            color: Colors.white,
            child: Row(
              children: [
                const Text('RECENT:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: recent5Drawn.asMap().entries.map((entry) {
                      int idx = entry.key;
                      int ballNum = entry.value;
                      bool isLatest = idx == 0;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLatest ? Colors.amber[800] : Colors.indigo[400],
                        ),
                        child: Text(
                          '$ballNum',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isLatest ? 11 : 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Text("Total: ${_drawnNumbers.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          ),
          
          // Responsive Fit Ticket Layout Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double computedCellHeight = (constraints.maxHeight - 24) / 18;
                  if (computedCellHeight < 8) computedCellHeight = 8;

                  return Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (ticketIndex) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 1.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.indigo.shade400, width: 0.8),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Table(
                              border: TableBorder.all(color: Colors.grey.shade300, width: 0.6),
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
                                        height: computedCellHeight,
                                        color: displayText.isEmpty ? Colors.grey.shade100 : Colors.white,
                                        alignment: Alignment.center,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Text(
                                              displayText,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: computedCellHeight * 0.55,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            if (isDaubed && displayText.isNotEmpty)
                                              Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.blue.withOpacity(0.45),
                                                  border: Border.all(color: Colors.blueAccent, width: 0.8),
                                                ),
                                                margin: const EdgeInsets.all(0.5),
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
                  );
                },
              ),
            ),
          ),
          
          // Stage Claim Button
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
            child: ElevatedButton(
              onPressed: _claimBingo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(
                "CLAIM ${_getStageTitle(_currentStage).toUpperCase()}!",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }
}