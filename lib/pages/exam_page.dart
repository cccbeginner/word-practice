import 'dart:math';

import 'package:flutter/material.dart';

import '../models/exam_models.dart';
import '../models/word_item.dart';
import '../services/exam_session_service.dart';
import '../services/word_repository.dart';
import '../utils/answer_normalizer.dart';
import '../utils/date_format.dart';
import '../widgets/error_view.dart';
import '../widgets/score_chip.dart';
import 'exam_record_page.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _answerFocusNode = FocusNode();
  final Random _random = Random();
  final WordRepository _wordRepository = WordRepository();
  final ExamSessionService _examService = ExamSessionService();

  List<WordItem> _words = [];
  ExamSession? _session;

  bool _loading = true;
  bool _takingExam = false;
  bool _waitingForNext = false;
  String? _errorMessage;
  String? _resultText;
  ExamAnswerRecord? _lastSubmittedRecord;

  Map<int, WordItem> get _wordsById {
    return {for (final word in _words) word.id: word};
  }

  WordItem? get _currentWord {
    final currentWordId = _session?.currentWordId;
    if (currentWordId == null) return null;
    return _wordsById[currentWordId];
  }

  @override
  void initState() {
    super.initState();
    _loadExamData();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _answerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadExamData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _wordRepository.loadActiveWords(),
        _examService.loadSession(),
      ]);

      final words = results[0] as List<WordItem>;
      final session = results[1] as ExamSession?;

      setState(() {
        _words = words;
        _session = _sanitizeSession(session, words);
        _loading = false;
        _takingExam = false;
        _waitingForNext = false;
        _resultText = null;
        _lastSubmittedRecord = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = '讀取考試資料失敗：$e';
      });
    }
  }

  ExamSession? _sanitizeSession(ExamSession? session, List<WordItem> words) {
    if (session == null) return null;
    if (session.wordIds.isEmpty) return null;

    final activeIds = words.map((word) => word.id).toSet();
    final hasUnknownWord = session.wordIds.any((wordId) => !activeIds.contains(wordId));

    if (hasUnknownWord && !session.completed) {
      return session.copyWith(completed: true, finishedAt: DateTime.now());
    }

    return session;
  }

  Future<void> _startNewSession({bool askBeforeDiscard = false}) async {
    if (_words.isEmpty) return;

    if (askBeforeDiscard) {
      final confirmed = await _confirmRestart();
      if (!confirmed) return;
    }

    final wordIds = _words.map((word) => word.id).toList()..shuffle(_random);
    final newSession = ExamSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      wordIds: wordIds,
      currentIndex: 0,
      answers: const [],
      completed: false,
      startedAt: DateTime.now(),
    );

    await _examService.saveSession(newSession);

    if (!mounted) return;
    setState(() {
      _session = newSession;
      _takingExam = true;
      _waitingForNext = false;
      _resultText = null;
      _lastSubmittedRecord = null;
      _answerController.clear();
    });

    _focusAnswerInputIfDesktop();
  }

  Future<bool> _confirmRestart() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重新開始考試？'),
          content: const Text('這會丟掉目前未完成的考試紀錄，並重新隨機排列所有單字。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('重新開始'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _continueExam() async {
    if (_session == null) return;

    setState(() {
      _takingExam = true;
      _waitingForNext = false;
      _resultText = null;
      _lastSubmittedRecord = null;
      _answerController.clear();
    });

    _focusAnswerInputIfDesktop();
  }

  void _pauseExam() {
    setState(() {
      _takingExam = false;
      _waitingForNext = false;
      _resultText = null;
      _lastSubmittedRecord = null;
      _answerController.clear();
    });
  }

  Future<void> _checkAnswer() async {
    final session = _session;
    final word = _currentWord;

    if (session == null || word == null || _waitingForNext || session.completed) {
      return;
    }

    final userAnswer = _answerController.text;

    if (userAnswer.trim().isEmpty) {
      setState(() {
        _resultText = '請先輸入英文答案。';
        _lastSubmittedRecord = null;
      });
      _focusAnswerInputIfDesktop();
      return;
    }

    final isCorrect = normalizeAnswer(userAnswer) == normalizeAnswer(word.english);
    final record = ExamAnswerRecord(
      wordId: word.id,
      questionNumber: session.answeredCount + 1,
      chinese: word.chinese,
      correctEnglish: word.english,
      userAnswer: userAnswer.trim(),
      isCorrect: isCorrect,
      answeredAt: DateTime.now(),
    );
    final updatedSession = session.recordAnswer(record);

    await _examService.saveSession(updatedSession);

    if (!mounted) return;
    setState(() {
      _session = updatedSession;
      _waitingForNext = true;
      _lastSubmittedRecord = record;
      _resultText = isCorrect ? '答對了！' : '答錯了，正確答案是：${word.english}';
    });
  }

  void _goNextQuestionOrResult() {
    final session = _session;
    if (session == null) return;

    if (session.completed) {
      setState(() {
        _takingExam = false;
        _waitingForNext = false;
        _answerController.clear();
        _resultText = null;
        _lastSubmittedRecord = null;
      });
      return;
    }

    setState(() {
      _waitingForNext = false;
      _answerController.clear();
      _resultText = null;
      _lastSubmittedRecord = null;
    });

    _focusAnswerInputIfDesktop();
  }

  Future<void> _openExamRecordPage() async {
    final session = _session;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目前沒有考試紀錄。')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamRecordPage(session: session),
      ),
    );
  }

  void _focusAnswerInputIfDesktop() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted || _waitingForNext) return;

      final width = MediaQuery.maybeOf(context)?.size.width ?? 999;

      if (width >= 700) {
        _answerFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('考試模式'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '考試紀錄',
            onPressed: _session == null ? null : _openExamRecordPage,
            icon: const Icon(Icons.receipt_long_rounded),
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
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _buildBody(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 120),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return ErrorView(
        message: _errorMessage!,
        onRetry: _loadExamData,
      );
    }

    if (_words.isEmpty) {
      return ErrorView(
        message: '目前沒有啟用中的單字，無法開始考試。',
        onRetry: _loadExamData,
      );
    }

    if (_takingExam && _session != null) {
      return _buildTakingExam();
    }

    return _buildExamHome();
  }

  Widget _buildExamHome() {
    final session = _session;
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (session == null) {
      return _ExamHomeCard(
        title: '尚未開始考試',
        description: '考試模式會把目前所有啟用中的單字隨機排列，每個單字只出現一次；${_words.length} 個單字就是 ${_words.length} 題。',
        primaryLabel: '開始考試',
        primaryIcon: Icons.play_arrow_rounded,
        onPrimary: () => _startNewSession(),
      );
    }

    if (session.completed) {
      return Column(
        children: [
          _ExamStatusCard(session: session),
          SizedBox(height: isMobile ? 12 : 16),
          _ExamHomeCard(
            title: '考試已完成',
            description: '你可以查看本次考試紀錄，或重新開始一場新的考試。重新開始會重新隨機排列所有單字。',
            primaryLabel: '查看考試紀錄',
            primaryIcon: Icons.receipt_long_rounded,
            onPrimary: _openExamRecordPage,
            secondaryLabel: '重新開始考試',
            secondaryIcon: Icons.refresh_rounded,
            onSecondary: () => _startNewSession(),
          ),
        ],
      );
    }

    return Column(
      children: [
        _ExamStatusCard(session: session),
        SizedBox(height: isMobile ? 12 : 16),
        _ExamHomeCard(
          title: '有一場未完成考試',
          description: '目前進度：${session.answeredCount}/${session.totalQuestions}。你可以繼續考試，或重新開始並丟掉未完成紀錄。',
          primaryLabel: '繼續考試',
          primaryIcon: Icons.play_arrow_rounded,
          onPrimary: _continueExam,
          secondaryLabel: '重新開始',
          secondaryIcon: Icons.restart_alt_rounded,
          onSecondary: () => _startNewSession(askBeforeDiscard: true),
          tertiaryLabel: '查看目前紀錄',
          tertiaryIcon: Icons.receipt_long_rounded,
          onTertiary: _openExamRecordPage,
        ),
      ],
    );
  }

  Widget _buildTakingExam() {
    final session = _session!;
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (session.completed && _waitingForNext) {
      return _buildAnswerResultView(
        session: session,
        title: '最後一題結果',
        buttonText: '查看考試結果',
      );
    }

    if (_waitingForNext) {
      return _buildAnswerResultView(
        session: session,
        title: '第 ${_lastSubmittedRecord?.questionNumber ?? session.answeredCount} 題結果',
        buttonText: '下一題',
      );
    }

    final word = _currentWord;

    if (word == null) {
      return ErrorView(
        message: '目前考試紀錄中的單字已不在啟用題庫內，請重新開始考試。',
        onRetry: () => _startNewSession(askBeforeDiscard: true),
      );
    }

    final questionNumber = session.answeredCount + 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ExamStatusCard(session: session),
        SizedBox(height: isMobile ? 12 : 20),
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
                children: [
                  Text(
                    '第 $questionNumber / ${session.totalQuestions} 題',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  Text(
                    word.chinese,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 32 : 40,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: isMobile ? 22 : 32),
                  TextField(
                    controller: _answerController,
                    focusNode: _answerFocusNode,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _checkAnswer(),
                    decoration: InputDecoration(
                      labelText: '請輸入英文單字',
                      hintText: '考試中每個單字只會出現一次',
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
                    _ExamResultBox(
                      text: _resultText!,
                      isCorrect: null,
                    ),
                  SizedBox(height: isMobile ? 16 : 24),
                  SizedBox(
                    width: double.infinity,
                    height: isMobile ? 44 : 48,
                    child: FilledButton(
                      onPressed: _checkAnswer,
                      child: const Text('確認答案'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: isMobile ? 42 : 46,
                    child: OutlinedButton.icon(
                      onPressed: _pauseExam,
                      icon: const Icon(Icons.pause_rounded),
                      label: const Text('暫停並返回'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerResultView({
    required ExamSession session,
    required String title,
    required String buttonText,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final record = _lastSubmittedRecord;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ExamStatusCard(session: session),
        SizedBox(height: isMobile ? 12 : 20),
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
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  if (record != null)
                    Text(
                      record.chinese,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 30 : 38,
                        fontWeight: FontWeight.bold,
                        height: 1.15,
                      ),
                    ),
                  SizedBox(height: isMobile ? 14 : 20),
                  if (_resultText != null)
                    _ExamResultBox(
                      text: _resultText!,
                      isCorrect: record?.isCorrect,
                    ),
                  SizedBox(height: isMobile ? 16 : 24),
                  SizedBox(
                    width: double.infinity,
                    height: isMobile ? 44 : 48,
                    child: FilledButton(
                      onPressed: _goNextQuestionOrResult,
                      child: Text(buttonText),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: isMobile ? 42 : 46,
                    child: OutlinedButton.icon(
                      onPressed: _openExamRecordPage,
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: const Text('查看考試紀錄'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExamStatusCard extends StatelessWidget {
  final ExamSession session;

  const _ExamStatusCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isVerySmall = MediaQuery.of(context).size.width < 380;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 18 : 22),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.completed ? '考試已完成' : '考試進度',
                    style: TextStyle(
                      fontSize: isMobile ? 17 : 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  formatDateTime(session.startedAt),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isVerySmall ? 11 : 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: session.totalQuestions == 0
                    ? 0
                    : session.answeredCount / session.totalQuestions,
                backgroundColor: Colors.blueGrey.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 12),
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
                ScoreChip(
                  label: '進度',
                  value: '${session.answeredCount}/${session.totalQuestions}',
                  color: Colors.blue,
                ),
                ScoreChip(
                  label: '答對',
                  value: session.correctCount.toString(),
                  color: Colors.green,
                ),
                ScoreChip(
                  label: '答錯',
                  value: session.wrongCount.toString(),
                  color: Colors.red,
                ),
                ScoreChip(
                  label: '正確率',
                  value: '${session.accuracy}%',
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamHomeCard extends StatelessWidget {
  final String title;
  final String description;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondary;
  final String? tertiaryLabel;
  final IconData? tertiaryIcon;
  final VoidCallback? onTertiary;

  const _ExamHomeCard({
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
    this.tertiaryLabel,
    this.tertiaryIcon,
    this.onTertiary,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: isMobile ? 14 : 15,
                height: 1.45,
              ),
            ),
            SizedBox(height: isMobile ? 18 : 22),
            SizedBox(
              width: double.infinity,
              height: isMobile ? 44 : 48,
              child: FilledButton.icon(
                onPressed: onPrimary,
                icon: Icon(primaryIcon),
                label: Text(primaryLabel),
              ),
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: isMobile ? 42 : 46,
                child: OutlinedButton.icon(
                  onPressed: onSecondary,
                  icon: Icon(secondaryIcon ?? Icons.refresh_rounded),
                  label: Text(secondaryLabel!),
                ),
              ),
            ],
            if (tertiaryLabel != null && onTertiary != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: isMobile ? 42 : 46,
                child: TextButton.icon(
                  onPressed: onTertiary,
                  icon: Icon(tertiaryIcon ?? Icons.receipt_long_rounded),
                  label: Text(tertiaryLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExamResultBox extends StatelessWidget {
  final String text;
  final bool? isCorrect;

  const _ExamResultBox({
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
