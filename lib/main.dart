import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const BingoApp());
}

class BingoApp extends StatelessWidget {
  const BingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Bingo 6-Card Book',
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
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
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
  String _adminPassphrase = "BingoAdmin2026";
  
  final _passphraseController = TextEditingController(text: "BingoAdmin2026");
  final _newPassphraseController = TextEditingController();
  final _roomTargetController = TextEditingController(text: "ROOM101");
  final _newRoomController = TextEditingController();
  
  final _ticketPriceController = TextEditingController(text: "Free");
  final _prize1LineController = TextEditingController(text: r"$10.00");
  final _prize2LinesController = TextEditingController(text: r"$25.00");
  final _prizeFullHouseController = TextEditingController(text: r"$100.00");
  final _rulesNoticeController = TextEditingController(text: "1 Line = 5 marked, 2 Lines = 10 marked, Full House = 15 marked.");

  int _drawIntervalSeconds = 4;
  WebSocketChannel? _adminChannel;
  bool _isRoomPaused = false;
  List<String> _connectedParticipants = [];

  void _verifyAdminAccess() {
    setState(() {
      _adminPassphrase = _passphraseController.text.trim();
      _isAuthenticated = true;
    });
    _connectAdminSocket();
  }

  void _connectAdminSocket() {
    final targetRoom = _roomTargetController.text.trim().toUpperCase();
    final adminUrl = 'wss://bingo-multiplayer-backend.onrender.com/ws/$targetRoom/SystemAdmin';
    try {
      _adminChannel = WebSocketChannel.connect(Uri.parse(adminUrl));
      _adminChannel!.stream.listen((message) {
        final data = jsonDecode(message);
        if (data['active_users'] != null) {
          setState(() {
            _connectedParticipants = List<String>.from(data['active_users']);
          });
        }
        if (data['event'] == 'admin_success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message']), backgroundColor: Colors.green),
          );
        } else if (data['event'] == 'game_paused') {
          setState(() => _isRoomPaused = true);
        } else if (data['event'] == 'game_resumed') {
          setState(() => _isRoomPaused = false);
        }
      });
    } catch (_) {}
  }

  void _sendAdminAction(Map<String, dynamic> payload) {
    if (_adminChannel != null) {
      payload['admin_secret'] = _adminPassphrase;
      _adminChannel!.sink.add(jsonEncode(payload));
    } else {
      _connectAdminSocket();
    }
  }

  void _resetPassphrase() {
    final newPass = _newPassphraseController.text.trim();
    if (newPass.isNotEmpty) {
      _sendAdminAction({
        'action': 'reset_passphrase',
        'new_passphrase': newPass,
      });
      setState(() {
        _adminPassphrase = newPass;
        _passphraseController.text = newPass;
      });
      _newPassphraseController.clear();
    }
  }

  void _createNewRoom() {
    final roomCode = _newRoomController.text.trim().toUpperCase();
    if (roomCode.isNotEmpty) {
      _sendAdminAction({
        'action': 'create_room',
        'new_room_id': roomCode,
      });
      _newRoomController.clear();
    }
  }

  void _deleteTargetRoom() {
    final targetRoom = _roomTargetController.text.trim().toUpperCase();
    if (targetRoom.isNotEmpty) {
      _sendAdminAction({
        'action': 'delete_room',
        'target_room_id': targetRoom,
      });
    }
  }

  void _broadcastRulesAndPricing() {
    _sendAdminAction({
      'action': 'configure_rules_pricing',
      'ticket_price': _ticketPriceController.text.trim(),
      'prizes': {
        'one_line': _prize1LineController.text.trim(),
        'two_lines': _prize2LinesController.text.trim(),
        'full_house': _prizeFullHouseController.text.trim(),
      },
      'rules_notice': _rulesNoticeController.text.trim(),
    });
  }

  void _toggleGamePause() {
    _sendAdminAction({
      'action': 'toggle_game_state',
      'command': _isRoomPaused ? 'resume' : 'pause',
    });
    setState(() => _isRoomPaused = !_isRoomPaused);
  }

  void _updateSpeedTempo() {
    _sendAdminAction({
      'action': 'update_room_rules',
      'draw_interval': _drawIntervalSeconds,
    });
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    _newPassphraseController.dispose();
    _roomTargetController.dispose();
    _newRoomController.dispose();
    _ticketPriceController.dispose();
    _prize1LineController.dispose();
    _prize2LinesController.dispose();
    _prizeFullHouseController.dispose();
    _rulesNoticeController.dispose();
    _adminChannel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text("Admin Access Gate"), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
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
                    const Icon(Icons.admin_panel_settings, size: 56, color: Colors.indigo),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passphraseController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Admin Passphrase', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _verifyAdminAccess,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
                      child: const Text('Authenticate'),
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
      appBar: AppBar(
        title: const Text("Admin Suite & Room Control"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Reconnect Admin Socket',
            onPressed: _connectAdminSocket,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 750),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Security & Admin Passphrase", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newPassphraseController,
                                decoration: const InputDecoration(labelText: 'New Secret Passphrase', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _resetPassphrase,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                              child: const Text("Reset Token"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Room Management Engine", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newRoomController,
                                decoration: const InputDecoration(labelText: r'New Room Code (e.g. VIP_2)', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text("Create Room"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: _createNewRoom,
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _roomTargetController,
                                decoration: const InputDecoration(labelText: 'Target Room ID', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: Icon(_isRoomPaused ? Icons.play_arrow : Icons.pause),
                              label: Text(_isRoomPaused ? "Resume" : "Pause"),
                              style: ElevatedButton.styleFrom(backgroundColor: _isRoomPaused ? Colors.green : Colors.orange.shade800, foregroundColor: Colors.white),
                              onPressed: _toggleGamePause,
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                              label: const Text("Delete", style: TextStyle(color: Colors.red)),
                              onPressed: _deleteTargetRoom,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Connected Participants", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                            Chip(label: Text("${_connectedParticipants.length} Connected"), backgroundColor: Colors.indigo.shade50),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _connectedParticipants.isEmpty
                            ? const Text("No active players connected in target room.", style: TextStyle(color: Colors.grey, fontSize: 12))
                            : Wrap(
                                spacing: 8.0,
                                children: _connectedParticipants.map((user) => Chip(
                                  avatar: const CircleAvatar(backgroundColor: Colors.green, radius: 4),
                                  label: Text(user, style: const TextStyle(fontSize: 12)),
                                )).toList(),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Rules, Pricing & Prizes Configuration", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _ticketPriceController,
                                decoration: const InputDecoration(labelText: r'Ticket Cost (Free, $5, etc)', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _prize1LineController,
                                decoration: const InputDecoration(labelText: '1 Line Prize', border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _prize2LinesController,
                                decoration: const InputDecoration(labelText: '2 Lines Prize', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _prizeFullHouseController,
                                decoration: const InputDecoration(labelText: 'Full House Prize', border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _rulesNoticeController,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Rules Announcement Notice', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.campaign),
                          label: const Text("Broadcast Rules & Prizes to Room"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 44)),
                          onPressed: _broadcastRulesAndPricing,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Ball Drawing Speed: $_drawIntervalSeconds sec / ball", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        Slider(
                          value: _drawIntervalSeconds.toDouble(),
                          min: 2,
                          max: 15,
                          divisions: 13,
                          onChanged: (val) => setState(() => _drawIntervalSeconds = val.toInt()),
                        ),
                        ElevatedButton(
                          onPressed: _updateSpeedTempo,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 40)),
                          child: const Text("Apply Speed Setting"),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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

class _BingoGamePageState extends State<BingoGamePage> with SingleTickerProviderStateMixin {
  List<List<List<bool>>> _bookDaubedStates = List.generate(6, (_) => List.generate(3, (_) => List.filled(9, false)));
  List<List<List<dynamic>>> _ticketBookNumbers = List.generate(6, (_) => List.generate(3, (_) => List.filled(9, 0)));
  WebSocketChannel? _channel;
  bool _isChannelConnected = false;
  final List<int> _drawnNumbers = [];
  int? _currentDrawnNumber;
  String _gameStatusMessage = "Connecting...";

  final List<Map<String, String>> _chatMessages = [];
  final List<String> _activePlayers = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  String _selectedClaimType = "one_line";
  String _ticketPrice = "Free";

  AnimationController? _victoryController;
  bool _showVictoryOverlay = false;
  List<_ConfettiParticle> _confetti = [];

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();

    _victoryController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        if (_showVictoryOverlay) {
          _updateConfettiParticles();
        }
      });
  }

  void _connectToWebSocket() {
    final wsUrl = 'wss://bingo-multiplayer-backend.onrender.com/ws/${widget.roomId}/${widget.username}';
    setState(() {
      _gameStatusMessage = "Connecting to room...";
      _isChannelConnected = false;
    });

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isChannelConnected = true;

      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          switch (data['event']) {
            case 'card_assigned':
              setState(() {
                _ticketBookNumbers = List<List<List<dynamic>>>.from(data['book']);
                _bookDaubedStates = List.generate(6, (_) => List.generate(3, (_) => List.filled(9, false)));
                _gameStatusMessage = "Room Connected: ${data['room_id']}";
                _ticketPrice = data['ticket_price'] ?? "Free";
                _isChannelConnected = true;
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
              HapticFeedback.lightImpact();
              break;
            case 'player_joined':
            case 'player_left':
              setState(() {
                if (data['active_users'] != null) {
                  _activePlayers.clear();
                  _activePlayers.addAll(List<String>.from(data['active_users']));
                }
              });
              break;
            case 'chat_received':
              setState(() {
                final int epochMs = data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
                final DateTime localTime = DateTime.fromMillisecondsSinceEpoch(epochMs);
                final String formattedTime = "${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}";

                _chatMessages.add({
                  'username': data['username'] ?? 'System',
                  'message': data['message'] ?? '',
                  'time': formattedTime,
                });
              });
              Future.delayed(const Duration(milliseconds: 100), () {
                if (_chatScrollController.hasClients) {
                  _chatScrollController.animateTo(
                    _chatScrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              });
              break;
            case 'rules_updated':
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("📢 Room Rules Updated"),
                  content: Text(data['message'] ?? ""),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
                  ],
                ),
              );
              break;
            case 'stage_won':
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("🎉 ${data['winner']} WON ${data['claim_type']}!"), backgroundColor: Colors.green),
              );
              if (data['winner'] == widget.username) {
                _triggerVictoryAnimation();
              }
              break;
            case 'invalid_claim':
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(data['message']), backgroundColor: Colors.redAccent),
              );
              break;
            case 'game_over':
              setState(() {
                final winner = data['winner'];
                _gameStatusMessage = winner != null ? "🏆 Full House Winner: $winner!" : "Game Over";
                if (winner == widget.username) {
                  _triggerVictoryAnimation();
                }
              });
              break;
            case 'system_disconnect':
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(data['message']), backgroundColor: Colors.red),
              );
              break;
          }
        },
        onDone: () => setState(() => _isChannelConnected = false),
        onError: (_) => setState(() => _isChannelConnected = false),
      );
    } catch (_) {
      setState(() => _isChannelConnected = false);
    }
  }

  void _triggerVictoryAnimation() {
    setState(() => _showVictoryOverlay = true);
    _initializeConfetti();
    _victoryController?.repeat();
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty && _channel != null) {
      _channel!.sink.add(jsonEncode({'action': 'send_chat', 'message': text}));
      _chatController.clear();
    }
  }

  void _claimCurrentStage() {
    if (_channel != null && _isChannelConnected) {
      _channel!.sink.add(jsonEncode({'action': 'claim_bingo', 'claim_type': _selectedClaimType}));
    }
  }

  void _confirmQuitGame() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit Game?'),
        content: const Text('Are you sure you want to exit the current playroom?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _channel?.sink.close();
              Navigator.pop(context);
            },
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }

  void _initializeConfetti() {
    final random = math.Random();
    _confetti = List.generate(120, (index) {
      return _ConfettiParticle(
        x: random.nextDouble() * 400,
        y: -random.nextDouble() * 200,
        color: Colors.primaries[random.nextInt(Colors.primaries.length)],
        size: random.nextDouble() * 7 + 5,
        speedY: random.nextDouble() * 3 + 2,
        speedX: random.nextDouble() * 2 - 1,
        rotation: random.nextDouble() * math.pi,
        shape: ConfettiShape.values[random.nextInt(ConfettiShape.values.length)],
      );
    });
  }

  void _updateConfettiParticles() {
    final random = math.Random();
    setState(() {
      for (var particle in _confetti) {
        particle.y += particle.speedY;
        particle.x += particle.speedX;
        particle.rotation += 0.05;
        if (particle.y > 800) {
          particle.y = -20;
          particle.x = random.nextDouble() * 500;
        }
      }
    });
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _chatController.dispose();
    _chatScrollController.dispose();
    _victoryController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobileViewport = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        title: Text('Playroom: ${widget.roomId}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isChannelConnected ? Icons.cloud_done : Icons.cloud_off, color: _isChannelConnected ? Colors.greenAccent : Colors.redAccent),
            onPressed: () {
              if (!_isChannelConnected) _connectToWebSocket();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _confirmQuitGame,
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              color: Colors.indigo,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Draw History', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${_drawnNumbers.length} of 90 balls drawn', style: TextStyle(color: Colors.indigo.shade100, fontSize: 13)),
                ],
              ),
            ),
            Expanded(
              child: _drawnNumbers.isEmpty
                  ? Center(child: Text('No numbers drawn yet.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _drawnNumbers.length,
                      separatorBuilder: (_, __) => const Divider(height: 12, thickness: 0.5),
                      itemBuilder: (context, index) {
                        final reverseIndex = _drawnNumbers.length - 1 - index;
                        final ballNumber = _drawnNumbers[reverseIndex];
                        return Row(
                          children: [
                            Text('#${reverseIndex + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                            const SizedBox(width: 12),
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.amber.shade700,
                              child: Text('$ballNumber', style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 16),
                            Text('Ball $ballNumber called', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          isMobileViewport ? _buildMobileLayout() : _buildDesktopLayout(),
          if (_showVictoryOverlay)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showVictoryOverlay = false),
                child: CustomPaint(
                  painter: ConfettiPainter(particles: _confetti),
                  child: Container(
                    color: Colors.black.withOpacity(0.2),
                    alignment: Alignment.center,
                    child: Card(
                      color: Colors.white,
                      elevation: 12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events, size: 72, color: Colors.amber),
                            const SizedBox(height: 12),
                            const Text('BINGO!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.indigo)),
                            const Text('Claim Verified!', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => setState(() => _showVictoryOverlay = false),
                              child: const Text('Continue'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildGameplayCanvas()),
        VerticalDivider(width: 1, color: Colors.grey[400]),
        Expanded(flex: 1, child: _buildSidebarPanel()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(child: _buildGameplayCanvas()),
        ExpansionTile(
          title: Text("Room Chat (${_chatMessages.length})", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.indigo[50],
          children: [
            SizedBox(height: 220, child: _buildSidebarPanel()),
          ],
        ),
      ],
    );
  }

  Widget _buildGameplayCanvas() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.indigo[900],
          padding: const EdgeInsets.all(4),
          child: Text(_gameStatusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
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
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.amber[700],
                        child: Text(_currentDrawnNumber != null ? '$_currentDrawnNumber' : '--', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Text("Ticket Fee: $_ticketPrice", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.indigo)),
                  Text("Drawn: ${_drawnNumbers.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                            margin: const EdgeInsets.symmetric(vertical: 3.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.indigo.shade300, width: 1.2),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
                                  color: Colors.indigo.shade50,
                                  child: Text('TICKET #${ticketIndex + 1}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.indigo.shade700)),
                                ),
                                Table(
                                  border: TableBorder.all(color: Colors.grey.shade200, width: 1.0),
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
                                            color: displayText.isEmpty ? Colors.grey.shade50 : (isDaubed ? Colors.amber.shade50 : Colors.white),
                                            alignment: Alignment.center,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Text(
                                                  displayText,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 13,
                                                    color: isDaubed ? Colors.amber.shade900 : Colors.black87,
                                                  ),
                                                ),
                                                if (isDaubed && displayText.isNotEmpty)
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.amber.withOpacity(0.25),
                                                      border: Border.all(color: Colors.amber.shade700, width: 1.5),
                                                    ),
                                                    margin: const EdgeInsets.all(2),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    );
                                  }),
                                ),
                              ],
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
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  const Text("Claim Target: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedClaimType,
                      isDense: true,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: "one_line", child: Text("1 Line (5 Numbers)", style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: "two_lines", child: Text("2 Consecutive Lines (10 Numbers)", style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: "full_house", child: Text("Full House (15 Numbers)", style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedClaimType = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text("CLAIM STAGE BINGO!"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 38),
                      ),
                      onPressed: _claimCurrentStage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.exit_to_app, color: Colors.redAccent, size: 18),
                    label: const Text("Quit", style: TextStyle(color: Colors.redAccent)),
                    onPressed: _confirmQuitGame,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarPanel() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.indigo[50],
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ball Pool Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.indigo.shade700, borderRadius: BorderRadius.circular(4)),
                      child: Text('${90 - _drawnNumbers.length} LEFT', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (90 - _drawnNumbers.length) / 90,
                    minHeight: 5,
                    backgroundColor: Colors.indigo.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade400),
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 6.0), child: Divider(height: 1, thickness: 0.5)),
                const Text('Active Players', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.indigo)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: _activePlayers.map((user) {
                    final isMe = user == widget.username;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.indigo.withOpacity(0.15), width: 0.6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.greenAccent, blurRadius: 2, spreadRadius: 0.5)],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(user, style: TextStyle(fontSize: 10, fontWeight: isMe ? FontWeight.bold : FontWeight.normal, color: isMe ? Colors.indigo : Colors.black87)),
                        ],
                      ),
                    );
                  }).toList(),
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              padding: const EdgeInsets.all(12.0),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final msg = _chatMessages[index];
                final isMe = msg['username'] == widget.username;
                final displayTime = msg['time'] ?? '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isMe) Text(msg['username']!, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          Text(displayTime, style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.indigo[500] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(msg['message']!, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 12)),
                      ),
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
                    decoration: const InputDecoration(hintText: 'Type message...', contentPadding: EdgeInsets.symmetric(horizontal: 8.0), border: OutlineInputBorder()),
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => _sendChatMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.indigo, size: 20),
                  onPressed: _sendChatMessage,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

enum ConfettiShape { rectangle, square, triangle, circle }

class _ConfettiParticle {
  double x, y, size, speedY, speedX, rotation;
  Color color;
  ConfettiShape shape;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.speedY,
    required this.speedX,
    required this.rotation,
    required this.shape,
  });
}

class ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var p in particles) {
      paint.color = p.color;
      canvas.save();
      canvas.translate((p.x / 400) * size.width, p.y);
      canvas.rotate(p.rotation);
      switch (p.shape) {
        case ConfettiShape.rectangle:
          canvas.drawRect(Rect.fromLTWH(-p.size / 2, -p.size * 0.75, p.size, p.size * 1.5), paint);
          break;
        case ConfettiShape.square:
          canvas.drawRect(Rect.fromLTWH(-p.size / 2, -p.size / 2, p.size, p.size), paint);
          break;
        case ConfettiShape.circle:
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
          break;
        case ConfettiShape.triangle:
          final path = Path();
          path.moveTo(0, -p.size / 2);
          path.lineTo(p.size / 2, p.size / 2);
          path.lineTo(-p.size / 2, p.size / 2);
          path.close();
          canvas.drawPath(path, paint);
          break;
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}