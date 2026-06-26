import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:hive_flutter/hive_flutter.dart';

import '../models/report.dart';
import 'hive_store.dart';

/// Local store for user problem reports. Today reports live on-device and are
/// handed to the OS share sheet to reach the developer; when a backend exists,
/// [submit] becomes the single place to also POST them.
class ReportStore {
  ReportStore._();

  static Box get _box => HiveStore.reportsBox;

  static ValueListenable<Box> listenable() => _box.listenable();
  static int get count => _box.length;

  static Future<Report> add({
    required ReportCategory category,
    String? speciesId,
    String? speciesName,
    String? zooId,
    String? zooName,
    String note = '',
  }) async {
    final now = DateTime.now();
    final r = Report(
      id: 'rpt_${now.microsecondsSinceEpoch}',
      createdAt: now,
      category: category,
      speciesId: speciesId,
      speciesName: speciesName,
      zooId: zooId,
      zooName: zooName,
      note: note,
    );
    await _box.put(r.id, r.toMap());
    return r;
  }

  /// All reports, newest first.
  static List<Report> all() {
    final list =
        _box.values.whereType<Map>().map(Report.fromMap).toList(growable: false);
    return list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> clear() => _box.clear();

  /// A plain-text dump of every report, for sharing/exporting.
  static String exportText() {
    final reports = all();
    if (reports.isEmpty) return 'No reports.';
    final b = StringBuffer('ZooDex problem reports (${reports.length})\n\n');
    for (final r in reports) {
      b
        ..writeln(r.toReadable())
        ..writeln();
    }
    return b.toString();
  }
}
