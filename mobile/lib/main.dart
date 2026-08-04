import 'package:flutter/material.dart';

void main() {
  runApp(const GetSetWellApp());
}

class GetSetWellApp extends StatelessWidget {
  const GetSetWellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GetSetWell',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text('GetSetWell'),
        ),
      ),
    );
  }
}