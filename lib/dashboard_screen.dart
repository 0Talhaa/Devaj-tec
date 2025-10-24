import 'package:flutter/material.dart';
import 'package:start_app/main.dart'; // For color constants
import 'package:start_app/new_order_types_page.dart';
import 'package:start_app/running_orders_page.dart';
import 'package:start_app/web_view_screen.dart';
import 'package:start_app/login_screen.dart'; // Added for logout functionality
import 'package:start_app/database_halper.dart';
class DashboardScreen extends StatelessWidget {
  final String userName;
  final int tiltId;
  final String tiltName;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.tiltId,
    required this.tiltName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
appBar: AppBar(
  backgroundColor: Colors.transparent,
  elevation: 0,
  foregroundColor: kPrimaryColor,

  // Disable default title alignment
  automaticallyImplyLeading: false,

  title: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // 👈 Left side: Logout button
      IconButton(
        icon: const Icon(Icons.logout),
        tooltip: 'Logout',
        onPressed: () async {
          await DatabaseHelper.instance.clearLoggedInUser();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => LoginScreen(
                  tiltId: tiltId,
                  tiltName: tiltName,
                ),
              ),
              (route) => false,
            );
          }
        },
      ),

      // 👉 Right side: Dashboard text
      const Text(
        'DASHBOARD',
        style: TextStyle(
          fontFamily: 'Raleway',
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
    ],
  ),
),

      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kTertiaryColor, Color(0xFF1D3538)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return constraints.maxWidth > 600
                ? _buildLargeScreenLayout(context)
                : _buildSmallScreenLayout(context);
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
                    color: kInputBgColor, // Consistent with main.dart
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
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error, color: Colors.red, size: 150),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          'WELCOME ${userName.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 28, // Slightly reduced for accessibility
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor,
                            fontFamily: 'Raleway',
                            shadows: [
                              Shadow(
                                blurRadius: 8.0,
                                color: kPrimaryColor,
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
                    color: kInputBgColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      // BoxShadow(
                      //   color: Colors.black.withOpacity(0.2),
                      //   spreadRadius: 5,
                      //   blurRadius: 15,
                      //   offset: const Offset(0, 8),
                      // ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          const WebViewScreen(url: 'https://163.61.91.48:5000/'), // Changed to HTTPS
                        ),
                      ],
                    ),
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
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.error, color: Colors.red, size: 150),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Welcome, ${userName.toUpperCase()}!',
                  style: const TextStyle(
                    fontSize: 24, // Slightly reduced for accessibility
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                    fontFamily: 'Raleway',
                    shadows: [
                      Shadow(
                        blurRadius: 8.0,
                        color: kPrimaryColor,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Tilt: $tiltName (ID: $tiltId)', // Added to display tilt info
                  style: const TextStyle(
                    fontSize: 14,
                    color: kSecondaryColor,
                    fontFamily: 'Raleway',
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
                  const WebViewScreen(url: 'https://163.61.91.48:5000/'), // Changed to HTTPS
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
    BuildContext context,
    String title,
    IconData icon,
    Widget page,
  ) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
      icon: Icon(icon, color: kTertiaryColor, size: 28),
      label: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Raleway',
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryColor,
        foregroundColor: kTertiaryColor,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.5),
      ),
    );
  }
}