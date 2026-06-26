import 'package:flutter/material.dart';

import '../data/entitlement_store.dart';
import '../data/purchase_service.dart';
import '../models/entitlement.dart';
import '../models/store_product.dart';
import '../models/zoo.dart';

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
    _finish(ok ? '${widget.zoo.name} unlocked' : 'No free unlocks left');
  }

  Future<void> _buy(ProductKind kind) async {
    setState(() => _busy = true);
    final res = await _svc.buy(kind,
        homeCountry: EntitlementStore.homeCountry.value);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      _finish('Purchase complete');
    } else if (res.cancelled) {
      // stay open
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'Purchase failed')),
      );
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    await _svc.restore();
    if (!mounted) return;
    setState(() => _busy = false);
    _finish('Restore requested');
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
            Text('Unlock ${zoo.name}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'The first ${Entitlement.maxFree} zoos are free.',
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
                  'Development mode: purchases are simulated and not validated.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (ent.freeRemaining > 0)
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _useFree,
                icon: const Icon(Icons.lock_open),
                label: Text('Use a free unlock (${ent.freeRemaining} left)'),
              ),
            const SizedBox(height: 8),
            _PlanTile(
              title: premiumCoversThis
                  ? 'Premium — all $home zoos'
                  : 'Premium (home country)',
              price: _priceFor(ProductKind.premiumCountry),
              subtitle: !homeSet
                  ? 'Set your home country in Settings to enable.'
                  : (premiumCoversThis
                      ? 'Unlocks every zoo in $home.'
                      : 'Covers $home zoos — this zoo is in ${zoo.country}. Choose Unlimited.'),
              enabled: !_busy && premiumCoversThis,
              onTap: () => _buy(ProductKind.premiumCountry),
            ),
            const SizedBox(height: 8),
            _PlanTile(
              title: 'Unlimited — every zoo, worldwide',
              price: _priceFor(ProductKind.unlimited),
              subtitle: 'One-time purchase, all zoos everywhere.',
              enabled: !_busy && !ent.isUnlimited,
              onTap: () => _buy(ProductKind.unlimited),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _restore,
              child: const Text('Restore purchases'),
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
