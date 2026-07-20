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
              items: ["90-Ball (6-Ticket Book)"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
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

class _BingoGamePageState extends State<BingoGamePage> with SingleTickerProviderStateMixin {
  List<List<List<bool>>> _bookDaubedStates = List.generate(6, (_) => List.generate(3, (_) => List.filled(9, false)));
  List<List<List<dynamic>>> _ticketBookNumbers = List.generate(6, (_) => List.generate(3, (_) => List.filled(9, 0)));
  WebSocketChannel? _channel;
  bool _isChannelConnected = false;
  final List<int> _drawnNumbers = [];
  int? _currentDrawnNumber;
  String _gameStatusMessage = "Connecting...";

  // Real-time Messaging & Presence Registries
  final List<Map<String, String>> _chatMessages = [];
  final List<String> _activePlayers = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // Procedural Particle Victory Overlay
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
            case 'room_rules_changed':
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
              break;
            case 'game_over':
              setState(() {
                final winner = data['winner'];
                _gameStatusMessage = winner != null ? "🏆 Winner: $winner!" : "Game Over";
                
                if (winner == widget.username) {
                  _showVictoryOverlay = true;
                  _initializeConfetti();
                  _victoryController?.repeat();
                }
              });
              break;
            case 'system_disconnect':
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.red));
              break;
          }
        },
        onDone: () {
          setState(() {
            _isChannelConnected = false;
            _gameStatusMessage = "Connection Stalled. Reconnect required.";
          });
        },
        onError: (error) {
          setState(() {
            _isChannelConnected = false;
            _gameStatusMessage = "Network error encountered.";
          });
        },
      );
    } catch (_) {
      setState(() {
        _isChannelConnected = false;
        _gameStatusMessage = "Failed to establish link.";
      });
    }
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'action': 'send_chat',
        'message': text,
      }));
      _chatController.clear();
    }
  }

  void _initializeConfetti() {
    final random = math.Random();
    _confetti = List.generate(120, (index) {
      final shapeTypes = ConfettiShape.values;
      final assignedShape = shapeTypes[random.nextInt(shapeTypes.length)];

      return _ConfettiParticle(
        x: random.nextDouble() * 400,
        y: -random.nextDouble() * 200,
        color: Colors.primaries[random.nextInt(Colors.primaries.length)],
        size: random.nextDouble() * 7 + 5,
        speedY: random.nextDouble() * 3 + 2,
        speedX: random.nextDouble() * 2 - 1,
        rotation: random.nextDouble() * math.pi,
        shape: assignedShape,
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobileViewport = screenWidth < 768;

    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        title: const Text('My Bingo Playroom'), 
        backgroundColor: Colors.indigo, 
        foregroundColor: Colors.white, 
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isChannelConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isChannelConnected ? Colors.greenAccent : Colors.redAccent,
            ),
            tooltip: _isChannelConnected ? 'Connection Healthy' : 'Link Offline - Tap to Reconnect',
            onPressed: () {
              if (!_isChannelConnected) {
                _connectToWebSocket();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Attempting recovery handshakes...")),
                );
              }
            },
          ),
          if (widget.username == 'BingoDev')
            IconButton(
              icon: Icon(
                _showVictoryOverlay ? Icons.celebration : Icons.developer_mode,
                color: _showVictoryOverlay ? Colors.amberAccent : Colors.white70,
              ),
              tooltip: 'Test Victory Splash Overlay',
              onPressed: () {
                setState(() {
                  _showVictoryOverlay = !_showVictoryOverlay;
                  if (_showVictoryOverlay) {
                    _initializeConfetti();
                    _victoryController?.repeat();
                  } else {
                    _victoryController?.stop();
                  }
                });
              },
            ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Draw History',
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
                      separatorBuilder: (context, index) => const Divider(height: 12, thickness: 0.5),
                      itemBuilder: (context, index) {
                        final reverseIndex = _drawnNumbers.length - 1 - index;
                        final ballNumber = _drawnNumbers[reverseIndex];
                        final sequentialCall = reverseIndex + 1;

                        return Row(
                          children: [
                            Container(
                              width: 32,
                              alignment: Alignment.center,
                              child: Text('#$sequentialCall', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                            ),
                            const SizedBox(width: 12),
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.amber.shade700,
                              child: Text('$ballNumber', style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 16),
                            Text('Ball $ballNumber called', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
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
          isMobileViewport 
            ? _buildMobileLayout() 
            : _buildDesktopLayout(),

          if (_showVictoryOverlay)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ConfettiPainter(particles: _confetti),
                  child: Container(
                    color: Colors.black.withOpacity(0.15),
                    alignment: Alignment.center,
                    child: Card(
                      color: Colors.white.withOpacity(0.9),
                      elevation: 12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events, size: 80, color: Colors.amber),
                            SizedBox(height: 12),
                            Text('BINGO!', style: TextStyle(fontSize: 36, fontWeight: FontWeight.black, color: Colors.indigo, letterSpacing: 2)),
                            Text('Authoritative Full House Confirmed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
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
            SizedBox(
              height: 220,
              child: _buildSidebarPanel(),
            )
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
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.indigo.shade300, width: 1.2),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade50,
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5)),
                                  ),
                                  child: Text('TICKET #${ticketIndex + 1}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.indigo.shade700, letterSpacing: 0.5)),
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
                                                    fontWeight: FontWeight.black, 
                                                    fontSize: 13, 
                                                    color: isDaubed ? Colors.amber.shade900 : Colors.black87
                                                  ),
                                                ),
                                                if (isDaubed && displayText.isNotEmpty)
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.amber.withOpacity(0.25),
                                                      border: Border.all(color: Colors.amber.shade700, width: 1.5)
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
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: ElevatedButton(
            onPressed: () => _channel?.sink.add(jsonEncode({'action': 'claim_bingo'})),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            child: const Text("CLAIM BINGO!", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        )
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
                  mainAxisAlignment: MainAxisAlignment.between,
                  children: [
                    const Text('Ball Pool Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.indigo.shade700, borderRadius: BorderRadius.circular(4)),
                      child: Text('${90 - _drawnNumbers.length} LEFT', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.black, color: Colors.white)),
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
                              boxShadow: [BoxShadow(color: Colors.greenAccent, blurRadius: 2, spreadRadius: 0.5)]
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user,
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                              color: isMe ? Colors.indigo : Colors.black87
                            ),
                          ),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isMe) ...[
                              Text(msg['username']!, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 6),
                            ],
                            Text(displayTime, style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontWeight: FontWeight.w400)),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              Text(msg['username']!, style: const TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.indigo[500] : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: isMe ? const Radius.circular(14) : const Radius.circular(2),
                            bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(14),
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                          border: isMe ? null : Border.all(color: Colors.grey.shade300, width: 0.8),
                        ),
                        child: Text(
                          msg['message']!,
                          style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 13, height: 1.3),
                        ),
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
                    decoration: const InputDecoration(hintText: 'Type a message...', contentPadding: EdgeInsets.symmetric(horizontal: 8.0), border: OutlineInputBorder()),
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
  double x;
  double y;
  Color color;
  double size;
  double speedY;
  double speedX;
  double rotation;
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
      
      double renderX = (p.x / 400) * size.width;
      double renderY = p.y;
      
      canvas.translate(renderX, renderY);
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
