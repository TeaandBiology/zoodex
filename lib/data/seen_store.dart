import 'package:hive_flutter/hive_flutter.dart';

import '../models/observation.dart';

class SeenStore {
  static final _box = Hive.box('seen');

  static String key(String zooId, String speciesId) => '$zooId::$speciesId';

  static List<Observation> list(String zooId, String speciesId) {
    final raw = _box.get(key(zooId, speciesId));

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Observation.fromMap(m))
          .toList(growable: false);
    }

    if (raw is Map) {
      return [Observation.fromMap(raw)];
    }

    // legacy compatibility (older versions stored bools)
    if (raw is bool) {
      if (!raw) return const [];
      return [Observation(seenAt: DateTime.now())];
    }

    return const [];
  }

  static List<String> allKeys() =>
      _box.keys.whereType<String>().toList(growable: false);

  static bool hasAnyObservation(String zooId, String speciesId) =>
      list(zooId, speciesId).isNotEmpty;

  static Future<void> add(String zooId, String speciesId, Observation obs) async {
    final current = list(zooId, speciesId).toList()..add(obs);
    final payload = current.map((o) => o.toMap()).toList(growable: false);
    await _box.put(key(zooId, speciesId), payload);
  }

  static Future<void> deleteExact(
    String zooId,
    String speciesId,
    Observation obs,
  ) async {
    final current = list(zooId, speciesId).toList();

    current.removeWhere((o) {
      final sameTime = o.seenAt.toUtc() == obs.seenAt.toUtc();
      final sameLat = o.lat == obs.lat;
      final sameLng = o.lng == obs.lng;
      final sameAcc = o.accuracyM == obs.accuracyM;
      final sameNotes = o.notes == obs.notes;
      final sameZoo = o.zooName == obs.zooName;
      final sameZone = o.zone == obs.zone;
      return sameTime &&
          sameLat &&
          sameLng &&
          sameAcc &&
          sameNotes &&
          sameZoo &&
          sameZone;
    });

    if (current.isEmpty) {
      await _box.delete(key(zooId, speciesId));
      return;
    }

    final payload = current.map((o) => o.toMap()).toList(growable: false);
    await _box.put(key(zooId, speciesId), payload);
  }

  static Future<void> clear(String zooId, String speciesId) =>
      _box.delete(key(zooId, speciesId));
}
