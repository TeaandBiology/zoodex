import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/entitlement.dart';
import '../models/zoo.dart';

/// Reactive, persisted cache of the user's entitlement and home country.
///
/// Free-zoo picks are legitimately local (no payment). The *paid* tier flags
/// here must, in production, be written only by [PurchaseService] from a
/// validated purchase — never set directly from UI as a trusted flag.
class EntitlementStore {
  EntitlementStore._();

  static const String boxName = 'entitlement';
  static const String _entKey = 'entitlement';
  static const String _homeCountryKey = 'home_country';

  static final ValueNotifier<Entitlement> current =
      ValueNotifier<Entitlement>(Entitlement.initial());
  static final ValueNotifier<String?> homeCountry =
      ValueNotifier<String?>(null);

  static Box get _box => Hive.box(boxName);

  static void init() {
    final raw = _box.get(_entKey);
    if (raw is Map) current.value = Entitlement.fromMap(raw);
    homeCountry.value = _box.get(_homeCountryKey) as String?;
  }

  static Future<void> _save(Entitlement e) async {
    current.value = e;
    await _box.put(_entKey, e.toMap());
  }

  static bool canAccess(Zoo zoo) => current.value.grantsAccessTo(zoo);

  // --- Home country (set once) ------------------------------------------------

  static bool get homeCountrySet =>
      homeCountry.value != null && homeCountry.value!.isNotEmpty;

  static Future<void> setHomeCountryOnce(String code) async {
    if (homeCountrySet) return;
    homeCountry.value = code;
    await _box.put(_homeCountryKey, code);
  }

  /// Dev only: clear the (otherwise set-once) home country, so onboarding can
  /// re-set it when re-testing the first-run flow.
  static Future<void> devClearHomeCountry() async {
    homeCountry.value = null;
    await _box.delete(_homeCountryKey);
  }

  // --- Free picks (pick-as-you-go, locked at 3) ------------------------------

  /// Returns false if the free allowance is already full.
  static Future<bool> unlockFreeZoo(String zooId) async {
    final e = current.value;
    if (e.grantsAccessTo(_dummyZoo(zooId))) return true; // already accessible
    if (e.freeFull) return false;
    await _save(e.copyWith(freeZooIds: [...e.freeZooIds, zooId]));
    return true;
  }

  // --- Paid tiers (written by PurchaseService after validation) --------------

  static Future<void> applyPremium(String country, {String source = 'dev'}) =>
      _save(current.value.copyWith(
        tier: EntitlementTier.premiumCountry,
        premiumCountry: country,
        source: source,
      ));

  static Future<void> applyUnlimited({String source = 'dev'}) =>
      _save(current.value.copyWith(
        tier: EntitlementTier.unlimited,
        clearPremiumCountry: true,
        source: source,
      ));

  /// Development helper to clear paid tiers and free picks back to nothing.
  static Future<void> resetToFree() => _save(Entitlement.initial());

  // freeZooIds is the only field grantsAccessTo needs for the "already free?"
  // check, so a minimal Zoo stand-in is enough here.
  static Zoo _dummyZoo(String id) => Zoo(id: id);
}
