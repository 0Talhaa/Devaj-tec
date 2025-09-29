import 'package:flutter/material.dart';

class PendingOrdersPage extends StatelessWidget {
  const PendingOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Orders'),
        backgroundColor: const Color(0xFF0D1D20),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Aap Pending Orders Page par hain!',
          style: TextStyle(fontSize: 24, fontFamily: 'Raleway'),
        ),
      ),
    );
  }
}
