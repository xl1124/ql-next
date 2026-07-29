String formatTaskLastRun(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return '';

  final numeric = num.tryParse(value);
  if (numeric != null) {
    if (numeric <= 0) return '';
    final milliseconds = numeric.abs() < 100000000000
        ? (numeric * 1000).round()
        : numeric.round();
    return _formatLocal(DateTime.fromMillisecondsSinceEpoch(milliseconds));
  }

  final parsed = DateTime.tryParse(value);
  if (parsed != null) return _formatLocal(parsed);
  return value;
}

String _formatLocal(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}:'
      '${local.second.toString().padLeft(2, '0')}';
}
