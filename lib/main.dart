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

  // Mock server state
  final List<int> _drawnNumbers = [42, 7, 68]; 
  final int _currentDrawnNumber = 68;

  @override
  void initState() {
    super.initState();
    _generateStandardBingoCard();
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
          _daubedStates[row][col] = true; // Auto-daub free space
          return "FREE";
        }
        return columns[col][row].toString();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Multiplayer Bingo'),
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
                            '$_currentDrawnNumber',
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
                          children: _drawnNumbers.reversed.skip(1).map((num) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8EAF6), // Stable Indigo 100 hex
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
                  maxWidth: 450,
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
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.black, color: Colors.indigo),
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
                                  border: Border.all(color: const Color(0xFFC5CAE9), width: 1.5), // Stable Indigo 200 hex
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
                                          color: Colors.red.withOpacity(0.45), // Swapped to withOpacity
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Checking Board with Server... 🤞')),
                    );
                  },
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
