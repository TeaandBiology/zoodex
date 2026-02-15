import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/data_loader.dart';
import '../data/seen_store.dart';
import '../models/inventory.dart';
import '../widgets/error_view.dart';
import '../widgets/scientific_name.dart';
import '../widgets/iucn_badge.dart';
import 'species_detail_screen.dart';

class ZooInventoryArgs {
  final String zooId;
  final String zooName;
  final String assetPath;
  const ZooInventoryArgs({required this.zooId, required this.zooName, required this.assetPath});
}

class ZooInventoryScreen extends StatefulWidget {
  final ZooInventoryArgs args;
  const ZooInventoryScreen({super.key, required this.args});

  @override
  State<ZooInventoryScreen> createState() => _ZooInventoryScreenState();
}

class _ZooInventoryScreenState extends State<ZooInventoryScreen> {
  late final Future<ZooInventory> _invFuture;
  String _query = '';
  String? _groupFilter;
  bool _comingSoon = false;

  @override
  void initState() {
    super.initState();
    // If this zoo isn't one of the known inventory packs, show a "Coming soon"
    // placeholder instead of attempting to load a missing asset.
    if (!DataLoader.inventories.containsKey(widget.args.zooId)) {
      _comingSoon = true;
    } else {
      _invFuture = DataLoader.loadZooInventory(widget.args.zooId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_comingSoon) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.args.zooName)),
        body: const Center(child: Text('Coming soon...')),
      );
    }

    return FutureBuilder<ZooInventory>(
      future: _invFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(body: ErrorView(error: snapshot.error));
        }
        final inv = snapshot.data;
        if (inv == null) {
          return const Scaffold(body: Center(child: Text('No data.')));
        }

        final total = inv.species.length;
        final seenCount = inv.species
            .where((s) => SeenStore.hasAnyObservation(inv.zoo.id, s.id))
            .length;

        final groups = inv.species.map((s) => s.group).toSet().toList()..sort();

        final q = _query.trim().toLowerCase();
        final filtered = inv.species.where((s) {
          final matchesGroup = _groupFilter == null || s.group == _groupFilter;
          if (!matchesGroup) return false;
          if (q.isEmpty) return true;

          return s.commonName.toLowerCase().contains(q) ||
              s.scientificName.toLowerCase().contains(q) ||
              s.group.toLowerCase().contains(q) ||
              s.zone.toLowerCase().contains(q);
        }).toList()
          ..sort((a, b) => a.commonName.compareTo(b.commonName));

        return Scaffold(
          appBar: AppBar(title: Text('${inv.zoo.name} ($seenCount/$total)')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search species, group, zone…',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String?>(
                      value: _groupFilter,
                      hint: const Text('Group'),
                      onChanged: (value) => setState(() => _groupFilter = value),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All'),
                        ),
                        ...groups.map(
                          (g) => DropdownMenuItem<String?>(
                            value: g,
                            child: Text(g),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<Box>(
                  valueListenable: Hive.box('seen').listenable(),
                  builder: (context, box, _) {
                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = filtered[i];
                        final obsCount = SeenStore.list(inv.zoo.id, s.id).length;
                        final seen = obsCount > 0;

                        return ListTile(
                          title: Text(
                            s.commonName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ScientificName(name: s.scientificName),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  IucnBadge(code: s.iucn, small: true),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(s.group)),
                                ],
                              ),
                            ],
                          ),
                          trailing: seen
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$obsCount',
                                    style:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              '/detail',
                              arguments: SpeciesDetailArgs(
                                zooId: inv.zoo.id,
                                zooName: inv.zoo.name,
                                species: s,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
