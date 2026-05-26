String formatDateTime(DateTime? value) {
  if (value == null) return '-';

  final local = value.toLocal();
  return '${local.year}/${_twoDigits(local.month)}/${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
