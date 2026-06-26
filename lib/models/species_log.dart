/// What happened with a species on a given visit. The third state —
/// "unassessed" — is represented by the *absence* of a log (most species).
enum Outcome { seen, noShow }

extension OutcomeX on Outcome {
  String get asString => this == Outcome.noShow ? 'noShow' : 'seen';
  static Outcome parse(String? s) => s == 'noShow' ? Outcome.noShow : Outcome.seen;
}

/// One species outcome within one visit. `speciesId` is the opaque species id
/// (`sp_…`); it is stored as the map key on the visit, so it isn't repeated in
/// the serialised value.
class SpeciesLog {
  final String visitId;
  final String speciesId;
  final Outcome outcome;
  final DateTime loggedAt;

  /// Private personal note — only ever shown to the owner, never shared.
  final String? note;

  const SpeciesLog({
    required this.visitId,
    required this.speciesId,
    required this.outcome,
    required this.loggedAt,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'outcome': outcome.asString,
        'loggedAt': loggedAt.toIso8601String(),
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  static SpeciesLog fromMap(
    String visitId,
    String speciesId,
    Map<dynamic, dynamic> m,
  ) {
    final raw = m['loggedAt'];
    final logged =
        raw is String ? (DateTime.tryParse(raw) ?? DateTime.now()) : DateTime.now();
    return SpeciesLog(
      visitId: visitId,
      speciesId: speciesId,
      outcome: OutcomeX.parse(m['outcome'] as String?),
      loggedAt: logged,
      note: m['note'] as String?,
    );
  }

  SpeciesLog copyWith({
    Outcome? outcome,
    DateTime? loggedAt,
    String? note,
    bool clearNote = false,
  }) =>
      SpeciesLog(
        visitId: visitId,
        speciesId: speciesId,
        outcome: outcome ?? this.outcome,
        loggedAt: loggedAt ?? this.loggedAt,
        note: clearNote ? null : (note ?? this.note),
      );
}
