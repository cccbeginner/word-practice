import 'dart:math';

import 'package:flutter/material.dart';

import '../models/word_item.dart';
import '../models/word_stats.dart';
import '../services/practice_stats_service.dart';
import '../services/word_repository.dart';
import '../utils/answer_normalizer.dart';
import '../widgets/error_view.dart';
import '../widgets/mini_stat_pill.dart';
import '../widgets/practice_score_card.dart';
import 'exam_page.dart';
import 'words_record_page.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _answerFocusNode = FocusNode();
  final Random _random = Random();
  final WordRepository _wordRepository = WordRepository();
  final PracticeStatsService _statsService = PracticeStatsService();

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

  Future<void> _loadWords() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final words = await _wordRepository.loadActiveWords();

      if (words.isEmpty) {
        setState(() {
          _words = [];
          _currentWord = null;
          _loading = false;
          _errorMessage = '目前沒有啟用中的單字。';
        });
        return;
      }

      final savedStats = await _statsService.loadStats();
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

    final isCorrect = normalizeAnswer(userAnswer) == normalizeAnswer(word.english);
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

    await _statsService.saveStats(_statsByWordId);
  }

  Future<void> _clearAllRecords() async {
    await _statsService.clearStats();

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

  Future<void> _openExamPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExamPage(),
      ),
    );
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
            tooltip: '考試模式',
            onPressed: _words.isEmpty ? null : _openExamPage,
            icon: const Icon(Icons.quiz_rounded),
          ),
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
      return ErrorView(
        message: _errorMessage!,
        onRetry: _loadWords,
      );
    }

    final word = _currentWord;

    if (word == null) {
      return ErrorView(
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
        PracticeScoreCard(
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
                      MiniStatPill(
                        label: '這題答對',
                        value: currentStats.correct.toString(),
                        color: Colors.green,
                      ),
                      MiniStatPill(
                        label: '這題答錯',
                        value: currentStats.wrong.toString(),
                        color: Colors.red,
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
                    _AnswerResultBox(
                      text: _resultText!,
                      isCorrect: _lastAnswerCorrect,
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

class _AnswerResultBox extends StatelessWidget {
  final String text;
  final bool? isCorrect;

  const _AnswerResultBox({
    required this.text,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: isCorrect == true
            ? Colors.green.shade50
            : isCorrect == false
                ? Colors.red.shade50
                : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCorrect == true
              ? Colors.green.shade300
              : isCorrect == false
                  ? Colors.red.shade300
                  : Colors.orange.shade300,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isMobile ? 15 : 16,
          fontWeight: FontWeight.w600,
          color: isCorrect == true
              ? Colors.green.shade800
              : isCorrect == false
                  ? Colors.red.shade800
                  : Colors.orange.shade800,
        ),
      ),
    );
  }
}
