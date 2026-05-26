import 'package:flutter/material.dart';

import '../pages/practice_page.dart';

class WordPracticeApp extends StatelessWidget {
  const WordPracticeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '英文單字練習',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Arial',
        visualDensity: VisualDensity.compact,
      ),
      home: const PracticePage(),
    );
  }
}
