import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://qjimgaeizxbswxgldgcl.supabase.co/';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqaW1nYWVpenhic3d4Z2xkZ2NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk3MTA0NTcsImV4cCI6MjA5NTI4NjQ1N30.FWISDms_YBtRlfzYYHmsIov-7Gwpuv182BUmpeuxYMw';

const String statsStorageKey = 'word_practice_stats_v1';

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
        visualDensity: VisualDensity.compact,
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

class WordStats {
  final int correct;
  final int wrong;

  const WordStats({
    this.correct = 0,
    this.wrong = 0,
  });

  int get total => correct + wrong;

  int get delta => wrong - correct;

  WordStats copyWith({
    int? correct,
    int? wrong,
  }) {
    return WordStats(
      correct: correct ?? this.correct,
      wrong: wrong ?? this.wrong,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'correct': correct,
      'wrong': wrong,
    };
  }

  factory WordStats.fromJson(Map<String, dynamic> json) {
    return WordStats(
      correct: (json['correct'] as num?)?.toInt() ?? 0,
      wrong: (json['wrong'] as num?)?.toInt() ?? 0,
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
  Map<int, WordStats> _statsByWordId = {};
  WordItem? _currentWord;

  bool _loading = true;
  String? _errorMessage;

  String? _resultText;
  bool? _lastAnswerCorrect;
  bool _hasCheckedCurrentQuestion = false;

  int get _correctCount {
    return _statsByWordId.values.fold<int>(
      0,
      (sum, stats) => sum + stats.correct,
    );
  }

  int get _wrongCount {
    return _statsByWordId.values.fold<int>(
      0,
      (sum, stats) => sum + stats.wrong,
    );
  }

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

  Future<Map<int, WordStats>> _loadSavedStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(statsStorageKey);

    if (raw == null || raw.trim().isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      return decoded.map((key, value) {
        return MapEntry(
          int.parse(key),
          WordStats.fromJson(value as Map<String, dynamic>),
        );
      });
    } catch (_) {
      await prefs.remove(statsStorageKey);
      return {};
    }
  }

  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();

    final data = _statsByWordId.map((wordId, stats) {
      return MapEntry(wordId.toString(), stats.toJson());
    });

    await prefs.setString(statsStorageKey, jsonEncode(data));
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

      final savedStats = await _loadSavedStats();
      final firstWord = _pickWeightedWordFrom(
        words: words,
        statsByWordId: savedStats,
        currentWord: null,
        avoidCurrentWord: false,
      );

      setState(() {
        _words = words;
        _statsByWordId = savedStats;
        _currentWord = firstWord;
        _loading = false;
        _resultText = null;
        _lastAnswerCorrect = null;
        _hasCheckedCurrentQuestion = false;
      });

      _focusAnswerInputIfDesktop();
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = '讀取題庫失敗：$e';
      });
    }
  }

  WordItem _pickWeightedWordFrom({
    required List<WordItem> words,
    required Map<int, WordStats> statsByWordId,
    required WordItem? currentWord,
    required bool avoidCurrentWord,
  }) {
    List<WordItem> candidates = words;

    if (avoidCurrentWord && currentWord != null && words.length > 1) {
      candidates = words.where((word) => word.id != currentWord.id).toList();
    }

    // 每個單字原始權重：e^(答錯次數 - 答對次數)
    // 這裡使用 softmax 等比例算法：e^(delta - maxDelta)
    // 抽選機率完全等價，但可以避免數字太大造成 overflow。
    final maxDelta = candidates
        .map((word) => (statsByWordId[word.id]?.delta ?? 0).toDouble())
        .reduce(max);

    final weightedItems = candidates.map((word) {
      final delta = (statsByWordId[word.id]?.delta ?? 0).toDouble();
      final weight = exp(delta - maxDelta);
      return MapEntry(word, weight);
    }).toList();

    final totalWeight = weightedItems.fold<double>(
      0,
      (sum, item) => sum + item.value,
    );

    if (totalWeight <= 0 || totalWeight.isNaN || totalWeight.isInfinite) {
      return candidates[_random.nextInt(candidates.length)];
    }

    double roll = _random.nextDouble() * totalWeight;

    for (final item in weightedItems) {
      roll -= item.value;
      if (roll <= 0) {
        return item.key;
      }
    }

    return weightedItems.last.key;
  }

  void _pickNextQuestion() {
    if (_words.isEmpty) return;

    final nextWord = _pickWeightedWordFrom(
      words: _words,
      statsByWordId: _statsByWordId,
      currentWord: _currentWord,
      avoidCurrentWord: true,
    );

    setState(() {
      _currentWord = nextWord;
      _answerController.clear();
      _resultText = null;
      _lastAnswerCorrect = null;
      _hasCheckedCurrentQuestion = false;
    });

    _focusAnswerInputIfDesktop();
  }

  Future<void> _checkAnswer() async {
    final word = _currentWord;
    if (word == null || _hasCheckedCurrentQuestion) return;

    final userAnswer = _answerController.text;

    if (userAnswer.trim().isEmpty) {
      setState(() {
        _resultText = '請先輸入英文答案。';
        _lastAnswerCorrect = null;
      });

      _focusAnswerInputIfDesktop();
      return;
    }

    final isCorrect =
        _normalizeAnswer(userAnswer) == _normalizeAnswer(word.english);

    final currentStats = _statsByWordId[word.id] ?? const WordStats();

    setState(() {
      _lastAnswerCorrect = isCorrect;
      _hasCheckedCurrentQuestion = true;

      if (isCorrect) {
        _statsByWordId[word.id] = currentStats.copyWith(
          correct: currentStats.correct + 1,
        );
        _resultText = '答對了！';
      } else {
        _statsByWordId[word.id] = currentStats.copyWith(
          wrong: currentStats.wrong + 1,
        );
        _resultText = '答錯了，正確答案是：${word.english}';
      }
    });

    await _saveStats();
  }

  Future<void> _clearAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(statsStorageKey);

    setState(() {
      _statsByWordId = {};
      _resultText = null;
      _lastAnswerCorrect = null;
      _hasCheckedCurrentQuestion = false;
      _answerController.clear();
    });

    _focusAnswerInputIfDesktop();
  }

  Future<void> _openRecordPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WordsRecordPage(
          words: _words,
          statsByWordId: _statsByWordId,
          onClearRecords: _clearAllRecords,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  void _focusAnswerInputIfDesktop() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted || _hasCheckedCurrentQuestion) return;

      final width = MediaQuery.maybeOf(context)?.size.width ?? 999;

      if (width >= 700) {
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
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          '英文單字練習',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '單字紀錄',
            onPressed: _words.isEmpty ? null : _openRecordPage,
            icon: const Icon(Icons.format_list_numbered_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                isMobile ? 12 : 20,
                isMobile ? 12 : 20,
                isMobile ? 12 : 20,
                24,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _buildBody(total, accuracy),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(int total, int accuracy) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 120),
        child: Center(
          child: CircularProgressIndicator(),
        ),
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isVerySmall = screenWidth < 380;
    final currentStats = _statsByWordId[word.id] ?? const WordStats();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ScoreCard(
          correctCount: _correctCount,
          wrongCount: _wrongCount,
          total: total,
          accuracy: accuracy,
          onClear: _clearAllRecords,
          onOpenRecords: _openRecordPage,
        ),
        SizedBox(height: isMobile ? 12 : 24),
        SizedBox(
          width: double.infinity,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
            ),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '題目',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: isMobile ? 14 : 16,
                    ),
                  ),
                  SizedBox(height: isMobile ? 6 : 10),
                  Text(
                    word.chinese,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isVerySmall
                          ? 28
                          : isMobile
                              ? 32
                              : 40,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniStatPill(
                        label: '這題答對',
                        value: currentStats.correct.toString(),
                        color: Colors.green,
                      ),
                      _MiniStatPill(
                        label: '這題答錯',
                        value: currentStats.wrong.toString(),
                        color: Colors.red,
                      ),
                      _MiniStatPill(
                        label: '權重指數',
                        value: '錯-對=${currentStats.delta}',
                        color: Colors.blueGrey,
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 18 : 32),
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
                      isDense: isMobile,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 18),
                  if (_resultText != null)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isMobile ? 12 : 14),
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
                          fontSize: isMobile ? 15 : 16,
                          fontWeight: FontWeight.w600,
                          color: _lastAnswerCorrect == true
                              ? Colors.green.shade800
                              : _lastAnswerCorrect == false
                                  ? Colors.red.shade800
                                  : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  SizedBox(height: isMobile ? 16 : 24),
                  if (!_hasCheckedCurrentQuestion)
                    SizedBox(
                      width: double.infinity,
                      height: isMobile ? 44 : 48,
                      child: FilledButton(
                        onPressed: _checkAnswer,
                        child: const Text('確認答案'),
                      ),
                    ),
                  if (_hasCheckedCurrentQuestion)
                    SizedBox(
                      width: double.infinity,
                      height: isMobile ? 44 : 48,
                      child: FilledButton(
                        onPressed: _pickNextQuestion,
                        child: const Text('下一題'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: isMobile ? 10 : 16),
        Text(
          '目前題庫：${_words.length} 題',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: isMobile ? 13 : 14,
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
  final VoidCallback onOpenRecords;

  const _ScoreCard({
    required this.correctCount,
    required this.wrongCount,
    required this.total,
    required this.accuracy,
    required this.onClear,
    required this.onOpenRecords,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isVerySmall = constraints.maxWidth < 380;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? 18 : 22),
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 18),
            child: Column(
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isMobile ? 2 : 4,
                  mainAxisSpacing: isMobile ? 10 : 12,
                  crossAxisSpacing: isMobile ? 10 : 12,
                  childAspectRatio: isVerySmall
                      ? 1.9
                      : isMobile
                          ? 2.15
                          : 1.75,
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
                SizedBox(height: isMobile ? 10 : 14),
                if (isMobile)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: FilledButton.icon(
                          onPressed: onOpenRecords,
                          icon: const Icon(Icons.list_alt_rounded, size: 18),
                          label: const Text('查看單字紀錄'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: onClear,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('清空紀錄'),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: onOpenRecords,
                          icon: const Icon(Icons.list_alt_rounded, size: 18),
                          label: const Text('查看紀錄'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 180,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: onClear,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('清空紀錄'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
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
    final width = MediaQuery.of(context).size.width;
    final isVerySmall = width < 380;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isVerySmall ? 10 : 12,
        vertical: isVerySmall ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: isVerySmall ? 12 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: isVerySmall ? 21 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 380;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 9 : 10,
        vertical: isSmall ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        '$label：$value',
        style: TextStyle(
          color: color,
          fontSize: isSmall ? 12 : 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class WordsRecordPage extends StatefulWidget {
  final List<WordItem> words;
  final Map<int, WordStats> statsByWordId;
  final Future<void> Function() onClearRecords;

  const WordsRecordPage({
    super.key,
    required this.words,
    required this.statsByWordId,
    required this.onClearRecords,
  });

  @override
  State<WordsRecordPage> createState() => _WordsRecordPageState();
}
class _WordsRecordPageState extends State<WordsRecordPage> {
  late Map<int, WordStats> _statsByWordId;

  @override
  void initState() {
    super.initState();
    _statsByWordId = Map<int, WordStats>.from(widget.statsByWordId);
  }

  Future<void> _clearRecords() async {
    await widget.onClearRecords();

    if (!mounted) return;

    setState(() {
      _statsByWordId = {};
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('所有單字紀錄已清空。'),
      ),
    );
  }

  Color _statusColor(WordStats stats) {
    if (stats.correct == 0 && stats.wrong == 0) {
      return Colors.grey;
    }

    if (stats.wrong > stats.correct) {
      return Colors.red;
    }

    if (stats.correct == stats.wrong) {
      return Colors.amber;
    }

    return Colors.green;
  }

  int _statusSortRank(WordStats stats) {
    if (stats.wrong > stats.correct) {
      return 0; // 紅色：答錯較多，最上面
    }

    if (stats.correct == stats.wrong && stats.total > 0) {
      return 1; // 黃色：答對答錯一樣多
    }

    if (stats.total == 0) {
      return 2; // 灰色：完全沒有紀錄
    }

    return 3; // 綠色：答對較多，最下面
  }

  @override
  Widget build(BuildContext context) {
    final words = [...widget.words]..sort((a, b) {
        final statsA = _statsByWordId[a.id] ?? const WordStats();
        final statsB = _statsByWordId[b.id] ?? const WordStats();

        final rankA = _statusSortRank(statsA);
        final rankB = _statusSortRank(statsB);

        if (rankA != rankB) {
          return rankA.compareTo(rankB);
        }

        return a.id.compareTo(b.id);
      });

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('單字紀錄'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 20,
            12,
            isMobile ? 12 : 20,
            24,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  children: [
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isMobile ? 18 : 22),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 14 : 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '單字紀錄總覽',
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '排序：答錯較多在最上面，接著是一樣多、尚未作答，答對較多放最下面。',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: isMobile ? 13 : 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _clearRecords,
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('清空所有紀錄'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    ...words.map((word) {
                      final stats = _statsByWordId[word.id] ?? const WordStats();
                      final color = _statusColor(stats);

                      return Padding(
                        padding: EdgeInsets.only(bottom: isMobile ? 8 : 10),
                        child: _WordRecordCard(
                          word: word,
                          stats: stats,
                          color: color,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordRecordCard extends StatelessWidget {
  final WordItem word;
  final WordStats stats;
  final Color color;

  const _WordRecordCard({
    required this.word,
    required this.stats,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isVerySmall = MediaQuery.of(context).size.width < 380;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isVerySmall ? 10 : 12,
          vertical: isVerySmall ? 8 : 10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.chinese,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isVerySmall ? 16 : 17,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    word.english,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: isVerySmall ? 13 : 14,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _RecordPill(
                  label: '對',
                  value: stats.correct.toString(),
                  color: Colors.green,
                ),
                const SizedBox(height: 4),
                _RecordPill(
                  label: '錯',
                  value: stats.wrong.toString(),
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RecordPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isVerySmall = MediaQuery.of(context).size.width < 380;

    return Container(
      constraints: const BoxConstraints(minWidth: 48),
      padding: EdgeInsets.symmetric(
        horizontal: isVerySmall ? 7 : 8,
        vertical: isVerySmall ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        '$label $value',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: isVerySmall ? 11 : 12,
          fontWeight: FontWeight.w700,
        ),
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.only(top: isMobile ? 80 : 120),
      child: Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 20 : 24),
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
      ),
    );
  }
}
