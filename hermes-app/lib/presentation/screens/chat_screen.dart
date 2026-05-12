import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  final String roomId;
  const ChatScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Chat Screen - Room: $roomId'),
      ),
    );
  }
}
