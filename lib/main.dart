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
      title: 'Restricted Arena Bingo',
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
  final _roomController = TextEditingController(text: "ROOM100");
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _roomController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showGuidelinePopup(String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.info_outline, 
                color: isError ? Colors.red : Colors.indigo
              ),
              const SizedBox(width: 10),
              Text(isError ? 'Access Error' : 'Room Rules Capacity'),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 15, height: 1.4)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Understood'),
            )
          ],
        );
      },
    );
  }

  void _validateAndEnterRoom() {
    final selectedRoom = _roomController.text.trim().toUpperCase();
    
    if (selectedRoom != "ROOM100" && selectedRoom != "ROOM101") {
      _showGuidelinePopup(
        "Invalid Target Code Entry!\n\nThe server restricts play exclusively to ROOM100 or ROOM101.", 
        isError: true
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      _showGuidelinePopup(
        "Connecting to $selectedRoom...\n\nPlease Note: Total concurrent room participants must be between 1 - 80 maximum.",
        isError: false
      );
      
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        Navigator.of(context).pop(); 
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BingoGamePage(
              roomId: selectedRoom,
              username: _nameController.text.trim(),
            ),
          ),
        );
      });
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
                    const Icon(Icons.casino, size: 64, color: Colors.indigo),
                    const SizedBox(height: 16),
                    const Text('Regulated Bingo Arena', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Your Username', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _roomController,
                      decoration: const InputDecoration(labelText: 'Room Code (ROOM100 / ROOM101)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.meeting_room)),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter code' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _validateAndEnterRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Enter Match Lobby', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  final List<List<bool>> _daubedStates = List.generate(5, (_) => List.filled(5, false));
  List<List<dynamic>> _bingoCardNumbers = List.generate(5, (_) => List.filled(5, ""));
  
  WebSocketChannel? _channel;
  final List<int> _drawnNumbers = []; 
  final List<String> _activeRoomUsers = []; 
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
              case 'player_reconnected':
                setState(() {
                  _bingoCardNumbers = data['card'];
                  _gameStarted = data['game_started'] ?? false;
                  _gameStatusMessage = "Connected to Room: ${data['room_id']}";
                  
                  if (data['daubed_grid'] != null) {
                    for (int r = 0; r < 5; r++) {
                      for (int c = 0; c < 5; c++) {
                        _daubedStates[r][c] = data['daubed_grid'][r][c];
                      }
                    }
                  } else {
                    _daubedStates[2][2] = true;
                  }

                  if (data['history'] != null) {
                    _drawnNumbers.clear();
                    _drawnNumbers.addAll(List<int>.from(data['history']));
                    if (_drawnNumbers.isNotEmpty) {
                      _currentDrawnNumber = _drawnNumbers.last;
                    }
                  }
                });
                break;

              case 'room_users_update':
                setState(() {
                  _activeRoomUsers.clear();
                  _activeRoomUsers.addAll(List<String>.from(data['users']));
                });
                break;

              case 'game_started':
                setState(() {
                  _gameStarted = true;
                  _gameStatusMessage = "🎮 Game Live! Room: ${widget.roomId}";
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
                    _chatScrollController.animateTo(_chatScrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                  }
                });
                break;

              case 'game_over':
                setState(() {
                  _gameStarted = false;
                  _gameStatusMessage = data['winner'] != null ? "🏆 Winner: ${data['winner']}!" : "Game Over";
                });
                break;

              case 'invalid_claim':
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.red[800]));
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

  void _toggleDaubCell(int row, int col, bool currentStatus) {
    if (row == 2 && col == 2) return;
    setState(() => _daubedStates[row][col] = !currentStatus);
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({'action': 'toggle_daub', 'row': row, 'col': col}));
    }
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
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.height < 780;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isConnected ? '${widget.roomId} 🟢' : 'Disconnected 🔴'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          Builder(builder: (context) => IconButton(icon: const Badge(label: Text('Chat'), child: Icon(Icons.chat_bubble)), onPressed: () => Scaffold.of(context).openEndDrawer())),
        ],
      ),
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            children: [
              Container(color: Colors.indigo, width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), child: const Text('Room Chat Log', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
              Expanded(
                child: _chatMessages.isEmpty
                    ? Center(child: Text('No messages yet', style: TextStyle(color: Colors.grey[500])))
                    : ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _chatMessages.length,
                        itemBuilder: (context, index) {
                          final msg = _chatMessages[index];
                          final isMe = msg['sender'] == widget.username;
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
              const Divider(height: 1),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(child: TextField(controller: _chatTextController, decoration: const InputDecoration(hintText: 'Type a message...', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)), onSubmitted: (_) => _sendChatMessage())),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.send, color: Colors.indigo), onPressed: _sendChatMessage),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(width: double.infinity, color: Colors.indigo[900], padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_gameStatusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500))),
          Container(
            height: 44,
            width: double.infinity,
            color: Colors.indigo[50],
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _activeRoomUsers.length,
              itemBuilder: (context, index) {
                final user = _activeRoomUsers[index];
                final isCurrent = user == widget.username;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: isCurrent ? Colors.indigo : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.indigo.withOpacity(0.3))),
                  child: Row(
                    children: [
                      Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(user, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isCurrent ? Colors.white : Colors.indigo[900])),
                    ],
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(
                      margin: EdgeInsets.symmetric(vertical: isMobile ? 8.0 : 16.0),
                      elevation: 4,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 10.0 : 20.0, horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('CURRENT NUMBER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 4),
                                CircleAvatar(radius: isMobile ? 26 : 36, backgroundColor: Colors.amber[700], child: Text(_currentDrawnNumber != null ? '$_currentDrawnNumber' : '--', style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.bold, color: Colors.white))),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('RECENT DRAWS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Row(
                                  children: _drawnNumbers.reversed.skip(1).take(4).map((num) => Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                                    decoration: const BoxDecoration(color: Color(0xFFE8EAF6), shape: BoxShape.circle),
                                    child: Text('$num', style: TextStyle(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                  )).toList(),
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const ['B', 'I', 'N', 'G', 'O'].map((letter) => Expanded(child: Center(child: Text(letter, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.indigo))))).toList(),
                      ),
                    ),
                    AspectRatio(
                      aspectRatio: 1,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 6, mainAxisSpacing: 6),
                        itemCount: 25,
                        itemBuilder: (context, index) {
                          int row = index ~/ 5;
                          int col = index % 5;
                          var rawVal = _bingoCardNumbers[row][col];
                          String val = rawVal == 0 ? "FREE" : rawVal.toString();
                          bool isDaubed = _daubedStates[row][col];

                          return GestureDetector(
                            onTap: () => _toggleDaubCell(row, col, isDaubed),
                            child: Container(
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFC5CAE9), width: 1.5)),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(val, style: TextStyle(fontSize: val == "FREE" ? (isMobile ? 11 : 14) : (isMobile ? 16 : 20), fontWeight: FontWeight.bold, color: val == "FREE" ? Colors.amber[900] : Colors.black87)),
                                  if (isDaubed) Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withOpacity(0.45)), margin: const EdgeInsets.all(6)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 450),
              padding: EdgeInsets.fromLTRB(24.0, 8.0, 24.0, isMobile ? 12.0 : 24.0),
              child: ElevatedButton(
                onPressed: _gameStarted ? _claimBingo : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, isMobile ? 46 : 54),
                  textStyle: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('BINGO!'),
              ),
            ),
          )
        ],
      ),
    );
  }
}
