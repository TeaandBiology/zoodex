import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/data_loader.dart';
import '../data/seen_store.dart';
import '../models/observation.dart';
import '../models/species.dart';
import '../widgets/error_view.dart';
import '../widgets/scientific_name.dart';
import '../widgets/iucn_badge.dart';
import '../widgets/count_badge.dart';

import 'species_detail_screen.dart';

class ZooDexEntry {
  final String zooId;
  final String zooName;
  final Species species;
  final int count;
  final DateTime lastSeen;

  const ZooDexEntry({
    required this.zooId,
    required this.zooName,
    required this.species,
    required this.count,
    required this.lastSeen,
  });
}

class ZooDexScreen extends StatefulWidget {
  const ZooDexScreen({super.key});

  @override
  State<ZooDexScreen> createState() => _ZooDexScreenState();
}

class _ZooDexScreenState extends State<ZooDexScreen> {
  String _query = '';

  Future<List<ZooDexEntry>> _loadZooDex() async {
    final entries = <ZooDexEntry>[];

    final packs = await DataLoader.loadZooPacks();
    for (final pack in packs) {
      final zoos = (pack['zoos'] as List).cast<Map<String, String>>();
      for (final z in zoos) {
        final zooId = z['id']!;
        final inv = await DataLoader.loadZooInventory(zooId);

        final speciesById = {for (final s in inv.species) s.id: s};
        final zooName = inv.zoo.name;

        // Get all keys then filter for this zooId
        for (final k in SeenStore.allKeys()) {
          final parts = k.split('::');
          if (parts.length != 2) continue;
          if (parts[0] != zooId) continue;

          final speciesId = parts[1];
          final species = speciesById[speciesId];
          if (species == null) continue;

          final history = SeenStore.list(zooId, speciesId);
          if (history.isEmpty) continue;

          final lastSeen = history
              .map((o) => o.seenAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);

          entries.add(
            ZooDexEntry(
              zooId: zooId,
              zooName: zooName,
              species: species,
              count: history.length,
              lastSeen: lastSeen,
            ),
          );
        }
      }
    }

    entries.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: Hive.box('seen').listenable(),
      builder: (context, box, _) {
        return FutureBuilder<List<ZooDexEntry>>(
          future: _loadZooDex(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Scaffold(body: ErrorView(error: snapshot.error));
            }

            final data = snapshot.data ?? const <ZooDexEntry>[];
            final q = _query.trim().toLowerCase();

            final filtered = q.isEmpty
                ? data
                : data.where((e) {
                    return e.species.commonName.toLowerCase().contains(q) ||
                        e.species.scientificName.toLowerCase().contains(q) ||
                        e.species.group.toLowerCase().contains(q) ||
                        e.zooName.toLowerCase().contains(q);
                  }).toList();

            return Scaffold(
              appBar: AppBar(
                title: Text('Species (${filtered.length})'),
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search species, zoo, group…',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No observations yet.'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final e = filtered[i];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e.species.commonName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    CountBadge(count: e.count),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ScientificName(
                                            name: e.species.scientificName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              IucnBadge(code: e.species.iucn, small: true),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  e.species.group,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          _Pill(text: e.zooName),
                                          Text(
                                            'Last seen: ${formatLocalDateTime(e.lastSeen)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.of(context).pushNamed(
                                    '/detail',
                                    arguments: SpeciesDetailArgs(
                                      zooId: e.zooId,
                                      zooName: e.zooName,
                                      species: e.species,
                                    ),
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
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}
