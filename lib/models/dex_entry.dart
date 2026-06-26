/// A computed, lifetime-collection view for one species — folded from all
/// visits + species-logs. Never stored (it would drift); always derived.
class DexEntry {
  final String speciesId;
  final bool seenEver;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;
  final int visitsSeenCount;
  final bool everVerified;
  final Set<String> zoosSeenAt;

  /// The zoo of the most recent "seen" — handy for opening a species detail.
  final String? lastZooId;

  const DexEntry({
    required this.speciesId,
    required this.seenEver,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.visitsSeenCount,
    required this.everVerified,
    required this.zoosSeenAt,
    required this.lastZooId,
  });
}
