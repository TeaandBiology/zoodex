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
  /// e.g. assets/data/inventories/london_zoo.json  => zooId = "london_zoo"
  static const inventories = <String, String>{
    'london_zoo': 'assets/data/inventories/london_zoo.json',
    'chester_zoo': 'assets/data/inventories/chester_zoo.json',
  };

  /// Known zoo packs used by the UI for selection. Each entry contains an
  /// `id` (the zooId) and the corresponding `asset` path. Keep this in sync
  /// with `inventories` above.
  static const knownZooPacks = <Map<String, String>>[
    {'id': 'london_zoo', 'asset': 'assets/data/inventories/london_zoo.json'},
    {'id': 'chester_zoo', 'asset': 'assets/data/inventories/chester_zoo.json'},
  ];

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
  static Future<ZooInventory> loadZooInventory(String zooId) async {
    final invAsset = inventories[zooId];
    if (invAsset == null) {
      throw Exception('Unknown zooId: $zooId. Add it to DataLoader.inventories.');
    }

    final zoos = await loadZoos();
    final zoo = zoos.firstWhere(
      (z) => z.id == zooId,
      orElse: () => throw Exception('Zoo not found in zoos.json for id=$zooId'),
    );

    final rawInv = await rootBundle.loadString(invAsset);
    final invDecoded = jsonDecode(rawInv);

    if (invDecoded is! Map) {
      throw Exception('Inventory file must be a JSON object: $invAsset');
    }
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
    // { "items": [ { "species_id": "...", "zone": "..." }, ... ] }
    final itemsField = invMap['items'];
    if (itemsField is List) {
      final catalog = await loadSpeciesCatalog();
      final byId = {for (final s in catalog) s.id: s};

      final species = <Species>[];

      for (final item in itemsField) {
        if (item is! Map) continue;
        final itemMap = Map<String, dynamic>.from(item);

        final id = itemMap['species_id'];
        if (id is! String || id.isEmpty) continue;

        final base = byId[id];
        if (base == null) {
          throw Exception('Unknown species_id "$id" in $invAsset');
        }

        final overrideZone = itemMap['zone'];
        final zone = (overrideZone is String && overrideZone.trim().isNotEmpty)
            ? overrideZone
            : base.zone;

        // Create a new Species with overridden zone
        species.add(Species(
          id: base.id,
          commonName: base.commonName,
          scientificName: base.scientificName,
          group: base.group,
          zone: zone,
          description: base.description,
        ));
      }

      // Keep deterministic ordering (by common name)
      species.sort((a, b) => a.commonName.compareTo(b.commonName));

      return ZooInventory(zoo: zoo, species: species);
    }

    // Case 1: inventory contains species_ids
    final idsField = invMap['species_ids'];
    if (idsField is List) {
      final ids = idsField.whereType<String>().toSet();

      final catalog = await loadSpeciesCatalog();
      final byId = {for (final s in catalog) s.id: s};

      final species = <Species>[];
      for (final id in ids) {
        final s = byId[id];
        if (s != null) species.add(s);
      }

      // Keep deterministic ordering (by common name)
      species.sort((a, b) => a.commonName.compareTo(b.commonName));

      return ZooInventory(zoo: zoo, species: species);
    }

    throw Exception(
      'Inventory must contain either "species" (full objects), "species_ids" (list of IDs), or "items" (list of {species_id,...}). File: $invAsset',
    );
  }
}
