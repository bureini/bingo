// Triggering the workflow
//Bingo web app
import 'package:flutter/material.dart';

void main() {
  runApp(const CampaignApp());
}

class CampaignApp extends StatelessWidget {
  const CampaignApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Community Clean-Up 2026',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A86B), // Eco-friendly green
          primary: const Color(0xFF00A86B),
          secondary: const Color(0xFF2E7D32),
        ),
      ),
      home: const CampaignHomePage(),
    );
  }
}

class CampaignHomePage extends StatelessWidget {
  const CampaignHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Using LayoutBuilder to make the UI responsive
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EcoAware',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Campaign link copied to clipboard!')),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // If the screen width is greater than 600, it's treated as a tablet/wide view
          bool isWideScreen = constraints.maxWidth > 600;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Hero Campaign Banner Section
                  _buildHeroBanner(context, isWideScreen),
                  const SizedBox(height: 24),

                  // 2. Impact Stats Section (Responsive Layout)
                  const Text(
                    'Our Impact So Far',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  isWideScreen 
                      ? Row(
                          children: [
                            Expanded(child: _buildStatCard('5,000+', 'Tons of Plastic Recycled', Colors.green.shade100)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildStatCard('12,000+', 'Volunteers Mobilized', Colors.blue.shade100)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildStatCard('5,000+', 'Tons of Plastic Recycled', Colors.green.shade100),
                            const SizedBox(height: 12),
                            _buildStatCard('12,000+', 'Volunteers Mobilized', Colors.blue.shade100),
                          ],
                        ),
                  const SizedBox(height: 24),

                  // 3. Main Message / Mission Statement
                  const Text(
                    'Why It Matters',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Our planet is facing unprecedented environmental challenges. Through community awareness and direct local action, we can build a sustainable future. Join our daily clean-up drives and educational webinars to make a lasting difference.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.5),
                  ),
                  const SizedBox(height: 32),

                  // 4. Call to Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
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
