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
      title: 'Responsive Bingo',
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

  @override
  void initState() {
    super.initState() {
      _generateNewCard();
    }
  }

  void _generateNewCard() {
    cardNumbers = List.generate(5, (_) => List.filled(5, 0));
    markedCells = List.generate(5, (_) => List.filled(5, false));
    calledNumbers.clear();
    lastCalledNumber = null;

    // Generate standard Bingo columns: B:1-15, I:16-30, N:31-45, G:46-60, O:61-75
    for (int col = 0; col < 5; col++) {
      List<int> pool = List.generate(15, (i) => (col * 15) + i + 1);
      pool.shuffle(_random);
      for (int row = 0; row < 5; row++) {
        cardNumbers[row][col] = pool[row];
      }
    }
    // FREE SPACE in the center (row 2, col 2)
    markedCells[2][2] = true;
  }

  void _callNextNumber() {
    if (calledNumbers.length >= 75) return;

    int nextNum;
    do {
      nextNum = _random.nextInt(75) + 1;
    } while (calledNumbers.contains(nextNum));

    setState(() {
      calledNumbers.add(nextNum);
      lastCalledNumber = nextNum;
    });
  }

  bool _checkWinCondition() {
    // Check rows
    for (int i = 0; i < 5; i++) {
      if (markedCells[i].every((cell) => cell)) return true;
    }
    // Check columns
    for (int col = 0; col < 5; col++) {
      if (List.generate(5, (row) => markedCells[row][col]).every((cell) => cell)) return true;
    }
    // Check Diagonals
    if (List.generate(5, (i) => markedCells[i][i]).every((cell) => cell)) return true;
    if (List.generate(5, (i) => markedCells[i][4 - i]).every((cell) => cell)) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen layout using LayoutBuilder for responsiveness
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎉 Live Online Bingo 🎉', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(_generateNewCard),
            tooltip: 'New Game Card',
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(color: Colors.deepPurple.shade50),
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isDesktop = constraints.maxWidth > 800;
            
            if (isDesktop) {
              // Side-by-side layout for desktop/tablets
              return Row(
                children: [
                  Expanded(flex: 3, child: _buildAnnouncerPanel()),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 4, child: Center(child: SingleChildScrollView(child: _buildBingoCard(constraints.maxHeight)))),
                ],
              );
            } else {
              // Stacked layout for mobile phones
              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildAnnouncerPanel(),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
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
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.deepPurple.shade400, Colors.purple.shade700]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text('LAST CALLED NUMBER', style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  Text(
                    lastCalledNumber != null ? '$letter-$lastCalledNumber' : '--',
                    style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onPressed: _callNextNumber,
            icon: const Icon(Icons.volume_up),
            label: const Text('CALL NEXT NUMBER'),
          ),
          const SizedBox(height: 20),
          const Text('Called Numbers History:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: calledNumbers.map((num) {
              return Chip(
                backgroundColor: Colors.purple.shade100,
                label: Text('$num', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildBingoCard(double availableSize) {
    // Constrain size so it stays square and fits snugly on any screen
    double cardWidth = min(availableSize * 0.9, 450);

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Letter Headers (B I N G O)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: columns.map((letter) => Expanded(
              child: Center(
                child: Text(
                  letter,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.black, color: Colors.deepPurple),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          // Grid view for numbers
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 25,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              int row = index ~/ 5;
              int col = index % 5;
              bool isFreeSpace = row == 2 && col == 2;
              int val = cardNumbers[row][col];
              bool isMarked = markedCells[row][col];

              return InkWell(
                onTap: () {
                  if (isFreeSpace) return;
                  setState(() {
                    markedCells[row][col] = !markedCells[row][col];
                    if (_checkWinCondition()) {
                      _showWinDialog();
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isFreeSpace 
                        ? Colors.amber.shade200 
                        : (isMarked ? Colors.green.shade400 : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isMarked ? Colors.green.shade700 : Colors.grey.shade300, 
                      width: 2
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isFreeSpace ? 'FREE' : '$val',
                      style: TextStyle(
                        fontSize: isFreeSpace ? 12 : 18,
                        fontWeight: FontWeight.bold,
                        color: isMarked || isFreeSpace ? Colors.white : Colors.black87,
                        shadows: isMarked || isFreeSpace ? [const Shadow(blurRadius: 2, color: Colors.black25)] : null,
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

  void _showWinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 BINGO! 🎉', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        content: const Text('Congratulations! You filled a winning line!', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: TextButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(context).pop();
              setState(_generateNewCard);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Play Again'),
            ),
          ),
        ],
      ),
    );
  }
}                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showJoinDialog(context);
                      },
                      icon: const Icon(Icons.favorite, color: Colors.white),
                      label: const Text(
                        'JOIN THE MOVEMENT',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper widget to build the adaptive Hero Banner
  Widget _buildHeroBanner(BuildContext context, bool isWideScreen) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: EdgeInsets.symmetric(
        vertical: isWideScreen ? 40.0 : 24.0,
        horizontal: 24.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.semibold(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'CAMPAIGN LIVE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Protect Our Oceans,\nSave Tomorrow.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Join thousands of citizens taking a stand against plastic pollution this month.',
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15),
          ),
        ],
      ),
    );
  }

  // Helper widget to build statistic cards
  Widget _buildStatCard(String count, String label, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // CTA Interaction Dialog
  void _showJoinDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thank You for Stepping Up!'),
        content: const Text('Enter your email to receive toolkits, local event updates, and volunteer guides.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Welcome aboard! Check your inbox soon.')),
              );
            },
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }
}
