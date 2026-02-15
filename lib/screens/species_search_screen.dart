// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../data/data_loader.dart';
import '../data/seen_store.dart';
import '../models/inventory.dart';
import '../models/species.dart';
import '../widgets/error_view.dart';
import '../widgets/scientific_name.dart';
import '../widgets/iucn_badge.dart';

import 'species_detail_screen.dart';

class SpeciesSearchScreen extends StatefulWidget {
  const SpeciesSearchScreen({super.key});

  @override
  State<SpeciesSearchScreen> createState() => _SpeciesSearchScreenState();
}

class _SpeciesSearchScreenState extends State<SpeciesSearchScreen> {
  late final Future<List<Species>> _catalogFuture;
  String _query = '';
  List<Map<String, Object>>? _packs;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _loadCatalog();
    DataLoader.loadZooPacks().then((p) => setState(() => _packs = p));
  }

  Future<List<Species>> _loadCatalog() async {
    // Expects a list of species objects with the same keys as your pack species:
    // id, common_name, scientific_name, zone, description
    final raw = await rootBundle.loadString('assets/data/species_catalog.json');
    final decoded = jsonDecode(raw);

    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((m) => Species.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false);
    }

    // Allow { "species": [ ... ] } too
    if (decoded is Map && decoded['species'] is List) {
      final list = (decoded['species'] as List).whereType<Map>();
      return list
          .map((m) => Species.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false);
    }

    throw Exception('species_catalog.json must be a List or { "species": [...] }');
  }

  Future<ZooInventory?> _tryLoadZoo(String zooId) async {
    return DataLoader.tryLoadZooInventory(zooId);
  }

  Future<({String zooId, String zooName})?> _pickZooForSpecies(Species s) async {
    // Build a light list of zoos (name + id) by loading each inventory.
    // Small N => fine for now; later you’ll drive this from zoos.json.
    final zoos = <({String id, String name})>[];

    final packs = _packs ?? DataLoader.knownZooPacks;
    for (final pack in packs) {
      final zoosInPack = (pack['zoos'] as List).cast<Map<String, String>>();
      for (final z in zoosInPack) {
        final inv = await _tryLoadZoo(z['id']!);
        if (inv != null) {
          zoos.add((id: inv.zoo.id, name: inv.zoo.name));
        }
      }
    }

    if (!mounted) return null;

    final ctx = context;

    return showDialog<({String zooId, String zooName})>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('Which zoo did you see this at?'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: zoos.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final z = zoos[i];
              return ListTile(
                title: Text(z.name),
                subtitle: Text(z.id),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(
                  context,
                  (zooId: z.id, zooName: z.name),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSpeciesAtZoo(Species s) async {
    final picked = await _pickZooForSpecies(s);
    if (picked == null) return;

    // Optional: if the zoo inventory doesn’t contain this species, warn but allow logging anyway.
    final inv = await _tryLoadZoo(picked.zooId);
    final existsInZoo = inv?.species.any((x) => x.id == s.id) ?? false;

    if (!mounted) return;

    final ctx = context;

    if (!existsInZoo) {
      final ok = await showDialog<bool>(
        context: ctx,
        builder: (context) => AlertDialog(
          title: const Text('Not in this zoo inventory'),
          content: const Text(
            'This species is not listed for that zoo. Log it anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log anyway'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    // Use the zoo’s version of the species if present (zone/description may differ),
    // otherwise fall back to catalog species.
    final zooSpecies = inv?.species.firstWhere(
          (x) => x.id == s.id,
          orElse: () => s,
        ) ?? s;

    Navigator.of(ctx).pushNamed(
      '/detail',
      arguments: SpeciesDetailArgs(
        zooId: picked.zooId,
        zooName: picked.zooName,
        species: zooSpecies,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Species>>(
      future: _catalogFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: ErrorView(error: snapshot.error));
        }

        final all = snapshot.data ?? const <Species>[];
        final q = _query.trim().toLowerCase();

        final filtered = q.isEmpty
          ? all
          : all.where((s) {
            return s.commonName.toLowerCase().contains(q) ||
              s.scientificName.toLowerCase().contains(q);
            }).toList();

        filtered.sort((a, b) => a.commonName.compareTo(b.commonName));

        return Scaffold(
          appBar: AppBar(title: Text('Species search (${filtered.length})')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search species, scientific name…',
                      border: OutlineInputBorder(),
                    ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No matches.'))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = filtered[i];

                          // Lightweight “seen anywhere” indicator across zoos
                          final packsForCheck = _packs ?? DataLoader.knownZooPacks;
                          var seenAnywhere = false;
                          for (final pack in packsForCheck) {
                            final zoosInPack = (pack['zoos'] as List).cast<Map<String, String>>();
                            for (final z in zoosInPack) {
                              final zooId = z['id']!;
                              if (DataLoader.inventories.containsKey(zooId)) {
                                if (SeenStore.hasAnyObservation(zooId, s.id)) {
                                  seenAnywhere = true;
                                  break;
                                }
                              }
                            }
                            if (seenAnywhere) break;
                          }

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
                            trailing: seenAnywhere
                                ? const Icon(Icons.check_circle)
                                : const Icon(Icons.chevron_right),
                            onTap: () => _openSpeciesAtZoo(s),
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
