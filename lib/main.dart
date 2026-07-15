import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const BingoApp());
}

class BingoApp extends StatelessWidget {
  const BingoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real-Time Bingo',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const BingoGameScreen(),
    );
  }
}

class BingoGameScreen extends StatefulWidget {
  const BingoGameScreen({Key? key}) : super(key: key);

  @override
  State<BingoGameScreen> createState() => _BingoGameScreenState();
}

class _BingoGameScreenState extends State<BingoGameScreen> {
  // Replace with your actual production backend URL deployed on the bingo-backend branch
  final String _serverUrl = 'wss://your-bingo-backend-url.com/ws';
  late WebSocketChannel _channel;
  
  List<int> _drawnNumbers = [];
  List<List<int>> _bingoCard = [];
  Set<int> _daubedNumbers = {};
  String _gameStatus = "Connecting to game server...";

  @override
  void initState() {
    super.initState();
    _connectToGameServer();
  }

  void _connectToGameServer() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      _channel.stream.listen(
        (message) => _handleServerMessage(message),
        onError: (error) {
          setState(() => _gameStatus = "Connection error. Retrying...");
          Future.delayed(const Duration(seconds: 5), _connectToGameServer);
        },
        onDone: () {
          setState(() => _gameStatus = "Disconnected from server.");
        },
      );
    } catch (e) {
      setState(() => _gameStatus = "Failed to connect to server.");
    }
  }

  void _handleServerMessage(dynamic rawMessage) {
    final Map<String, dynamic> data = jsonDecode(rawMessage as String);
    final String action = data['action'] ?? '';

    setState(() {
      switch (action) {
        case 'INIT_CARD':
          // The server sends down a safe, randomized card matrix configuration
          _bingoCard = List<List<int>>.from(
            (data['card'] as List).map((row) => List<int>.from(row)),
          );
          _gameStatus = "Game joined! Waiting for the next ball...";
          break;

        case 'BALL_DRAWN':
          int ball = data['number'];
          _drawnNumbers.add(ball);
          _gameStatus = "Ball drawn: Number $ball";
          break;

        case 'GAME_OVER':
          String winner = data['winner'];
          _gameStatus = "Game Over! Winner: $winner";
          break;
      }
    });
  }

  void _daubNumber(int number) {
    // Client-side guard: Only allow marking a number if the server has drawn it or it's the FREE space (0)
    if (_drawnNumbers.contains(number) || number == 0) {
      setState(() {
        if (_daubedNumbers.contains(number)) {
          _daubedNumbers.remove(number);
        } else {
          _daubedNumbers.add(number);
        }
      });
    }
  }

  void _claimBingo() {
    // Transmit the payload to the server. 
    // The server will execute an absolute authority check to declare the official win.
    final payload = jsonEncode({
      'action': 'CLAIM_BINGO',
      'daubed': _daubedNumbers.toList(),
    });
    _channel.sink.add(payload);
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Multiplayer Bingo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(_gameStatus, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('Drawn Balls: ${_drawnNumbers.join(', ')}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 20),
            if (_bingoCard.isNotEmpty)
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
                  itemCount: 25,
                  itemBuilder: (context, index) {
                    int row = index ~/ 5;
                    int col = index % 5;
                    int number = _bingoCard[row][col];
                    bool isDaubed = _daubedNumbers.contains(number);

                    return GestureDetector(
                      onTap: () => _daubNumber(number),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: number == 0 
                              ? Colors.amber.shade200 // FREE Space decoration
                              : (isDaubed ? Colors.green.shade300 : Colors.grey.shade200),
                          border: Border.all(color: Colors.black25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            number == 0 ? 'FREE' : '$number',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ElevatedButton(
              onPressed: _claimBingo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text('BINGO!', style: TextStyle(fontSize: 20, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
