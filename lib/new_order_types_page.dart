import 'package:flutter/material.dart';
import 'package:start_app/dining_page.dart';
import 'package:start_app/take_away_page.dart';
import 'package:start_app/delivery_page.dart';

class NewOrdersPage extends StatelessWidget {
  const NewOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Order Type'),
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
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/devaj_logo.png',
                  width: 150,
                  height: 150,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'New Order For',
                style: TextStyle(
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
              const SizedBox(height: 64),
              _buildButton(
                context,
                'Dining',
                Icons.restaurant_menu,
                const DiningPage(),
              ),
              const SizedBox(height: 32),
              _buildButton(
                context,
                'Take Away',
                Icons.shopping_bag,
                const TakeAwayPage(),
              ),
              const SizedBox(height: 32),
              _buildButton(
                context,
                'Delivery',
                Icons.delivery_dining,
                const DeliveryPage(),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 48),
            Center(
              child: Image.asset(
                'assets/devaj_logo.png',
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'New Order For',
              style: TextStyle(
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
            _buildButton(
              context,
              'Dining',
              Icons.restaurant_menu,
              const DiningPage(),
            ),
            const SizedBox(height: 24),
            _buildButton(
              context,
              'Take Away',
              Icons.shopping_bag,
              const TakeAwayPage(),
            ),
            const SizedBox(height: 24),
            _buildButton(
              context,
              'Delivery',
              Icons.delivery_dining,
              const DeliveryPage(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(
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
