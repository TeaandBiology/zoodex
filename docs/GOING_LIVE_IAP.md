# Going live with in-app purchases

Slice 3 ships with `DevPurchaseService`, which **fakes** purchases locally with no
payment and no validation. Before you charge anyone, replace it with a validated
implementation. The whole integration sits behind one interface
(`lib/data/purchase_service.dart`), so this is a contained job.

## Why not just trust the device flag?

A value stored on the device can be edited on a rooted/jailbroken phone, so a
"user paid" boolean is not proof of payment. The fix is to let the store (and a
validation layer) be the source of truth, and have the app *refresh* its
entitlement from that on launch — overwriting the local cache, including
downgrading it if validation says the user isn't entitled.

## Recommended path: RevenueCat (no backend of your own)

RevenueCat sits on top of Apple StoreKit and Google Play Billing, does the
server-side receipt validation for you, and gives cross-device entitlements and
restore — which is exactly what avoids you having to build and secure a backend
just for purchases.

**1. Configure store products (one-time, in each console).**
   - Two **non-consumable** products. Decide your premium model:
     - simplest: a single `unlimited` product, plus one `premium` product per
       country you sell (e.g. `premium_gb`, `premium_fr`). The app already stores
       `homeCountry`, so premium grants access scoped to it.
   - Apple: App Store Connect → In-App Purchases (non-consumable). Provide
     screenshots + review notes. "Restore purchases" is required (handled below).
   - Google: Play Console → Monetize → In-app products.

**2. RevenueCat dashboard.**
   - Add your apps + store credentials. Create **entitlements** (e.g.
     `premium`, `unlimited`) and attach the store products to **offerings**.

**3. Add the SDK.**
   ```yaml
   dependencies:
     purchases_flutter: ^8.0.0   # check for the current version
   ```

**4. Initialise at launch (in `main`, before `runApp`).**
   ```dart
   await Purchases.configure(PurchasesConfiguration('<public_sdk_key>'));
   PurchaseService.instance = RevenueCatPurchaseService();
   await PurchaseService.instance.refreshFromStore(); // authoritative sync
   ```

**5. Implement the interface.** Sketch (adapt to the current SDK API):
   ```dart
   class RevenueCatPurchaseService implements PurchaseService {
     @override
     bool get isProductionValidated => true;

     @override
     Future<List<StoreProduct>> products(String? homeCountry) async {
       final offerings = await Purchases.getOfferings();
       // map offering packages -> your StoreProduct list (id, kind, priceString)
     }

     @override
     Future<PurchaseOutcome> buy(ProductKind kind, {String? homeCountry}) async {
       try {
         final pkg = /* pick the package for kind (+ homeCountry for premium) */;
         final info = await Purchases.purchasePackage(pkg);
         await _applyFrom(info, homeCountry);
         return const PurchaseOutcome.success();
       } on PlatformException catch (e) {
         final code = PurchasesErrorHelper.getErrorCode(e);
         if (code == PurchasesErrorCode.purchaseCancelledError) {
           return const PurchaseOutcome.cancelled();
         }
         return PurchaseOutcome.failed(e.message);
       }
     }

     @override
     Future<void> restore() async {
       final info = await Purchases.restorePurchases();
       await _applyFrom(info, null);
     }

     // Call on launch and after any purchase/restore. AUTHORITATIVE: it must be
     // able to downgrade, not just upgrade, so a tampered local cache can't stick.
     Future<void> refreshFromStore() async {
       final info = await Purchases.getCustomerInfo();
       await _applyFrom(info, null);
     }

     Future<void> _applyFrom(CustomerInfo info, String? homeCountry) async {
       final active = info.entitlements.active;
       if (active.containsKey('unlimited')) {
         await EntitlementStore.applyUnlimited(source: _storeSource());
       } else if (active.containsKey('premium')) {
         final country = homeCountry ?? EntitlementStore.homeCountry.value;
         if (country != null) {
           await EntitlementStore.applyPremium(country, source: _storeSource());
         }
       } else {
         // No paid entitlement -> ensure paid tier is cleared (keep free picks).
         await EntitlementStore.downgradeToFreeKeepingPicks();
       }
     }
   }
   ```
   You'll need to add `EntitlementStore.downgradeToFreeKeepingPicks()` (set tier
   back to free, clear `premiumCountry`, keep `freeZooIds`) so a refresh can
   revoke a lapsed/refunded purchase without wiping free unlocks.

**6. Refunds & lapses.** A launch-time `refreshFromStore()` plus RevenueCat
   webhooks keep entitlements honest; a refunded purchase drops out of
   `entitlements.active` and the next refresh downgrades the cache.

## Alternative: official `in_app_purchase` plugin

Apple/Google's own plugin avoids a third party, but it does **not** validate
receipts for you — you'd need your own server to verify them and store
entitlements, or you accept weaker client-side trust. Given the goal of avoiding
a backend for launch, RevenueCat is the lower-effort, safer choice; revisit this
if you later run your own backend anyway (Phase 2).

## Don't forget

- **Charitable donations are out** (decision recorded) — keep it that way; if it
  ever returns, donations must not flow through IAP and a 95/5 split is regulated
  fundraising (see the design doc history).
- **Apple Family Sharing: off** at launch — leave the product's family-sharing
  toggle disabled in App Store Connect.
- Keep `DevPurchaseService` in the codebase (handy for testing), but make sure the
  release build sets `PurchaseService.instance` to the validated one.
