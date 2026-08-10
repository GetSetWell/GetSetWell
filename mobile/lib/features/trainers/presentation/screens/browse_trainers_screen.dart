import 'package:flutter/material.dart';

class BrowseTrainersScreen extends StatelessWidget {
  const BrowseTrainersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF000D1B),
      body: SafeArea(
        child: Center(
          child: Text('Browse Trainers', style: TextStyle(color: Colors.white, fontSize: 24)),
        ),
      ),
    );
  }
}
