String twoDigits(int value) => value.toString().padLeft(2, '0');

String formatDateTime(DateTime value) {
  final now = DateTime.now();
  final sameDay = now.year == value.year &&
      now.month == value.month &&
      now.day == value.day;

  final time = '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  if (sameDay) return '今天 $time';
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} $time';
}

String formatBytes(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
