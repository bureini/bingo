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
      title: 'Multiplayer Bingo',
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
                    const Icon(Icons.sports_esports, size: 64, color: Colors.indigo),
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

// --- GAME ROOM CLIENT ---
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
  int? _currentDrawnNumber;
  bool _isConnected = false;
  bool _gameStarted = false;
  String _gameStatusMessage = "Connecting to game server...";

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
                  _bingoCardNumbers = data['card'];
                  _daubedStates[2][2] = true; 
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

              case 'game_over':
                setState(() {
                  _gameStarted = false;
                  _gameStatusMessage = data['winner'] != null 
                      ? "🏆 Winner: ${data['winner']}!" 
                      : "Game Over: ${data['reason']}";
                });
                break;

              case 'invalid_claim':
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(data['message']),
                    backgroundColor: Colors.orange[800],
                  ),
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

  void _claimBingo() {
    if (_channel == null || !_isConnected) return;
    _channel!.sink.add(jsonEncode({'action': 'claim_bingo'}));
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // Dynamic constraint threshold to optimize dense layout sizing rules on standard smaller devices
    final isMobile = mediaQuery.size.height < 780;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isConnected ? 'Bingo Arena 🎴' : 'Connecting... 📡'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Connection Status Bar Block
          Container(
            width: double.infinity,
            color: Colors.indigo[900],
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _gameStatusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
            ),
          ),
          
          // 2. Expandable Scroll Block containing Dashboard Elements & Board Matrix Grid
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dynamic Summary HUD Display Card
                    Card(
                      margin: EdgeInsets.symmetric(vertical: isMobile ? 8.0 : 16.0),
                      elevation: 4,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 10.0 : 20.0, 
                          horizontal: 16.0
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('CURRENT NUMBER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 4),
                                CircleAvatar(
                                  radius: isMobile ? 26 : 36,
                                  backgroundColor: Colors.amber[700],
                                  child: Text(
                                    _currentDrawnNumber != null ? '$_currentDrawnNumber' : '--',
                                    style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
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
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE8EAF6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text('$num', style: TextStyle(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                  )).toList(),
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    
                    // Letter Title Header Track
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const ['B', 'I', 'N', 'G', 'O'].map((letter) => Expanded(
                          child: Center(
                            child: Text(letter, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.indigo))),
                        )).toList(),
                      ),
                    ),
                    
                    // Native Aspect Ratio Grid Frame 
                    AspectRatio(
                      aspectRatio: 1,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                        itemCount: 25,
                        itemBuilder: (context, index) {
                          int row = index ~/ 5;
                          int col = index % 5;
                          var rawVal = _bingoCardNumbers[row][col];
                          String val = rawVal == 0 ? "FREE" : rawVal.toString();
                          bool isDaubed = _daubedStates[row][col];

                          return GestureDetector(
                            onTap: () {
                              if (row == 2 && col == 2) return;
                              setState(() => _daubedStates[row][col] = !isDaubed);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFC5CAE9), width: 1.5),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    val,
                                    style: TextStyle(
                                      fontSize: val == "FREE" ? (isMobile ? 11 : 14) : (isMobile ? 16 : 20),
                                      fontWeight: FontWeight.bold,
                                      color: val == "FREE" ? Colors.amber[900] : Colors.black87,
                                    ),
                                  ),
                                  if (isDaubed)
                                    Container(
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withOpacity(0.45)),
                                      margin: const EdgeInsets.all(6),
                                    ),
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
          
          // 3. Persistent Operational Footer Button Layer
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