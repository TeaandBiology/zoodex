/// Maps ISO country codes (as stored on zoos and the user's home country) to
/// human-readable names. Falls back to the raw code if unknown, so adding new
/// zoos in new countries degrades gracefully.
const Map<String, String> _names = {
  'GB': 'United Kingdom',
  'US': 'United States',
  'IE': 'Ireland',
  'FR': 'France',
  'DE': 'Germany',
  'ES': 'Spain',
  'IT': 'Italy',
  'NL': 'Netherlands',
  'AU': 'Australia',
  'CA': 'Canada',
  'NZ': 'New Zealand',
};

/// Short forms for compact spots like the profile line.
const Map<String, String> _short = {
  'GB': 'UK',
  'US': 'USA',
};

/// Full country name for a code (e.g. "GB" -> "United Kingdom").
String countryName(String code) {
  final c = code.trim().toUpperCase();
  if (c.isEmpty) return '';
  return _names[c] ?? code.trim();
}

/// Short country name for tight spaces (e.g. "GB" -> "UK"); falls back to the
/// full name, then the raw code.
String countryNameShort(String code) {
  final c = code.trim().toUpperCase();
  if (c.isEmpty) return '';
  return _short[c] ?? _names[c] ?? code.trim();
}
