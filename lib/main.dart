import 'dart:convert';
import 'dart:math';
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
      home: const BingoGamePage(),
    );
  }
}

class BingoGamePage extends StatefulWidget {
  const BingoGamePage({super.key});

  @override
  State<BingoGamePage> createState() => _BingoGamePageState();
}

class _BingoGamePageState extends State<BingoGamePage> {
  final List<List<bool>> _daubedStates = List.generate(5, (_) => List.filled(5, false));
  late List<List<String>> _bingoCardNumbers;
  
  WebSocketChannel? _channel;
  final List<int> _drawnNumbers = []; 
  int? _currentDrawnNumber;
  bool _isConnected = false;

  // UPDATED: Public testing WebSocket URL. 
  // When you deploy your custom Python/Node.js backend later, replace this with your backend domain.
  final String _wsUrl = 'wss://echo.websocket.events';

  @override
  void initState() {
    super.initState();
    _generateStandardBingoCard();
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      setState(() => _isConnected = true);

      _channel!.stream.listen(
        (message) {
          // The testing echo server echoes back whatever we send it.
          // This section processes the server stream safely.
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'number_drawn') {
              setState(() {
                int newNumber = data['number'];
                _currentDrawnNumber = newNumber;
                _drawnNumbers.add(newNumber);
              });
            } else if (data['action'] == 'claim_bingo') {
              // Echo testing mock response simulation:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎉 Testing Mode: Bingo Claim Sent & Received by Echo Server!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            // Raw text fallback if the test server sends a welcome text broadcast string
            debugPrint("Received broadcast text: $message");
          }
        },
        onError: (error) => setState(() => _isConnected = false),
        onDone: () => setState(() => _isConnected = false),
      );
    } catch (e) {
      setState(() => _isConnected = false);
    }
  }

  void _generateStandardBingoCard() {
    final random = Random();
    List<List<int>> columns = [];
    
    for (int i = 0; i < 5; i++) {
      int min = (i * 15) + 1;
      Set<int> columnNumbers = {};
      while (columnNumbers.length < 5) {
        columnNumbers.add(min + random.nextInt(15));
      }
      columns.add(columnNumbers.toList());
    }

    _bingoCardNumbers = List.generate(5, (row) {
      return List.generate(5, (col) {
        if (row == 2 && col == 2) {
          _daubedStates[row][col] = true; 
          return "FREE";
        }
        return columns[col][row].toString();
      });
    });
  }

  void _claimBingo() {
    if (_channel == null || !_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to game server!')),
      );
      return;
    }

    // Secure Verification payload structural blueprint
    final payload = {
      'action': 'claim_bingo',
      'card': _bingoCardNumbers,
      'daubed': _daubedStates,
    };

    _channel!.sink.add(jsonEncode(payload));
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isConnected ? 'Live Multiplayer Bingo 🟢' : 'Connecting to Server... 🔴'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey[100],
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(16.0),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('CURRENT NUMBER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.amber[700],
                          child: Text(
                            _currentDrawnNumber != null ? '$_currentDrawnNumber' : '--',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('RECENT DRAWS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: _drawnNumbers.reversed.skip(1).take(4).map((num) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8EAF6),
                              shape: BoxShape.circle,
                            ),
                            child: Text('$num', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                          )).toList(),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const ['B', 'I', 'N', 'G', 'O'].map((letter) => Expanded(
                          child: Center(
                            child: Text(
                              letter,
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.indigo),
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 8),
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
                            String val = _bingoCardNumbers[row][col];
                            bool isDaubed = _daubedStates[row][col];

                            return GestureDetector(
                              onTap: () {
                                if (row == 2 && col == 2) return;
                                setState(() {
                                  _daubedStates[row][col] = !isDaubed;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFC5CAE9), width: 1.5),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, offset: Offset(0, 2), blurRadius: 4)
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(
                                      val,
                                      style: TextStyle(
                                        fontSize: val == "FREE" ? 14 : 20,
                                        fontWeight: FontWeight.bold,
                                        color: val == "FREE" ? Colors.amber[900] : Colors.black87,
                                      ),
                                    ),
                                    if (isDaubed)
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.red.withOpacity(0.45),
                                        ),
                                        margin: const EdgeInsets.all(6),
                                      ),
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
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ElevatedButton(
                  onPressed: _claimBingo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('BINGO!'),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
