class ExamAnswerRecord {
  final int wordId;
  final int questionNumber;
  final String chinese;
  final String correctEnglish;
  final String userAnswer;
  final bool isCorrect;
  final DateTime answeredAt;

  const ExamAnswerRecord({
    required this.wordId,
    required this.questionNumber,
    required this.chinese,
    required this.correctEnglish,
    required this.userAnswer,
    required this.isCorrect,
    required this.answeredAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'wordId': wordId,
      'questionNumber': questionNumber,
      'chinese': chinese,
      'correctEnglish': correctEnglish,
      'userAnswer': userAnswer,
      'isCorrect': isCorrect,
      'answeredAt': answeredAt.toIso8601String(),
    };
  }

  factory ExamAnswerRecord.fromJson(Map<String, dynamic> json) {
    return ExamAnswerRecord(
      wordId: (json['wordId'] as num).toInt(),
      questionNumber: (json['questionNumber'] as num?)?.toInt() ?? 0,
      chinese: json['chinese'] as String? ?? '',
      correctEnglish: json['correctEnglish'] as String? ?? '',
      userAnswer: json['userAnswer'] as String? ?? '',
      isCorrect: json['isCorrect'] as bool? ?? false,
      answeredAt: DateTime.tryParse(json['answeredAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ExamSession {
  final String id;
  final List<int> wordIds;
  final int currentIndex;
  final List<ExamAnswerRecord> answers;
  final bool completed;
  final DateTime startedAt;
  final DateTime? finishedAt;

  const ExamSession({
    required this.id,
    required this.wordIds,
    required this.currentIndex,
    required this.answers,
    required this.completed,
    required this.startedAt,
    this.finishedAt,
  });

  int get totalQuestions => wordIds.length;

  int get answeredCount => answers.length;

  int get correctCount => answers.where((record) => record.isCorrect).length;

  int get wrongCount => answers.where((record) => !record.isCorrect).length;

  int get accuracy {
    if (answeredCount == 0) return 0;
    return ((correctCount / answeredCount) * 100).round();
  }

  int get remainingCount => totalQuestions - answeredCount;

  int? get currentWordId {
    if (completed || currentIndex < 0 || currentIndex >= wordIds.length) {
      return null;
    }
    return wordIds[currentIndex];
  }

  ExamSession copyWith({
    String? id,
    List<int>? wordIds,
    int? currentIndex,
    List<ExamAnswerRecord>? answers,
    bool? completed,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
  }) {
    return ExamSession(
      id: id ?? this.id,
      wordIds: wordIds ?? this.wordIds,
      currentIndex: currentIndex ?? this.currentIndex,
      answers: answers ?? this.answers,
      completed: completed ?? this.completed,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: clearFinishedAt ? null : finishedAt ?? this.finishedAt,
    );
  }

  ExamSession recordAnswer(ExamAnswerRecord record) {
    final nextAnswers = [...answers, record];
    final nextIndex = currentIndex + 1;
    final isCompleted = nextIndex >= wordIds.length;

    return copyWith(
      answers: nextAnswers,
      currentIndex: isCompleted ? wordIds.length : nextIndex,
      completed: isCompleted,
      finishedAt: isCompleted ? DateTime.now() : finishedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wordIds': wordIds,
      'currentIndex': currentIndex,
      'answers': answers.map((record) => record.toJson()).toList(),
      'completed': completed,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
    };
  }

  factory ExamSession.fromJson(Map<String, dynamic> json) {
    return ExamSession(
      id: json['id'] as String? ?? '',
      wordIds: (json['wordIds'] as List? ?? [])
          .map((value) => (value as num).toInt())
          .toList(),
      currentIndex: (json['currentIndex'] as num?)?.toInt() ?? 0,
      answers: (json['answers'] as List? ?? [])
          .map(
            (value) => ExamAnswerRecord.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(),
      completed: json['completed'] as bool? ?? false,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      finishedAt: DateTime.tryParse(json['finishedAt'] as String? ?? ''),
    );
  }
}
