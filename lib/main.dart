import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

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

class BingoJoinLobbyPage extends StatefulWidget {
  const BingoJoinLobbyPage({super.key});

  @override
  State<BingoJoinLobbyPage> createState() => _BingoJoinLobbyPageState();
}

class _BingoJoinLobbyPageState extends State<BingoJoinLobbyPage> {
  final _roomController = TextEditingController(text: "ROOM101");
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSigningInAsAdmin = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _roomController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String?> _authenticateAdmin(String username, String password) async {
    final url = Uri.parse('https://bingo-multiplayer-backend.onrender.com/api/admin/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['access_token'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void _executeConnectionFlow() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    if (_isSigningInAsAdmin) {
      String? token = await _authenticateAdmin(_nameController.text.trim(), _passwordController.text);
      setState(() => _isLoading = false);
      
      if (token != null) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDashboardPage(
              username: _nameController.text.trim(),
              adminToken: token,
              initialRoomId: _roomController.text.trim().toUpperCase(),
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Admin Authentication Refused: Invalid Credentials.")),
        );
      }
    } else {
      setState(() => _isLoading = false);
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
                    Icon(
                      _isSigningInAsAdmin ? Icons.admin_panel_settings : Icons.sports_esports,
                      size: 64,
                      color: _isSigningInAsAdmin ? Colors.redAccent : Colors.indigo,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isSigningInAsAdmin ? 'Secure Admin Terminal' : 'Join a Bingo Arena',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _roomController,
                      decoration: const InputDecoration(labelText: 'Room Code', border: OutlineInputBorder(), prefixIcon: Icon(Icons.meeting_room)),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a room code' : null,
                    ),
                    if (_isSigningInAsAdmin) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Admin System Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                        validator: (val) => (val == null || val.isEmpty) ? 'Password required' : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _isSigningInAsAdmin,
                          onChanged: (val) => setState(() {
                            _isSigningInAsAdmin = val ?? false;
                          }),
                        ),
                        const Text("Authenticate as System Admin"),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _executeConnectionFlow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSigningInAsAdmin ? Colors.redAccent : Colors.indigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(_isSigningInAsAdmin ? 'Login & Open Control Console' : 'Connect to Server', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

class AdminDashboardPage extends StatefulWidget {
  final String username;
  final String adminToken;
  final String initialRoomId;

  const AdminDashboardPage({super.key, required this.username, required this.adminToken, required this.initialRoomId});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late TextEditingController _roomController;
  String _ruleType = "standard";
  String _cardType = "classic";
  WebSocketChannel? _socket;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _roomController = TextEditingController(text: widget.initialRoomId);
  }

  void _syncRules() {
    final room = _roomController.text.trim().toUpperCase();
    if (room.isEmpty) return;

    _socket?.sink.close();
    final wsUrl = 'wss://bingo-multiplayer-backend.onrender.com/ws/$room/${widget.username}?token=${widget.adminToken}';
    
    try {
      _socket = WebSocketChannel.connect(Uri.parse(wsUrl));
      _socket!.sink.add(jsonEncode({
        'action': 'update_room_rules',
        'rule_type': _ruleType,
        'card_type': _cardType,
      }));
      setState(() => _isConnected = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Room $room game configurations applied.'), backgroundColor: Colors.green[800]),
      );
    } catch (e) {
      setState(() => _isConnected = false);
    }
  }

  void _triggerGameStart() {
    if (_socket == null || !_isConnected) return;
    _socket!.sink.add(jsonEncode({'action': 'start_admin_match'}));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Match live! Game extraction loops activated.'), backgroundColor: Colors.indigo),
    );
  }

  @override
  void dispose() {
    _roomController.dispose();
    _socket?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Operations Management Tower'), backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _roomController,
                    decoration: const InputDecoration(labelText: 'Target Room ID to Modify', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _ruleType,
                    decoration: const InputDecoration(labelText: "Winning Target Rule Set", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: "standard", child: Text("Standard Line (Row/Col/Diag)")),
                      DropdownMenuItem(value: "blackout", child: Text("Full House / Blackout")),
                      DropdownMenuItem(value: "corners", child: Text("Four Corners")),
                    ],
                    onChanged: (val) => setState(() => _ruleType = val!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _cardType,
                    decoration: const InputDecoration(labelText: "Grid Form Layout Matrix", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: "classic", child: Text("Classic 5x5 Grid Layout")),
                      DropdownMenuItem(value: "speed", child: Text("Speed 3x3 Grid Layout")),
                    ],
                    onChanged: (val) => setState(() => _cardType = val!),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _syncRules,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                    child: const Text('Publish Configurations & Sync Room'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isConnected ? _triggerGameStart : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                    child: const Text('Force Start Active Room Match'),
                  ),
                ],
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
  int _dimension = 5;
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

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    final wsUrl = 'wss://bingo-multiplayer-backend.onrender.com/ws/${widget.roomId}/${widget.username}';
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      setState(() => _isConnected = true);

