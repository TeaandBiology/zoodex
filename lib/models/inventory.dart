import 'species.dart';
import 'zoo.dart';

/// A zoo paired with the list of species recorded as living there.
///
/// This is built at runtime by `ReferenceData` from a zoo's inventory file; it
/// isn't stored on disk in this exact shape.
class ZooInventory {
  final Zoo zoo;
  final List<Species> species;

  const ZooInventory({required this.zoo, required this.species});
}
