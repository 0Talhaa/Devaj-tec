import 'package:flutter/material.dart';

class DeliveryPage extends StatelessWidget {
  const DeliveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery'),
        backgroundColor: const Color(0xFF0D1D20),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Aap Delivery Page par hain!',
          style: TextStyle(fontSize: 24, fontFamily: 'Raleway'),
        ),
      ),
    );
  }
}
