import 'package:flutter/material.dart';
import 'package:start_app/new_order_types_page.dart';
import 'package:start_app/running_orders_page.dart';
import 'package:start_app/web_view_screen.dart'; // Naya import

class DashboardScreen extends StatelessWidget {
  final String userName;
  final int tiltId;
  final String tiltName;

  const DashboardScreen({super.key, required this.userName, required this.tiltId, required this.tiltName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1D20),
              Color(0xFF1D3538),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return _buildLargeScreenLayout(context);
            } else {
              return _buildSmallScreenLayout(context);
            }
          },
        ),
      ),
    );
  }

  Widget _buildLargeScreenLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(48.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162A2D),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 5,
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/devaj_logo.png',
                          width: 150,
                          height: 150,
                        ),
                        const SizedBox(height: 30),
                        // Username ko uppercase mein show karne ke liye .toUpperCase() method ka use karein
                        Text(
                          "Welcome, ${userName.toUpperCase()}!",
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF75E5E2),
                            fontFamily: 'Raleway',
                            shadows: [
                              Shadow(
                                blurRadius: 10.0,
                                color: Color(0xFF75E5E2),
                                offset: Offset(0, 0),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(48.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162A2D),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 5,
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDashboardButton(
                        context,
                        'New Orders',
                        Icons.add_shopping_cart,
                        const NewOrdersPage(),
                      ),
                      const SizedBox(height: 24),
                      _buildDashboardButton(
                        context,
                        'Running Orders',
                        Icons.delivery_dining,
                        const RunningOrdersPage(),
                      ),
                      const SizedBox(height: 24),
                      _buildDashboardButton(
                        context,
                        'Open Web View',
                        Icons.public,
                        const WebViewScreen(url: 'http://163.61.91.48:5000/'), // Naya button
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallScreenLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Image.asset(
                    'assets/devaj_logo.png',
                    width: 150,
                    height: 150,
                  ),
                ),
                const SizedBox(height: 30),
                // Username ko uppercase mein show karne ke liye .toUpperCase() method ka use karein
                Text(
                  "Welcome, ${userName.toUpperCase()}!",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF75E5E2),
                    fontFamily: 'Raleway',
                    shadows: [
                      Shadow(
                        blurRadius: 8.0,
                        color: Color(0xFF75E5E2),
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                _buildDashboardButton(
                  context,
                  'New Orders',
                  Icons.add_shopping_cart,
                  const NewOrdersPage(),
                ),
                const SizedBox(height: 24),
                _buildDashboardButton(
                  context,
                  'Running Orders',
                  Icons.delivery_dining,
                  const RunningOrdersPage(),
                ),
                const SizedBox(height: 24),
                _buildDashboardButton(
                  context,
                  'Open Web View',
                  Icons.public,
                  const WebViewScreen(url: 'http://163.61.91.48:5000/'), // Naya button
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardButton(
      BuildContext context, String title, IconData icon, Widget page) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      icon: Icon(icon, color: const Color(0xFF0D1D20), size: 28),
      label: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Raleway',
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF75E5E2),
        foregroundColor: const Color(0xFF0D1D20),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.5),
      ),
    );
  }
}
