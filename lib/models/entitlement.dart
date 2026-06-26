import 'zoo.dart';

enum EntitlementTier { free, premiumCountry, unlimited }

String tierToString(EntitlementTier t) {
  switch (t) {
    case EntitlementTier.free:
      return 'free';
    case EntitlementTier.premiumCountry:
      return 'premiumCountry';
    case EntitlementTier.unlimited:
      return 'unlimited';
  }
}

EntitlementTier tierFromString(String? s) {
  switch (s) {
    case 'unlimited':
      return EntitlementTier.unlimited;
    case 'premiumCountry':
      return EntitlementTier.premiumCountry;
    default:
      return EntitlementTier.free;
  }
}

/// What a user may access. Access is a derived check over this plus `zoo.country`.
///
/// NOTE: for the paid tiers this is only a *cache*. In a real release it must be
/// set solely from a validated store purchase (see `PurchaseService` and
/// docs/GOING_LIVE_IAP.md) — never trusted as a bare on-device flag, which could
/// be edited on a rooted device. The free picks are legitimately local state
/// (they involve no payment).
class Entitlement {
  static const int maxFree = 3;

  final EntitlementTier tier;
  final String? premiumCountry; // set iff tier == premiumCountry
  final List<String> freeZooIds; // up to [maxFree], locked once full
  final DateTime updatedAt;
  final String source; // 'none' | 'dev' | 'appStore' | 'playStore'

  const Entitlement({
    this.tier = EntitlementTier.free,
    this.premiumCountry,
    this.freeZooIds = const [],
    required this.updatedAt,
    this.source = 'none',
  });

  factory Entitlement.initial() =>
      Entitlement(updatedAt: DateTime.fromMillisecondsSinceEpoch(0));

  bool get isUnlimited => tier == EntitlementTier.unlimited;
  bool get isPremium => tier == EntitlementTier.premiumCountry;
  bool get freeFull => freeZooIds.length >= maxFree;
  int get freeRemaining =>
      (maxFree - freeZooIds.length).clamp(0, maxFree).toInt();

  /// A zoo is accessible if it's covered by the tier OR was one of the (always
  /// honoured) free picks. Free picks are universal so an upgrade never revokes
  /// access to a zoo the user already unlocked.
  bool grantsAccessTo(Zoo zoo) {
    if (tier == EntitlementTier.unlimited) return true;
    if (freeZooIds.contains(zoo.id)) return true;
    if (tier == EntitlementTier.premiumCountry &&
        premiumCountry != null &&
        zoo.country == premiumCountry) {
      return true;
    }
    return false;
  }

  Entitlement copyWith({
    EntitlementTier? tier,
    String? premiumCountry,
    List<String>? freeZooIds,
    String? source,
    bool clearPremiumCountry = false,
  }) =>
      Entitlement(
        tier: tier ?? this.tier,
        premiumCountry:
            clearPremiumCountry ? null : (premiumCountry ?? this.premiumCountry),
        freeZooIds: freeZooIds ?? this.freeZooIds,
        source: source ?? this.source,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'tier': tierToString(tier),
        if (premiumCountry != null) 'premiumCountry': premiumCountry,
        'freeZooIds': freeZooIds,
        'updatedAt': updatedAt.toIso8601String(),
        'source': source,
      };

  static Entitlement fromMap(Map<dynamic, dynamic> m) {
    final raw = m['freeZooIds'];
    final ids = raw is List ? raw.whereType<String>().toList() : <String>[];
    final ts = m['updatedAt'];
    return Entitlement(
      tier: tierFromString(m['tier'] as String?),
      premiumCountry: m['premiumCountry'] as String?,
      freeZooIds: ids,
      updatedAt:
          ts is String ? (DateTime.tryParse(ts) ?? DateTime.now()) : DateTime.now(),
      source: (m['source'] as String?) ?? 'none',
    );
  }
}
