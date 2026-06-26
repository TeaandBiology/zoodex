/// A user-submitted problem report (wrong image, factual error, missing
/// species, etc). Stored locally first so nothing is lost offline; delivery to
/// the developer is a separate step (share sheet today, an API call later).
enum ReportCategory {
  speciesImage('Species image issue'),
  factual('Factual error'),
  taxonomy('Wrong taxonomy or IUCN status'),
  missingSpecies('Missing species'),
  other('Something else');

  const ReportCategory(this.label);
  final String label;

  static ReportCategory fromName(String? name) => values.firstWhere(
        (c) => c.name == name,
        orElse: () => ReportCategory.other,
      );
}

class Report {
  final String id;
  final DateTime createdAt;
  final ReportCategory category;
  final String? speciesId;
  final String? speciesName;
  final String? zooId;
  final String? zooName;
  final String note;

  const Report({
    required this.id,
    required this.createdAt,
    required this.category,
    this.speciesId,
    this.speciesName,
    this.zooId,
    this.zooName,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'category': category.name,
        'speciesId': speciesId,
        'speciesName': speciesName,
        'zooId': zooId,
        'zooName': zooName,
        'note': note,
      };

  factory Report.fromMap(Map map) => Report(
        id: (map['id'] ?? '').toString(),
        createdAt:
            DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
        category: ReportCategory.fromName(map['category']?.toString()),
        speciesId: map['speciesId'] as String?,
        speciesName: map['speciesName'] as String?,
        zooId: map['zooId'] as String?,
        zooName: map['zooName'] as String?,
        note: (map['note'] ?? '').toString(),
      );

  /// One-line-ish readable form used when exporting / sharing.
  String toReadable() {
    final b = StringBuffer()
      ..writeln('• ${category.label}')
      ..writeln('  when: ${createdAt.toIso8601String()}');
    if (speciesName != null) b.writeln('  species: $speciesName ($speciesId)');
    if (zooName != null) b.writeln('  zoo: $zooName ($zooId)');
    if (note.trim().isNotEmpty) b.writeln('  note: ${note.trim()}');
    return b.toString();
  }
}
