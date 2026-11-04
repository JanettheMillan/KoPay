import 'package:flutter/material.dart';

void main() {
  runApp(const KopayApp());
}

class KopayApp extends StatelessWidget {
  const KopayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Kopay',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: Text('kopay')),
      ),
    );
  }
}
