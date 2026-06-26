import 'package:flutter/foundation.dart' show ValueListenable, debugPrint;
import 'package:hive_flutter/hive_flutter.dart';

import '../models/dex_entry.dart';
import '../models/species_log.dart';
import '../models/verification.dart';
import '../models/visit.dart';
import '../util/date_format.dart';
import 'reference_data.dart';

/// User data: visits and their per-species outcomes, plus the derived Dex.
/// Stored in the Hive `visits` box keyed by `zooId::yyyy-mm-dd`.
class VisitStore {
  VisitStore._();

  static const String boxName = 'visits';
  static const String _migratedFlag = 'migrated_seen_v1';

  static Box get _box => Hive.box(boxName);

  static ValueListenable<Box> listenable() => _box.listenable();

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  static Visit? getVisit(String zooId, DateTime date) {
    final raw = _box.get(Visit.keyFor(zooId, date));
    return raw is Map ? Visit.fromMap(raw) : null;
  }

  static List<Visit> allVisits() =>
      _box.values.whereType<Map>().map(Visit.fromMap).toList(growable: false);

  /// Every (visit, log) pair for a species, newest first.
  static List<({Visit visit, SpeciesLog log})> historyForSpecies(
    String speciesId,
  ) {
    final out = <({Visit visit, SpeciesLog log})>[];
    for (final v in allVisits()) {
      final l = v.logs[speciesId];
      if (l != null) out.add((visit: v, log: l));
    }
    out.sort((a, b) => b.log.loggedAt.compareTo(a.log.loggedAt));
    return out;
  }

  static bool seenEver(String speciesId) {
    for (final v in allVisits()) {
      final l = v.logs[speciesId];
      if (l != null && l.outcome == Outcome.seen) return true;
    }
    return false;
  }

  /// Distinct species marked seen across all of a zoo's visits.
  static int seenSpeciesCountAtZoo(String zooId) {
    final ids = <String>{};
    for (final v in allVisits()) {
      if (v.zooId != zooId) continue;
      v.logs.forEach((sid, l) {
        if (l.outcome == Outcome.seen) ids.add(sid);
      });
    }
    return ids.length;
  }

