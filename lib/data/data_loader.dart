import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/zoo.dart';
import '../models/species.dart';
import '../models/inventory.dart';

/// These must match your pubspec.yaml assets:
/// - assets/data/zoos.json
/// - assets/data/species_catalog.json
/// - assets/data/inventories/<zooId>.json
class DataLoader {
  static const zoosAsset = 'assets/data/zoos.json';
  static const speciesCatalogAsset = 'assets/data/species_catalog.json';

  /// Map zooId -> inventory asset path
  /// IMPORTANT: The keys here should match the filename in assets/data/inventories/
  /// e.g. assets/data/inventories/zsl_london_zoo.json  => zooId = "zsl_london_zoo"
  // This map is now dynamically generated at runtime. The static version is kept for legacy compatibility.
  static const inventories = <String, String>{
    'zsl_london_zoo': 'assets/data/inventories/zsl_london_zoo.json',
    'chester_zoo': 'assets/data/inventories/chester_zoo.json',
    // All other zoos are loaded dynamically; missing entries are handled gracefully.
  };

  /// Known zoo packs used by the UI. Each pack groups multiple zoo entries
  /// so you can have country- or region-level packs in future.
  /// Each pack has a `packId`, a human `label` and a `zoos` list containing
  /// entries with `id` and `asset` for each individual zoo inventory file.
  // Deprecated: use loadZooPacks() for dynamic packs.
  static const knownZooPacks = <Map<String, Object>>[];

  /// Load packs dynamically from `zoos.json` so we can treat the entire
  /// catalog as a single UK pack without keeping the list in sync manually.
  static Future<List<Map<String, Object>>> loadZooPacks() async {
    final zoos = await loadZoos();
    final zoosList = zoos
        .map((z) => {'id': z.id, 'asset': 'assets/data/inventories/${z.id}.json'})
        .toList(growable: false);

    return [
      {
        'packId': 'uk',
        'label': 'UK',
        'zoos': zoosList,
      }
    ];
  }

  static Future<List<Zoo>> loadZoos() async {
    final raw = await rootBundle.loadString(zoosAsset);
    final decoded = jsonDecode(raw);

    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((m) => Zoo.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    }

    if (decoded is Map && decoded['zoos'] is List) {
      return (decoded['zoos'] as List)
          .whereType<Map>()
          .map((m) => Zoo.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    }

    throw Exception('zoos.json must be a List or a { "zoos": [...] } object.');
  }

  static Future<List<Species>> loadSpeciesCatalog() async {
    final raw = await rootBundle.loadString(speciesCatalogAsset);
    final decoded = jsonDecode(raw);

    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((m) => Species.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    }

    if (decoded is Map && decoded['species'] is List) {
      return (decoded['species'] as List)
          .whereType<Map>()
          .map((m) => Species.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    }

    throw Exception(
      'species_catalog.json must be a List or a { "species": [...] } object.',
    );
  }

  /// Loads a ZooInventory (Zoo + full Species objects) for a given zooId.
  ///
  /// This supports three inventory JSON shapes:
  /// 1) { "species_ids": ["sp1","sp2", ...] }
  /// 2) { "species": [ {full species objects}, ... ] }
  /// 3) { "items": [ { "species_id": "sp1", "zone": "..." }, ... ] }
  ///
  /// If multiple are present, precedence is:
  /// "species" wins, then "items", then "species_ids".
  static Future<ZooInventory?> tryLoadZooInventory(String zooId) async {
    final assetPath = 'assets/data/inventories/$zooId.json';
    try {
      final zoos = await loadZoos();
      Zoo? zoo;
      for (final z in zoos) {
        if (z.id == zooId) {
          zoo = z;
          break;
        }
      }
      if (zoo == null) return null;

      final rawInv = await rootBundle.loadString(assetPath);
      final invDecoded = jsonDecode(rawInv);
      if (invDecoded is! Map) return null;
      final invMap = Map<String, dynamic>.from(invDecoded);

      // Case 2: inventory contains full species objects
      final speciesField = invMap['species'];
      if (speciesField is List) {
        final species = speciesField
            .whereType<Map>()
            .map((m) => Species.fromJson(Map<String, dynamic>.from(m)))
            .toList(growable: false);
        return ZooInventory(zoo: zoo, species: species);
      }

      // Case 3: inventory contains items with per-zoo overrides
      final itemsField = invMap['items'];
      if (itemsField is List) {
        final catalog = await loadSpeciesCatalog();
        final species = <Species>[];
        for (final item in itemsField) {
          if (item is Map && item['species_id'] is String) {
            Species? base;
            for (final s in catalog) {
              if (s.id == item['species_id']) {
                base = s;
                break;
              }
            }
            if (base != null) {
              species.add(Species(
                id: base.id,
                commonName: base.commonName,
                scientificName: base.scientificName,
                group: base.group,
                zone: item['zone'] as String? ?? base.zone,
                description: item['description'] as String? ?? base.description,
                range: item['range'] as String? ?? base.range,
                iucn: base.iucn,
              ));
            }
          }
        }
        return ZooInventory(zoo: zoo, species: species);
      }

      // Case 1: inventory contains only species_ids
      final speciesIds = invMap['species_ids'];
      if (speciesIds is List) {
        final catalog = await loadSpeciesCatalog();
        final species = <Species>[];
        for (final s in catalog) {
          if (speciesIds.contains(s.id)) {
            species.add(s);
          }
        }
        return ZooInventory(zoo: zoo, species: species);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Legacy: throws if missing
  static Future<ZooInventory> loadZooInventory(String zooId) async {
    final inv = await tryLoadZooInventory(zooId);
    if (inv == null) {
      throw Exception('Unknown zooId: $zooId. No inventory file found.');
    }
    return inv;
  }

}