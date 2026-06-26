import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile/desktop: write the CSV to a temp file and open the system share sheet
/// (Save to Files, email, messaging, etc.). Uses the share_plus 10+ API.
Future<void> exportCsvFile(String csv, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(csv);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: 'ZooDex data export',
    ),
  );
}
