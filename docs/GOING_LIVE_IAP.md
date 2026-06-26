# Going live with in-app purchases

The app currently ships with `DevPurchaseService`, a development stub that
simulates a successful purchase and unlocks the selected tier locally. It takes
no payment, performs no validation, and shows a development-mode banner. It is
not secure and must not be used to charge anyone. Before charging real users,
replace it with a validated implementation. The whole integration sits behind a
single interface (`lib/data/purchase_service.dart`), so this is a contained job.

## Why a local flag is not enough

A value stored on the device can be edited on a rooted or jailbroken phone, so a
"user paid" boolean is not proof of payment. Entitlements must be
server-validated and never treated as a trusted local flag. The store (and a
validation layer) is the source of truth. The app refreshes its entitlement from
that source on launch, overwriting the local cache, including downgrading it if
validation says the user is not entitled. The validated result is then cached
locally so owned zoos open offline.

## Tiers

- Free: three zoos, chosen locally, no money involved.
- Premium: one home country.
- Unlimited: global access.

## Real purchases

Real purchases must go through Apple StoreKit on iOS and Google Play Billing on
Android. The app cannot grant a paid entitlement on its own authority. Two
requirements follow from Apple's rules and from refund handling:

- A working Restore Purchases flow is required by Apple. Provide it.
- Refunds must revoke entitlements. A refunded or lapsed purchase has to drop the
  user back to the free tier on the next refresh.

## Recommended path: RevenueCat (no backend required)

The recommended no-backend path is a validation service such as RevenueCat,
placed behind the same `PurchaseService` interface. RevenueCat sits on top of
Apple StoreKit and Google Play Billing, performs server-side receipt validation,
and provides cross-device entitlements and restore. That avoids building and
securing a purchase backend.

**1. Configure store products (one-time, in each console).**
   - Two non-consumable products. Decide the premium model:
     - Simplest: a single `unlimited` product, plus one `premium` product per
       country sold (e.g. `premium_gb`, `premium_fr`). The app already stores
       `homeCountry`, so premium grants access scoped to it.
   - Apple: App Store Connect, In-App Purchases (non-consumable). Provide
     screenshots and review notes. Restore Purchases is required (handled below).
   - Google: Play Console, Monetize, In-app products.

**2. RevenueCat dashboard.**
   - Add the apps and store credentials. Create entitlements (e.g. `premium`,
     `unlimited`) and attach the store products to offerings.

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
       // map offering packages -> StoreProduct list (id, kind, priceString)
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
     // able to downgrade, not just upgrade, so a tampered local cache cannot stick.
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
   `EntitlementStore.downgradeToFreeKeepingPicks()` (set tier back to free, clear
   `premiumCountry`, keep `freeZooIds`) needs to be added so a refresh can revoke
   a lapsed or refunded purchase without wiping free unlocks.

**6. Refunds and lapses.** A launch-time `refreshFromStore()` plus RevenueCat
   webhooks keep entitlements honest. A refunded purchase drops out of
   `entitlements.active`, and the next refresh downgrades the cache.

## Alternative: official `in_app_purchase` plugin

Apple and Google's own plugin avoids a third party, but it does not validate
receipts. Using it requires either a server to verify receipts and store
entitlements, or accepting weaker client-side trust. Given the goal of avoiding
a backend for launch, RevenueCat is the lower-effort, safer choice. Revisit this
option if a backend is later run for other reasons (Phase 2).

## Reminders

- Charitable donations are out (decision recorded). Keep it that way. If it ever
  returns, donations must not flow through IAP, and a 95/5 split is regulated
  fundraising (see the design doc history).
- Apple Family Sharing is off at launch. Leave the product's family-sharing
  toggle disabled in App Store Connect.
- Keep `DevPurchaseService` in the codebase (useful for testing), but make sure
  the release build sets `PurchaseService.instance` to the validated one.
