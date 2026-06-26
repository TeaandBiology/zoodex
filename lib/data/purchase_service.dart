import 'package:flutter/foundation.dart';

import '../models/store_product.dart';
import 'entitlement_store.dart';

/// Abstraction over the app store. Swap [instance] for a real, validated
/// implementation before shipping paid features — see GOING_LIVE_IAP.md.
abstract class PurchaseService {
  /// The live implementation. Defaults to a development stub.
  static PurchaseService instance = DevPurchaseService();

  /// Whether this implementation performs real, server-validated purchases.
  /// The UI surfaces a warning when this is false.
  bool get isProductionValidated;

  Future<List<StoreProduct>> products(String? homeCountry);

  /// Attempt a purchase. On success the implementation is responsible for
  /// writing the resulting entitlement (via EntitlementStore) from a *validated*
  /// source.
  Future<PurchaseOutcome> buy(ProductKind kind, {String? homeCountry});

  /// Re-apply entitlements already owned by this store account (new device, etc).
  Future<void> restore();
}

/// DEVELOPMENT ONLY — grants entitlements locally with no payment and no
/// validation. This is intentionally insecure; it exists so the gating and
/// purchase flow can be exercised before the store integration is wired.
/// Replace [PurchaseService.instance] with a validated implementation before
/// release.
class DevPurchaseService implements PurchaseService {
  @override
  bool get isProductionValidated => false;

  @override
  Future<List<StoreProduct>> products(String? homeCountry) async {
    final country = (homeCountry == null || homeCountry.isEmpty) ? '—' : homeCountry;
    return [
      StoreProduct(
        id: 'dev.premium.$country',
        kind: ProductKind.premiumCountry,
        title: 'Premium — all $country zoos',
        priceLabel: '£4.99 (dev)',
      ),
      const StoreProduct(
        id: 'dev.unlimited',
        kind: ProductKind.unlimited,
        title: 'Unlimited — every zoo, worldwide',
        priceLabel: '£9.99 (dev)',
      ),
    ];
  }

  @override
  Future<PurchaseOutcome> buy(ProductKind kind, {String? homeCountry}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250)); // pretend
    switch (kind) {
      case ProductKind.premiumCountry:
        if (homeCountry == null || homeCountry.isEmpty) {
          return const PurchaseOutcome.failed('Set a home country first');
        }
        await EntitlementStore.applyPremium(homeCountry, source: 'dev');
      case ProductKind.unlimited:
        await EntitlementStore.applyUnlimited(source: 'dev');
    }
    return const PurchaseOutcome.success();
  }

  @override
  Future<void> restore() async {
    debugPrint('[DevPurchaseService] restore() is a no-op in development.');
  }
}
