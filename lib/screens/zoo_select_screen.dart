import 'package:flutter/material.dart';

import '../data/entitlement_store.dart';
import '../l10n/app_localizations.dart';
import '../data/reference_data.dart';
import '../models/entitlement.dart';
import '../models/inventory.dart';
import '../models/zoo.dart';
import 'paywall_sheet.dart';
import 'zoo_inventory_screen.dart';
import 'zoo_map_view.dart';

enum _ZooView { map, list }

/// Open the zoo's inventory if the user has access, otherwise prompt to unlock.
/// Shared by both the map pins and the list tiles so they behave identically.
void openZooOrUnlock(BuildContext context, Zoo zoo, bool unlocked) {
  if (unlocked) {
    Navigator.of(context).pushNamed(
      '/inventory',
      arguments: ZooInventoryArgs(
        zooId: zoo.id,
        assetPath: 'assets/data/inventories/${zoo.id}.json',
      ),
    );
  } else {
    showUnlockSheet(context, zoo);
  }
}

class ZooSelectScreen extends StatefulWidget {
  const ZooSelectScreen({super.key});

  @override
  State<ZooSelectScreen> createState() => _ZooSelectScreenState();
}

class _ZooSelectScreenState extends State<ZooSelectScreen> {
  String _query = '';
  _ZooView _view = _ZooView.map; // map is the default on load

  @override
  Widget build(BuildContext context) {
    final all = ReferenceData.instance.zoos;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).zooSelectTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<_ZooView>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: _ZooView.map,
                    icon: const Icon(Icons.map_outlined),
                    label: Text(AppLocalizations.of(context).zooSelectViewMap)),
                ButtonSegment(
                    value: _ZooView.list,
                    icon: const Icon(Icons.list),
                    label: Text(AppLocalizations.of(context).zooSelectViewList)),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<Entitlement>(
        valueListenable: EntitlementStore.current,
        builder: (context, ent, _) {
          return Column(
            children: [
              _PlanBanner(ent: ent),
              const Divider(height: 1),
              Expanded(
                child: _view == _ZooView.map
                    ? ZooMapView(
                        zoos: all,
                        entitlement: ent,
                        onOpenZoo: (zoo) => openZooOrUnlock(
                            context, zoo, ent.grantsAccessTo(zoo)),
                      )
                    : _ZooList(
                        zoos: all,
                        ent: ent,
                        query: _query,
                        onQueryChanged: (v) => setState(() => _query = v),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ZooList extends StatelessWidget {
  final List<Zoo> zoos;
  final Entitlement ent;
  final String query;
  final ValueChanged<String> onQueryChanged;

  const _ZooList({
    required this.zoos,
    required this.ent,
    required this.query,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? zoos
        : zoos
            .where((z) =>
                z.name.toLowerCase().contains(q) ||
                z.country.toLowerCase().contains(q))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).zooSelectSearchHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: AppLocalizations.of(context).zooSelectClear,
                      icon: const Icon(Icons.clear),
                      onPressed: () => onQueryChanged(''),
                    ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(AppLocalizations.of(context).zooSelectNoMatches))
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final zoo = filtered[i];
                    return _ZooTile(
                        zoo: zoo, unlocked: ent.grantsAccessTo(zoo));
                  },
                ),
        ),
      ],
    );
  }
}

class _PlanBanner extends StatelessWidget {
  final Entitlement ent;
  const _PlanBanner({required this.ent});

  @override
  Widget build(BuildContext context) {
    String text;
    if (ent.isUnlimited) {
      text = AppLocalizations.of(context).zooSelectPlanUnlimited;
    } else if (ent.isPremium) {
      text = AppLocalizations.of(context).zooSelectPlanPremium(ent.premiumCountry ?? '');
    } else {
      text = AppLocalizations.of(context)
          .zooSelectPlanFree(ent.freeRemaining, Entitlement.maxFree);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(ent.isUnlimited || ent.isPremium ? Icons.verified : Icons.star_outline,
              size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ZooTile extends StatelessWidget {
  final Zoo zoo;
  final bool unlocked;
  const _ZooTile({required this.zoo, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ZooInventory>(
      future: ReferenceData.instance.loadZooInventory(zoo.id),
      builder: (context, snap) {
        final count = snap.hasData ? snap.data!.species.length : null;
        final subtitleParts = <String>[
          if (count != null)
            AppLocalizations.of(context).zooSelectSpeciesCount(count),
          if (zoo.country.isNotEmpty) zoo.country,
          if (!unlocked) AppLocalizations.of(context).zooSelectLocked,
        ];

        return ListTile(
          leading: Icon(unlocked ? Icons.lock_open : Icons.lock_outline,
              color: unlocked
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline),
          title: Text(zoo.name),
          subtitle:
              subtitleParts.isEmpty ? null : Text(subtitleParts.join(' • ')),
          trailing: Icon(unlocked ? Icons.chevron_right : Icons.lock),
          onTap: () => openZooOrUnlock(context, zoo, unlocked),
        );
      },
    );
  }
}
