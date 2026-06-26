String _two(int n) => n.toString().padLeft(2, '0');

/// Strip a timestamp to a local midnight-normalised calendar date.
DateTime dateOnly(DateTime dt) {
  final l = dt.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Stable `yyyy-mm-dd` key for a local date (used in visit keys).
String dateKey(DateTime dt) {
  final l = dt.toLocal();
  return '${l.year}-${_two(l.month)}-${_two(l.day)}';
}

String formatLocalDate(DateTime dt) => dateKey(dt);

String formatLocalDateTime(DateTime dt) {
  final d = dt.toLocal();
  return '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// e.g. "June 2026" — used for the profile's "joined" date.
String monthYear(DateTime dt) {
  final d = dt.toLocal();
  return '${_months[d.month - 1]} ${d.year}';
}