      _channel!.stream.listen((message) {
        final data = jsonDecode(message);
        final String event = data['event'];

        switch (event) {
          case 'card_assigned':
            setState(() {
              _dimension = data['card_type'] == "speed" ? 3 : 5;
              _bingoCardNumbers = List<List<dynamic>>.from(data['card']);
              _daubedStates = List.generate(_dimension, (_) => List.filled(_dimension, false));
              if (_dimension == 5) _daubedStates[2][2] = true; 
              _gameStatusMessage = "Connected to Room: ${data['room_id']}";
            });
            break;

          case 'room_rules_updated':
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message']), backgroundColor: Colors.indigo[900]),
            );
            break;

          case 'player_joined':
            setState(() {
              _gameStatusMessage = "Lobby: ${data['total_players']} Player(s) inside. Waiting for game start...";
            });
            break;

          case 'game_started':
            setState(() {
              _gameStarted = true;
              _gameStatusMessage = data['message'];
            });
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
              _gameStatusMessage = "Winner: ${data['winner']}!";
            });
            break;

          case 'invalid_claim':
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.orange[800]));
            break;
        }
      }, onError: (_) => setState(() => _isConnected = false), onDone: () => setState(() => _isConnected = false));
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isConnected ? 'Bingo Arena' : 'Connecting...'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          Builder(builder: (context) => IconButton(icon: const Icon(Icons.chat_bubble), onPressed: () => Scaffold.of(context).openEndDrawer())),
        ],
      ),
      endDrawer: Drawer(
        child: Column(
          children: [
            Container(color: Colors.indigo, width: double.infinity, padding: const EdgeInsets.all(16), child: const Text('Room Chat Log', style: TextStyle(color: Colors.white, fontSize: 18))),
            Expanded(
              child: ListView.builder(
                controller: _chatScrollController,
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final msg = _chatMessages[index];
                  return ListTile(title: Text(msg['sender']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), subtitle: Text(msg['message']!));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _chatTextController, decoration: const InputDecoration(hintText: 'Type message...'))),
                  IconButton(icon: const Icon(Icons.send), onPressed: _sendChatMessage),
                ],
              ),
            )
          ],
        ),
      ),
      body: Column(
        children: [
          Container(width: double.infinity, color: Colors.indigo[900], padding: const EdgeInsets.all(8), child: Text(_gameStatusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white))),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        CircleAvatar(radius: 30, backgroundColor: Colors.amber[700], child: Text(_currentDrawnNumber?.toString() ?? '--', style: const TextStyle(fontSize: 22, color: Colors.white))),
                        Text('Total Extracted: ${_drawnNumbers.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _dimension, crossAxisSpacing: 6, mainAxisSpacing: 6),
                      itemCount: _dimension * _dimension,
                      itemBuilder: (context, index) {
                        int r = index ~/ _dimension;
                        int c = index % _dimension;
                        if (r >= _bingoCardNumbers.length || c >= _bingoCardNumbers[r].length) return const SizedBox();
                        var rawVal = _bingoCardNumbers[r][c];
                        String textVal = rawVal == 0 ? "FREE" : rawVal.toString();
                        bool daubed = _daubedStates[r][c];
                        return GestureDetector(
                          onTap: () => setState(() => _daubedStates[r][c] = !daubed),
                          child: Container(
                            decoration: BoxDecoration(color: daubed ? Colors.red[200] : Colors.white, border: Border.all(color: Colors.indigo), borderRadius: BorderRadius.circular(8)),
                            alignment: Alignment.center,
                            child: Text(textVal, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _gameStarted ? () => _channel?.sink.add(jsonEncode({'action': 'claim_bingo'})) : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(200, 50)),
            child: const Text('BINGO!'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
