import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://qjimgaeizxbswxgldgcl.supabase.co/';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqaW1nYWVpenhic3d4Z2xkZ2NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk3MTA0NTcsImV4cCI6MjA5NTI4NjQ1N30.FWISDms_YBtRlfzYYHmsIov-7Gwpuv182BUmpeuxYMw';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const WordPracticeApp());
}

final supabase = Supabase.instance.client;

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
      ),
      home: const PracticePage(),
    );
  }
}

class WordItem {
  final int id;
  final String chinese;
  final String english;

  const WordItem({
    required this.id,
    required this.chinese,
    required this.english,
  });

  factory WordItem.fromMap(Map<String, dynamic> map) {
    return WordItem(
      id: map['id'] as int,
      chinese: map['chinese'] as String,
      english: map['english'] as String,
    );
  }
}

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _answerFocusNode = FocusNode();
  final Random _random = Random();

  List<WordItem> _words = [];
  WordItem? _currentWord;

  bool _loading = true;
  String? _errorMessage;

  int _correctCount = 0;
  int _wrongCount = 0;

  String? _resultText;
  bool? _lastAnswerCorrect;
  bool _hasCheckedCurrentQuestion = false;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _answerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final rows = await supabase
          .from('words')
          .select('id, chinese, english')
          .eq('is_active', true)
          .order('id', ascending: true);

      final words = (rows as List)
          .map((row) => WordItem.fromMap(row as Map<String, dynamic>))
          .toList();

      if (words.isEmpty) {
        setState(() {
          _words = [];
          _currentWord = null;
          _loading = false;
          _errorMessage = '目前沒有啟用中的單字。';
        });
        return;
      }

      setState(() {
        _words = words;
        _currentWord = words[_random.nextInt(words.length)];
        _loading = false;
      });

      _focusAnswerInput();
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = '讀取題庫失敗：$e';
      });
    }
  }

  void _pickRandomQuestion() {
    if (_words.isEmpty) return;

    WordItem nextWord = _words[_random.nextInt(_words.length)];

    if (_words.length > 1 && _currentWord != null) {
      while (nextWord.id == _currentWord!.id) {
        nextWord = _words[_random.nextInt(_words.length)];
      }
    }

    setState(() {
      _currentWord = nextWord;
      _answerController.clear();
      _resultText = null;
      _lastAnswerCorrect = null;
      _hasCheckedCurrentQuestion = false;
    });

    _focusAnswerInput();
  }

  void _checkAnswer() {
    final word = _currentWord;
    if (word == null) return;

    final userAnswer = _answerController.text;

    if (userAnswer.trim().isEmpty) {
      setState(() {
        _resultText = '請先輸入英文答案。';
        _lastAnswerCorrect = null;
      });
      return;
    }

    final isCorrect = _normalizeAnswer(userAnswer) == _normalizeAnswer(word.english);

    setState(() {
      _lastAnswerCorrect = isCorrect;
      _hasCheckedCurrentQuestion = true;

      if (isCorrect) {
        _correctCount++;
        _resultText = '答對了！';
      } else {
        _wrongCount++;
        _resultText = '答錯了，正確答案是：${word.english}';
      }
    });
  }

  void _clearRecord() {
    final shouldGoNext = _hasCheckedCurrentQuestion;

    setState(() {
      _correctCount = 0;
      _wrongCount = 0;
      _resultText = null;
      _lastAnswerCorrect = null;
      _hasCheckedCurrentQuestion = false;
      _answerController.clear();
    });

    if (shouldGoNext) {
      _pickRandomQuestion();
    } else {
      _focusAnswerInput();
    }
  }

  void _focusAnswerInput() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        _answerFocusNode.requestFocus();
      }
    });
  }

  String _normalizeAnswer(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[，,；;：:\-–—_/\\()\[\]{}.]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  Widget build(BuildContext context) {
    final total = _correctCount + _wrongCount;
    final accuracy = total == 0 ? 0 : ((_correctCount / total) * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('中文題目 → 英文單字練習'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildBody(total, accuracy),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(int total, int accuracy) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _ErrorView(
        message: _errorMessage!,
        onRetry: _loadWords,
      );
    }

    final word = _currentWord;

    if (word == null) {
      return _ErrorView(
        message: '沒有可練習的單字。',
        onRetry: _loadWords,
      );
    }

    return Column(
      children: [
        _ScoreCard(
          correctCount: _correctCount,
          wrongCount: _wrongCount,
          total: total,
          accuracy: accuracy,
          onClear: _clearRecord,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Center(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '題目',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      word.chinese,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _answerController,
                      focusNode: _answerFocusNode,
                      enabled: !_hasCheckedCurrentQuestion,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_hasCheckedCurrentQuestion) {
                          _checkAnswer();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: '請輸入英文單字',
                        hintText: '例如：apple cider vinegar',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_resultText != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _lastAnswerCorrect == true
                              ? Colors.green.shade50
                              : _lastAnswerCorrect == false
                                  ? Colors.red.shade50
                                  : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _lastAnswerCorrect == true
                                ? Colors.green.shade300
                                : _lastAnswerCorrect == false
                                    ? Colors.red.shade300
                                    : Colors.orange.shade300,
                          ),
                        ),
                        child: Text(
                          _resultText!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _lastAnswerCorrect == true
                                ? Colors.green.shade800
                                : _lastAnswerCorrect == false
                                    ? Colors.red.shade800
                                    : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (!_hasCheckedCurrentQuestion)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _checkAnswer,
                          child: const Text('確認答案'),
                        ),
                      ),
                    if (_hasCheckedCurrentQuestion)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _pickRandomQuestion,
                          child: const Text('下一題'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Text(
          '目前題庫：${_words.length} 題',
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final int correctCount;
  final int wrongCount;
  final int total;
  final int accuracy;
  final VoidCallback onClear;

  const _ScoreCard({
    required this.correctCount,
    required this.wrongCount,
    required this.total,
    required this.accuracy,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ScoreChip(
                    label: '答對',
                    value: correctCount.toString(),
                    color: Colors.green,
                  ),
                  _ScoreChip(
                    label: '答錯',
                    value: wrongCount.toString(),
                    color: Colors.red,
                  ),
                  _ScoreChip(
                    label: '總答題',
                    value: total.toString(),
                    color: Colors.blue,
                  ),
                  _ScoreChip(
                    label: '正確率',
                    value: '$accuracy%',
                    color: Colors.purple,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh),
              label: const Text('清空紀錄'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ScoreChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('重新讀取'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
