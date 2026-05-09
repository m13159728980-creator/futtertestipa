import 'package:flutter/material.dart';

void main() {
  runApp(const PrivateChatApp());
}

class PrivateChatApp extends StatelessWidget {
  const PrivateChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Private Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const PrivateChatShell(),
    );
  }
}

class PrivateChatShell extends StatelessWidget {
  const PrivateChatShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Private Chat'),
      ),
    );
  }
}