  /// Number of visits at [zooId] where [speciesId] was seen.
  static int seenVisitsAtZoo(String zooId, String speciesId) {
    var n = 0;
    for (final v in allVisits()) {
      if (v.zooId != zooId) continue;
      final l = v.logs[speciesId];
      if (l != null && l.outcome == Outcome.seen) n++;
    }
    return n;
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  static Future<Visit> _persist(Visit v) async {
    await _box.put(v.key, v.toMap());
    return v;
  }

  /// Record (or update) a species outcome on the `(zoo, date)` visit. [when]
  /// defaults to now; logs to the visit for that day, creating it if needed.
  static Future<Visit> logSpecies(
    String zooId,
    String speciesId, {
    Outcome outcome = Outcome.seen,
    String? note,
    DateTime? when,
  }) async {
    // Always store against the canonical species id, so a species that was once
    // duplicated and later merged collapses to a single record everywhere.
    speciesId = ReferenceData.instance.resolveId(speciesId);

    final ts = when ?? DateTime.now();
    final d = dateOnly(ts);
    var v = getVisit(zooId, d);
    v ??= Visit(
      id: Visit.keyFor(zooId, d),
      zooId: zooId,
      date: d,
      firstLoggedAt: ts,
      lastLoggedAt: ts,
    );

    final existing = v.logs[speciesId];
    v.logs[speciesId] = SpeciesLog(
      visitId: v.id,
      speciesId: speciesId,
      outcome: outcome,
      loggedAt: ts,
      note: note ?? existing?.note,
    );

    if (ts.isBefore(v.firstLoggedAt)) v.firstLoggedAt = ts;
    if (ts.isAfter(v.lastLoggedAt)) v.lastLoggedAt = ts;
    return _persist(v);
  }

  static Future<void> removeLog(
    String zooId,
    String speciesId,
    DateTime date,
  ) async {
    final v = getVisit(zooId, date);
    if (v == null) return;
    v.logs.remove(speciesId);
    if (v.logs.isEmpty) {
      await _box.delete(v.key);
    } else {
      await _persist(v);
    }
  }

  static Future<void> setNote(
    String zooId,
    String speciesId,
    DateTime date,
    String? note,
  ) async {
    final v = getVisit(zooId, date);
    final l = v?.logs[speciesId];
    if (v == null || l == null) return;
    v.logs[speciesId] =
        l.copyWith(note: note, clearNote: note == null || note.isEmpty);
    await _persist(v);
  }

  /// Upgrade a day's visit to verified. Never downgrades an already-verified
  /// visit, so a later poor fix can't undo an earlier good one.
  static Future<void> markVerified(String zooId, DateTime date) async {
    final v = getVisit(zooId, date);
    if (v == null || v.verified == VerificationStatus.verified) return;
    v.verified = VerificationStatus.verified;
    await _persist(v);
  }

  // ---------------------------------------------------------------------------
  // Dev-only helpers
  // ---------------------------------------------------------------------------

  /// Synthetic zoo id used to hold the "add all species" dev sightings, so they
  /// can be added and removed without touching any real visit.
  static const String devZooId = 'dev_all_species';
  static final DateTime _devWhen = DateTime(2020, 1, 1, 12);

  /// Dev helper: marks every catalogue species as seen under one synthetic
  /// visit, so the Species tab shows the whole catalogue. Returns the count.
  static Future<int> devAddAllSpecies() async {
    final all = ReferenceData.instance.allSpecies;
    final d = dateOnly(_devWhen);
    final v = getVisit(devZooId, d) ??
        Visit(
          id: Visit.keyFor(devZooId, d),
          zooId: devZooId,
          date: d,
          firstLoggedAt: _devWhen,
          lastLoggedAt: _devWhen,
        );
    for (final s in all) {
      v.logs[s.id] = SpeciesLog(
        visitId: v.id,
        speciesId: s.id,
        outcome: Outcome.seen,
        loggedAt: _devWhen,
      );
    }
    await _persist(v);
    return all.length;
  }

  /// Dev helper: removes only the synthetic "add all species" visit, leaving
  /// real sightings untouched.
  static Future<void> devRemoveAllSpecies() async {
    await _box.delete(Visit.keyFor(devZooId, dateOnly(_devWhen)));
  }

  // ---------------------------------------------------------------------------
  // Derived Dex
  // ---------------------------------------------------------------------------

  /// Builds the Dex by aggregating "seen" logs. When [rollUp] is true, sightings
  /// of a subspecies/breed are grouped under their parent species (so the
  /// Species tab shows one "Tiger" card); otherwise each leaf is its own entry.
  static List<DexEntry> buildDex({bool rollUp = false}) {
    final ref = ReferenceData.instance;
    final agg = <String, _Agg>{};
    for (final v in allVisits()) {
      v.logs.forEach((sid, l) {
        if (l.outcome != Outcome.seen) return;
        final key = rollUp ? ref.rollupId(sid) : sid;
        final a = agg.putIfAbsent(key, _Agg.new);
        a.visitKeys.add(v.key);
        a.zoos.add(v.zooId);
        final t = l.loggedAt;
        if (a.first == null || t.isBefore(a.first!)) a.first = t;
        if (a.last == null || t.isAfter(a.last!)) {
          a.last = t;
          a.lastZooId = v.zooId;
        }
        if (v.verified == VerificationStatus.verified) a.everVerified = true;
      });
    }
    return agg.entries
        .map((e) => DexEntry(
              speciesId: e.key,
              seenEver: true,
              firstSeenAt: e.value.first,
              lastSeenAt: e.value.last,
              visitsSeenCount: e.value.visitKeys.length,
              everVerified: e.value.everVerified,
              zoosSeenAt: e.value.zoos,
              lastZooId: e.value.lastZooId,
            ))
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // One-time migration from the old flat `seen` box
  // ---------------------------------------------------------------------------

  /// Converts legacy `seen` records (keyed `zooId::speciesRef` -> [observations])
  /// into date-grouped visits. Old species references are resolved to opaque
  /// ids via [ReferenceData]; unresolved ones are skipped. Runs once.
  static Future<void> migrateLegacySeenIfNeeded() async {
    final settings = Hive.box('settings');
    if (settings.get(_migratedFlag) == true) return;

    Box? seen;
    try {
      seen = Hive.box('seen');
    } catch (_) {
      seen = null;
    }

    var migrated = 0;
    var skipped = 0;
    if (seen != null) {
      for (final k in seen.keys.whereType<String>().toList()) {
        final parts = k.split('::');
        if (parts.length != 2) continue;
        final zooId = parts[0];
        final species = ReferenceData.instance.speciesById(parts[1]);
        if (species == null) {
          skipped++;
          continue;
        }
        final raw = seen.get(k);
        final obs = <Map>[];
        if (raw is List) {
          obs.addAll(raw.whereType<Map>());
        } else if (raw is Map) {
          obs.add(raw);
        }
        for (final o in obs) {
          final sa = o['seenAt'];
          final when = sa is String
              ? (DateTime.tryParse(sa) ?? DateTime.now())
              : DateTime.now();
          await logSpecies(
            zooId,
            species.id,
            outcome: Outcome.seen,
            note: o['notes'] as String?,
            when: when,
          );
        }
        migrated++;
      }
    }

    await settings.put(_migratedFlag, true);
    debugPrint('[VisitStore] legacy migration: $migrated key(s), $skipped skipped');
  }

  static const String _normalizedFlag = 'normalized_species_ids_v1';

  /// Rewrites any stored sightings that were logged against an old species id to
  /// the current canonical id (via [ReferenceData.resolveId]). This is what
  /// merges sightings of a species that used to be duplicated — e.g. one logged
  /// at a zoo that referenced the old id and one at a zoo that referenced the
  /// new id now land on the same species. Runs once; harmless if nothing changed.
  static Future<void> normalizeSpeciesIdsIfNeeded() async {
    final settings = Hive.box('settings');
    if (settings.get(_normalizedFlag) == true) return;

    var changed = 0;
    for (final v in allVisits()) {
      var dirty = false;
      final merged = <String, SpeciesLog>{};
      v.logs.forEach((sid, log) {
        final canon = ReferenceData.instance.resolveId(sid);
        if (canon != sid) dirty = true;
        final existing = merged[canon];
        if (existing == null) {
          merged[canon] = log;
        } else {
          // Two old ids collapsed to the same species within one visit: keep the
          // later timestamp, and treat it as "seen" if either record was a sighting.
          final later =
              log.loggedAt.isAfter(existing.loggedAt) ? log : existing;
          final seen =
              log.outcome == Outcome.seen || existing.outcome == Outcome.seen;
          merged[canon] = SpeciesLog(
            visitId: v.id,
            speciesId: canon,
            outcome: seen ? Outcome.seen : Outcome.noShow,
            loggedAt: later.loggedAt,
            note: later.note,
          );
          dirty = true;
        }
      });
      if (dirty) {
        v.logs
          ..clear()
          ..addAll(merged);
        await _box.put(v.key, v.toMap());
        changed++;
      }
    }

    await settings.put(_normalizedFlag, true);
    debugPrint('[VisitStore] species-id normalization: $changed visit(s) updated');
  }
}

class _Agg {
  final Set<String> visitKeys = <String>{};
  DateTime? first;
  DateTime? last;
  bool everVerified = false;
  final Set<String> zoos = <String>{};
  String? lastZooId;
}
