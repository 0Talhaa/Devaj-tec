import 'package:flutter/material.dart';

class TakeAwayPage extends StatelessWidget {
  const TakeAwayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Away'),
        backgroundColor: const Color(0xFF0D1D20),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Aap Take Away Page par hain!',
          style: TextStyle(fontSize: 24, fontFamily: 'Raleway'),
        ),
      ),
    );
  }
}
