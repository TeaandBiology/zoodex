/// Maps ISO country codes (as stored on zoos / home country) to display names.
/// Falls back to the raw code when unknown, so new codes still show something.
const Map<String, String> _names = {
  'GB': 'United Kingdom',
  'UK': 'United Kingdom',
  'IE': 'Ireland',
  'US': 'United States',
  'FR': 'France',
  'DE': 'Germany',
  'ES': 'Spain',
  'IT': 'Italy',
  'NL': 'Netherlands',
  'BE': 'Belgium',
  'PT': 'Portugal',
  'AU': 'Australia',
  'NZ': 'New Zealand',
  'CA': 'Canada',
};

/// Short display label, preferring a friendly abbreviation (e.g. GB -> "UK").
const Map<String, String> _short = {
  'GB': 'UK',
  'UK': 'UK',
  'US': 'USA',
};

/// Full country name for a code (e.g. "GB" -> "United Kingdom").
String countryName(String? code) {
  final c = (code ?? '').trim();
  if (c.isEmpty) return '';
  return _names[c.toUpperCase()] ?? c;
}

/// Short country label for tight spaces (e.g. "GB" -> "UK").
String countryShort(String? code) {
  final c = (code ?? '').trim();
  if (c.isEmpty) return '';
  return _short[c.toUpperCase()] ?? countryName(c);
}
