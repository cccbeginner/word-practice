String normalizeAnswer(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[，,；;：:\-–—_/\\()\[\]{}.]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}
