import 'species.dart';
import 'zoo.dart';

class ZooInventory {
  final Zoo zoo;

  /// Species present at this zoo (from the zoo’s inventory file / old pack file).
  final List<Species> species;

  const ZooInventory({
    required this.zoo,
    required this.species,
  });

  /// New structure (recommended):
  /// { "zoo": { ... }, "species": [ ... ] }
  ///
  /// Also supports old pack structure:
  /// { "pack_id": "...", "zoo_name": "...", "last_updated": "...", "species": [ ... ] }
  factory ZooInventory.fromJson(Map<String, dynamic> json) {
    final zooJson = (json['zoo'] is Map<String, dynamic>)
        ? (json['zoo'] as Map<String, dynamic>)
        : json; // old pack: zoo fields at root

    final speciesList = (json['species'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((m) => Species.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);

    return ZooInventory(
      zoo: Zoo.fromJson(zooJson.cast<String, dynamic>()),
      species: speciesList,
    );
  }

  Map<String, dynamic> toJson() => {
        'zoo': zoo.toJson(),
        'species': species.map((s) => s.toJson()).toList(growable: false),
      };
}
