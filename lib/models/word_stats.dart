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
