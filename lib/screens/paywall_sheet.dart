import 'package:flutter/material.dart';

import '../data/entitlement_store.dart';
import '../data/purchase_service.dart';
import '../models/entitlement.dart';
import '../models/store_product.dart';
import '../models/zoo.dart';
import '../l10n/app_localizations.dart';

Future<void> showUnlockSheet(BuildContext context, Zoo zoo) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _UnlockSheet(zoo: zoo),
  );
}

class _UnlockSheet extends StatefulWidget {
  final Zoo zoo;
  const _UnlockSheet({required this.zoo});

  @override
  State<_UnlockSheet> createState() => _UnlockSheetState();
}

class _UnlockSheetState extends State<_UnlockSheet> {
  final _svc = PurchaseService.instance;
  List<StoreProduct> _products = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final p = await _svc.products(EntitlementStore.homeCountry.value);
    if (!mounted) return;
    setState(() => _products = p);
  }

  String _priceFor(ProductKind kind) {
    for (final p in _products) {
      if (p.kind == kind) return p.priceLabel;
    }
    return '';
  }

  void _finish(String message) {
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _useFree() async {
    setState(() => _busy = true);
    final ok = await EntitlementStore.unlockFreeZoo(widget.zoo.id);
    if (!mounted) return;
    setState(() => _busy = false);
    final l10n = AppLocalizations.of(context);
    _finish(ok
        ? l10n.paywallZooUnlocked(widget.zoo.name)
        : l10n.paywallNoFreeUnlocksLeft);
  }

  Future<void> _buy(ProductKind kind) async {
    setState(() => _busy = true);
    final res = await _svc.buy(kind,
        homeCountry: EntitlementStore.homeCountry.value);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      _finish(AppLocalizations.of(context).paywallPurchaseComplete);
    } else if (res.cancelled) {
      // stay open
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                res.error ?? AppLocalizations.of(context).paywallPurchaseFailed)),
      );
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    await _svc.restore();
    if (!mounted) return;
    setState(() => _busy = false);
    _finish(AppLocalizations.of(context).paywallRestoreRequested);
  }

  @override
  Widget build(BuildContext context) {
    final zoo = widget.zoo;
    final ent = EntitlementStore.current.value;
    final homeSet = EntitlementStore.homeCountrySet;
    final home = EntitlementStore.homeCountry.value;
    final premiumCoversThis = homeSet && zoo.country == home;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppLocalizations.of(context).paywallUnlockZoo(zoo.name),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)
                  .paywallFirstZoosFree(Entitlement.maxFree),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!_svc.isProductionValidated) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppLocalizations.of(context).paywallDevelopmentMode,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (ent.freeRemaining > 0)
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _useFree,
                icon: const Icon(Icons.lock_open),
                label: Text(AppLocalizations.of(context)
                    .paywallUseFreeUnlock(ent.freeRemaining)),
              ),
            const SizedBox(height: 8),
            _PlanTile(
              title: premiumCoversThis
                  ? AppLocalizations.of(context).paywallPremiumAllZoos(home ?? '')
                  : AppLocalizations.of(context).paywallPremiumHomeCountry,
              price: _priceFor(ProductKind.premiumCountry),
              subtitle: !homeSet
                  ? AppLocalizations.of(context).paywallSetHomeCountryToEnable
                  : (premiumCoversThis
                      ? AppLocalizations.of(context).paywallUnlocksEveryZooIn(home ?? '')
                      : AppLocalizations.of(context)
                          .paywallCoversZoosChooseUnlimited(home ?? '', zoo.country)),
              enabled: !_busy && premiumCoversThis,
              onTap: () => _buy(ProductKind.premiumCountry),
            ),
            const SizedBox(height: 8),
            _PlanTile(
              title: AppLocalizations.of(context).paywallUnlimitedWorldwide,
              price: _priceFor(ProductKind.unlimited),
              subtitle: AppLocalizations.of(context).paywallUnlimitedSubtitle,
              enabled: !_busy && !ent.isUnlimited,
              onTap: () => _buy(ProductKind.unlimited),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _restore,
              child: Text(AppLocalizations.of(context).paywallRestorePurchases),
            ),
            if (_busy) const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String title;
  final String price;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _PlanTile({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        enabled: enabled,
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(price, style: Theme.of(context).textTheme.labelLarge),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
