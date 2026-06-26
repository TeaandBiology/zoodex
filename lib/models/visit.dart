import '../util/date_format.dart';
import 'species_log.dart';
import 'verification.dart';

/// A visit is one zoo on one calendar day. Identity is `(zooId, localDate)`,
/// which is also its [id] and storage [key]. It owns the per-species outcomes
/// logged during it, and carries the verification result for the day.
///
/// No raw GPS is ever stored — only [verified].
class Visit {
  final String id;
  final String zooId;
  final DateTime date; // local, midnight-normalised
  VerificationStatus verified;
  DateTime firstLoggedAt;
  DateTime lastLoggedAt;

  /// speciesId -> outcome for this visit.
  final Map<String, SpeciesLog> logs;

  Visit({
    required this.id,
    required this.zooId,
    required this.date,
    this.verified = VerificationStatus.unverified,
    required this.firstLoggedAt,
    required this.lastLoggedAt,
    Map<String, SpeciesLog>? logs,
  }) : logs = logs ?? <String, SpeciesLog>{};

  static String keyFor(String zooId, DateTime date) =>
      '$zooId::${dateKey(date)}';

  String get key => keyFor(zooId, date);

  int get seenCount =>
      logs.values.where((l) => l.outcome == Outcome.seen).length;
  int get noShowCount =>
      logs.values.where((l) => l.outcome == Outcome.noShow).length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'zooId': zooId,
        'date': dateKey(date),
        'verified': verificationToString(verified),
        'firstLoggedAt': firstLoggedAt.toIso8601String(),
        'lastLoggedAt': lastLoggedAt.toIso8601String(),
        'logs': {for (final e in logs.entries) e.key: e.value.toMap()},
      };

  static Visit fromMap(Map<dynamic, dynamic> m) {
    DateTime parseDate(dynamic v) {
      if (v is String) {
        final p = DateTime.tryParse(v);
        if (p != null) return DateTime(p.year, p.month, p.day);
      }
      return dateOnly(DateTime.now());
    }

    DateTime parseTs(dynamic v) =>
        v is String ? (DateTime.tryParse(v) ?? DateTime.now()) : DateTime.now();

    final id = (m['id'] ?? '').toString();
    final logs = <String, SpeciesLog>{};
    final rawLogs = m['logs'];
    if (rawLogs is Map) {
      rawLogs.forEach((k, v) {
        if (v is Map) logs[k.toString()] = SpeciesLog.fromMap(id, k.toString(), v);
      });
    }

    return Visit(
      id: id,
      zooId: (m['zooId'] ?? '').toString(),
      date: parseDate(m['date']),
      verified: verificationFromString(m['verified'] as String?),
      firstLoggedAt: parseTs(m['firstLoggedAt']),
      lastLoggedAt: parseTs(m['lastLoggedAt']),
      logs: logs,
    );
  }
}
