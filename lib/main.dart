import 'package:flutter/material.dart';
import 'screens/music_list_screen.dart';

void main() {
  runApp(const MusicPlayerApp());
}

class MusicPlayerApp extends StatefulWidget {
  const MusicPlayerApp({super.key});

  @override
  State<MusicPlayerApp> createState() => _MusicPlayerApp();
}

class _MusicPlayerApp extends State<MusicPlayerApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MusicListScreen(),
    );
  }
}
