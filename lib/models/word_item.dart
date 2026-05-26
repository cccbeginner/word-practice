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
