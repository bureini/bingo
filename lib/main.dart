import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const BingoApp());
}

class BingoApp extends StatelessWidget {
  const BingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Automated Live Bingo',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const BingoScreen(),
    );
  }
}

class BingoScreen extends StatefulWidget {
  const BingoScreen({super.key});

  @override
  State<BingoScreen> createState() => _BingoScreenState();
}

class _BingoScreenState extends State<BingoScreen> {
  final List<String> columns = ['B', 'I', 'N', 'G', 'O'];
  late List<List<int>> cardNumbers;
  late List<List<bool>> markedCells;
  List<int> calledNumbers = [];
  int? lastCalledNumber;
  final Random _random = Random();
  
  Timer? _callerTimer;
  bool _isGameRunning = false;
  String _serverStatus = "Waiting to Start...";

  @override
  void initState() {
    super.initState();
    _generateNewCard();
  }

  @override
  void dispose() {
    _callerTimer?.cancel();
    super.dispose();
  }

  void _generateNewCard() {
    _callerTimer?.cancel();
    cardNumbers = List.generate(5, (_) => List.filled(5, 0));
    markedCells = List.generate(5, (_) => List.filled(5, false));
    calledNumbers.clear();
    lastCalledNumber = null;
    _isGameRunning = false;
    _serverStatus = "Ready. Press Start Game!";

    for (int col = 0; col < 5; col++) {
      List<int> pool = List.generate(15, (i) => (col * 15) + i + 1);
      pool.shuffle(_random);
      for (int row = 0; row < 5; row++) {
        cardNumbers[row][col] = pool[row];
      }
    }
    markedCells[2][2] = true; // FREE Space
  }

  void _startGame() {
    setState(() {
      _isGameRunning = true;
      _serverStatus = "Server Online: Calling numbers...";
    });
    _callerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _callNextNumber();
    });
  }

  void _callNextNumber() {
    if (calledNumbers.length >= 75) {
      _callerTimer?.cancel();
      setState(() {
        _serverStatus = "Game Over: All numbers called.";
      });
      return;
    }

    int nextNum;
    do {
      nextNum = _random.nextInt(75) + 1;
    } while (calledNumbers.contains(nextNum));

    setState(() {
      calledNumbers.add(nextNum);
      lastCalledNumber = nextNum;
    });
  }

  void _verifyBingoClaim() {
    bool hasWinningLine = false;

    // Check Rows
    for (int i = 0; i < 5; i++) {
      if (markedCells[i].every((cell) => cell)) hasWinningLine = true;
    }
    // Check Columns
    for (int col = 0; col < 5; col++) {
      if (List.generate(5, (row) => markedCells[row][col]).every((cell) => cell)) hasWinningLine = true;
    }
    // Check Diagonals
    if (List.generate(5, (i) => markedCells[i][i]).every((cell) => cell)) hasWinningLine = true;
    if (List.generate(5, (i) => markedCells[i][4 - i]).every((cell) => cell)) hasWinningLine = true;

    // Fraud Scrutineer
    bool fraudDetected = false;
    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 5; col++) {
        if (row == 2 && col == 2) continue;
        if (markedCells[row][col] && !calledNumbers.contains(cardNumbers[row][col])) {
          fraudDetected = true;
        }
      }
    }

    if (hasWinningLine && !fraudDetected) {
      _callerTimer?.cancel();
      _showResultDialog(title: "🎉 BINGO WINNER! 🎉", message: "The server successfully verified your card configurations. You won!");
    } else if (fraudDetected) {
      _showResultDialog(title: "❌ Verification Failed ❌", message: "Invalid claim! You marked spaces that the host server hasn't called yet.");
    } else {
      _showResultDialog(title: "⚠️ Incomplete Card ⚠️", message: "The server scanned your card layout, but you don't have a complete row, column, or diagonal line yet.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🕹️ Server-Driven Bingo Room', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(_generateNewCard),
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(color: Colors.deepPurple.shade50),
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isDesktop = constraints.maxWidth > 800;
            
            if (isDesktop) {
              return Row(
                children: [
                  Expanded(flex: 3, child: _buildAnnouncerPanel()),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 4, child: Center(child: SingleChildScrollView(child: _buildBingoCard(constraints.maxHeight)))),
                ],
              );
            } else {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildAnnouncerPanel(),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: _buildBingoCard(constraints.maxWidth),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildAnnouncerPanel() {
    String letter = '';
    if (lastCalledNumber != null) {
      int idx = ((lastCalledNumber! - 1) ~/ 15).clamp(0, 4);
      letter = columns[idx];
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _serverStatus,
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: _isGameRunning ? Colors.green.shade700 : Colors.red.shade700, 
              fontSize: 16
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 6,
            child: Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.deepPurple.shade400, Colors.purple.shade700]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('LIVE SERVER CALL', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1.5)),
                  const SizedBox(height: 5),
                  Text(
                    lastCalledNumber != null ? '$letter-$lastCalledNumber' : '--',
                    style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          if (!_isGameRunning)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
              onPressed: _startGame,
              child: const Text('START ROOM CALLER'),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
              onPressed: _verifyBingoClaim,
              child: const Text('🔔 BINGO! CLAIM WIN 🔔', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 15),
          const Text('Server Log History:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 6),
          SizedBox(
            maxHeight: 120,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: calledNumbers.reversed.map((num) {
                  return Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.purple.shade50,
                    label: Text('$num', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBingoCard(double availableSize) {
    double cardWidth = min(availableSize * 0.9, 420);

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: columns.map((letter) => Expanded(
              child: Center(
                child: Text(letter, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 25,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
            ),
            itemBuilder: (context, index) {
              int row = index ~/ 5;
              int col = index % 5;
              bool isFreeSpace = row == 2 && col == 2;
              int val = cardNumbers[row][col];
              bool isMarked = markedCells[row][col];

              return InkWell(
                onTap: () {
                  if (isFreeSpace || !_isGameRunning) return;
                  setState(() {
                    markedCells[row][col] = !markedCells[row][col];
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isFreeSpace 
                        ? Colors.amber.shade200 
                        : (isMarked ? Colors.green.shade400 : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isMarked ? Colors.green.shade700 : Colors.grey.shade300, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      isFreeSpace ? 'FREE' : '$val',
                      style: TextStyle(
                        fontSize: isFreeSpace ? 11 : 16,
                        fontWeight: FontWeight.bold,
                        color: isMarked || isFreeSpace ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showResultDialog({required String title, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: TextButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(context).pop();
              if (title.contains("WINNER")) {
                setState(_generateNewCard);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}