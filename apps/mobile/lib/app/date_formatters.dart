String formatServerDate(Object? value) {
  final date = DateTime.tryParse(value as String? ?? '')?.toLocal();
  if (date == null) return '—';
  return _formatLocalDate(date);
}

String formatServerDateTime(Object? value) {
  final date = DateTime.tryParse(value as String? ?? '')?.toLocal();
  if (date == null) return '—';
  return '${_formatLocalDate(date)} pukul ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _formatLocalDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
