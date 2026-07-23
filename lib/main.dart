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
  
  // Chat & Broadcast State
  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  String? _activeAnnouncement;

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
            setState(() => _gameStatusMessage = "Game Live!");
            break;
          case 'number_drawn':
            setState(() {
              _currentDrawnNumber = data['number'];
              _drawnNumbers.clear();
              _drawnNumbers.addAll(List<int>.from(data['history']));
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
                'sender': 'ANNOUNCEMENT',
                'message': data['message'],
                'is_admin': true,
              });
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("[ADMIN]: ${data['message']}"),
                backgroundColor: Colors.orange[800],
                duration: const Duration(seconds: 6),
              ),
            );
            break;
          case 'game_over':
            setState(() => _gameStatusMessage = data['winner'] != null ? "Winner: ${data['winner']}!" : "Game Over");
            break;
        }
      });
    } catch (_) {}
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty) {
      _channel?.sink.add(jsonEncode({
        'action': 'send_chat',
        'message': text,
      }));
      _chatController.clear();
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<int> recentFiveDrawn = _drawnNumbers.reversed.take(5).toList();
    final Set<int> drawnNumbersSet = _drawnNumbers.toSet();

    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        title: const Text('My Bingo Playroom'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: 'Open Chat Feed',
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
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          
          if (_activeAnnouncement != null)
            Container(
              width: double.infinity,
              color: Colors.amber[800],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.campaign, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _activeAnnouncement!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _activeAnnouncement = null),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  )
                ],
              ),
            ),

          // --- TOP DRAWN BALL RACK ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                child: Column(
                  children: [
                    const Text('RECENT DRAWN BALLS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        bool hasNum = index < recentFiveDrawn.length;
                        int? numVal = hasNum ? recentFiveDrawn[index] : null;
                        bool isLatest = (index == 0) && hasNum;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: CircleAvatar(
                            radius: isLatest ? 18 : 15,
                            backgroundColor: isLatest
                                ? Colors.amber[700]
                                : (hasNum ? Colors.indigo[600] : Colors.grey[300]),
                            child: Text(
                              hasNum ? '$numVal' : '--',
                              style: TextStyle(
                                fontSize: isLatest ? 14 : 12,
                                color: hasNum ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
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
                                      int numberInt = (cellVal is int) ? cellVal : int.tryParse(cellVal.toString()) ?? 0;
                                      String displayText = (numberInt == 0) ? "" : numberInt.toString();
                                      
                                      bool isDaubedManual = _bookDaubedStates[ticketIndex][r][c];
                                      bool isDrawnMatch = numberInt != 0 && drawnNumbersSet.contains(numberInt);
                                      
                                      return GestureDetector(
                                        onTap: () {
                                          if (displayText.isNotEmpty) {
                                            setState(() => _bookDaubedStates[ticketIndex][r][c] = !isDaubedManual);
                                          }
                                        },
                                        child: Container(
                                          height: dynamicCellHeight,
                                          color: displayText.isEmpty
                                              ? Colors.grey.shade100
                                              : (isDrawnMatch ? Colors.green.shade50 : Colors.white),
                                          alignment: Alignment.center,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Text(
                                                displayText,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: isDrawnMatch ? Colors.green.shade900 : Colors.black87,
                                                ),
                                              ),
                                              if (isDrawnMatch)
                                                Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.green.withOpacity(0.35),
                                                    border: Border.all(color: Colors.green, width: 1.2),
                                                  ),
                                                  margin: const EdgeInsets.all(1),
                                                ),
                                              if (isDaubedManual && !isDrawnMatch && displayText.isNotEmpty)
                                                Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.blue.withOpacity(0.4),
                                                    border: Border.all(color: Colors.blueAccent, width: 0.8),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text("CLAIM BINGO!", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}