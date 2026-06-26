/// Fallback when neither dart:io nor dart:html is available. The caller catches
/// this and copies the CSV to the clipboard instead.
Future<void> exportCsvFile(String csv, String filename) async {
  throw UnsupportedError('CSV export is not supported on this platform.');
}
