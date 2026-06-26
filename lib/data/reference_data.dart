import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import '../models/inventory.dart';
import '../models/species.dart';
import '../models/zoo.dart';

/// Single source of truth for all *reference* data (species, zoos, inventories,
/// aliases, avatars). Owns where the data comes from — today the bundled assets;
/// later a remote, versioned manifest — so the rest of the app never cares.
///
/// Species are keyed by an opaque, permanent `id`. A readable `slug` and an
/// `aliases` table both resolve forward to that id, so inventories (and any
/// stored observations) can reference a species by slug or by an old/merged id
/// and still land on the right record. Loading is **tolerant**: a bad row is
/// skipped and logged, never thrown.
///
/// Call [init] once at startup (after Hive).
class ReferenceData {
  ReferenceData._();
  static final ReferenceData instance = ReferenceData._();

  /// Highest inventory `schema_version` this build understands. A higher remote
  /// schema is loaded leniently rather than allowed to break anything.
  static const int supportedSchemaVersion = 1;

  static const String _zoosAsset = 'assets/data/zoos.json';
  static const String _catalogAsset = 'assets/data/species_catalog.json';
  static const String _aliasesAsset = 'assets/data/aliases.json';
  static const String _creditsAsset = 'assets/data/image_credits.json';
  static const String _focusAsset = 'assets/data/image_focus.json';

  String _inventoryAsset(String zooId) => 'assets/data/inventories/$zooId.json';
  String _overlayAsset(String code) => 'assets/data/i18n/$code/species.json';

  bool _initialised = false;
  List<Zoo> _zoos = const [];
  Map<String, Species> _byId = const {};
  Map<String, Species> _bySlug = const {};
  Map<String, String> _aliases = const {};
  Map<String, String> _imageCredits = const {};
  Map<String, List<double>> _imageFocus = const {};
  List<String> _dataWarnings = const [];
  Map<String, String> _parentByChild = const {};
  Map<String, List<Species>> _childrenByParent = const {};
  final Map<String, ZooInventory> _inventoryCache = {};

  /// Active content language, and the untranslated catalogue plus the active
  /// overlay it is built from. The English catalogue is the canonical source;
  /// [_overlay] maps slug -> translated fields for [_localeCode].
  String _localeCode = 'en';
  List<Species> _catalogEn = const [];
  Map<String, Map<String, dynamic>> _overlay = const {};

  /// The active content language code (e.g. 'fr'). Defaults to 'en'.
  String get localeCode => _localeCode;

  bool get isInitialised => _initialised;

  /// All zoos, sorted by name. Valid after [init].
  List<Zoo> get zoos => _zoos;
  List<Species> get allSpecies => _byId.values.toList(growable: false);
  List<String> get zooIds => _zoos.map((z) => z.id).toList(growable: false);

  Future<void> init() async {
    if (_initialised) return;
    _aliases = await _loadAliases();
    _catalogEn = await _loadCatalog();
    _overlay = await _loadOverlay(_localeCode);
    _rebuildIndex();
    for (final w in _dataWarnings) {
      debugPrint('[ReferenceData] data warning - $w');
    }

    _imageCredits = await _loadImageCredits();
    _imageFocus = await _loadImageFocus();

    _zoos = await _loadZoos();
    _initialised = true;
    debugPrint(
      '[ReferenceData] ready: ${_zoos.length} zoos, ${_byId.length} species '
      '(${_bySlug.length} slugs), ${_aliases.length} aliases, locale $_localeCode',
    );
  }

  /// Switch the active content language: reload the per-locale catalogue overlay
  /// and rebuild the species index so common names and descriptions resolve in
  /// [code] (English fallback per field). Inventory caches are dropped so they
  /// rebuild in the new language. Cheap enough to call on a language change.
  Future<void> applyLocale(String code) async {
    final norm = code.trim().isEmpty ? 'en' : code.trim();
    if (!_initialised) {
      _localeCode = norm;
      await init();
      return;
    }
    if (norm == _localeCode) return;
    _localeCode = norm;
    _overlay = await _loadOverlay(norm);
    _rebuildIndex();
    _inventoryCache.clear();
  }

  /// Build the id/slug/rollup indexes from the English catalogue with the active
  /// locale overlay applied. Pure and re-runnable, so a language switch just
  /// calls it again.
  void _rebuildIndex() {
    final byId = <String, Species>{};
    final bySlug = <String, Species>{};
    for (final base in _catalogEn) {
      final s = base.localized(_overlay[base.slug]);
      byId[s.id] = s;
      if (s.slug.isNotEmpty && !bySlug.containsKey(s.slug)) bySlug[s.slug] = s;
    }
    _byId = byId;
    _bySlug = bySlug;

    // Rollup index: link each subspecies/breed to its parent species. parent_id
    // is authored as a slug, so resolve it the same way inventory refs are.
    final parentByChild = <String, String>{};
    final childrenByParent = <String, List<Species>>{};
    final warnings = <String>[];
    for (final s in byId.values) {
      if (s.parentId.isEmpty) continue;
      final pid = resolveId(s.parentId);
      if (!byId.containsKey(pid)) {
        // Precaution: a parent_id that doesn't resolve is almost always a typo.
        warnings.add(
            '${s.slug}: parent_id "${s.parentId}" is not in the catalogue');
        continue;
      }
      if (pid == s.id) {
        warnings.add('${s.slug}: parent_id points at itself');
        continue;
      }
      parentByChild[s.id] = pid;
      (childrenByParent[pid] ??= <Species>[]).add(s);
    }

    // Automatic linking by naming convention: a species with a three-word
    // (trinomial) scientific name is a subspecies; if a species with the matching
    // two-word (binomial) name exists, treat it as the parent. Scientific names
    // are never translated, so this grouping is locale-independent.
    final binomialToId = <String, String>{};
    for (final s in byId.values) {
      final parts = s.scientificName.trim().split(RegExp(r'\s+'));
      if (parts.length == 2) {
        binomialToId.putIfAbsent(parts.join(' ').toLowerCase(), () => s.id);
      }
    }
    for (final s in byId.values) {
      if (s.parentId.isNotEmpty) continue; // explicit link already handled
      if (parentByChild.containsKey(s.id)) continue;
      final parts = s.scientificName.trim().split(RegExp(r'\s+'));
      if (parts.length != 3) continue;
      final pid = binomialToId[parts.take(2).join(' ').toLowerCase()];
      if (pid == null || pid == s.id) continue;
      parentByChild[s.id] = pid;
      (childrenByParent[pid] ??= <Species>[]).add(s);
    }

    for (final list in childrenByParent.values) {
      list.sort((a, b) =>
          a.commonName.toLowerCase().compareTo(b.commonName.toLowerCase()));
    }
    _parentByChild = parentByChild;
    _childrenByParent = childrenByParent;
    _dataWarnings = warnings;
  }

  /// Resolve any reference (opaque id, aliased old id, or slug) to a canonical
  /// opaque id. Returns the input unchanged when nothing matches.
  String resolveId(String ref) {
    if (_byId.containsKey(ref)) return ref;
    final aliased = _aliases[ref];
    if (aliased != null) return aliased;
    final bySlug = _bySlug[ref];
    if (bySlug != null) return bySlug.id;
    return ref;
  }

  Species? speciesById(String ref) => _byId[resolveId(ref)];

  /// The parent species of a subspecies/breed, or null for a top-level species.
  Species? parentOf(String ref) {
    final pid = _parentByChild[resolveId(ref)];
    return pid == null ? null : _byId[pid];
  }

  /// The subspecies/breeds under a species, sorted by name (empty if none).
  List<Species> childrenOf(String ref) =>
      _childrenByParent[resolveId(ref)] ?? const [];

  bool hasChildren(String ref) =>
      (_childrenByParent[resolveId(ref)] ?? const []).isNotEmpty;

  /// Grouping key for the Species tab: a subspecies/breed rolls up to its parent
  /// species; everything else is its own key.
  String rollupId(String ref) {
    final id = resolveId(ref);
    return _parentByChild[id] ?? id;
  }

  Zoo? zooById(String id) {
    for (final z in _zoos) {
      if (z.id == id) return z;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Loaders (all tolerant)
  // ---------------------------------------------------------------------------

  Future<dynamic> _decode(String asset) async =>
      jsonDecode(await rootBundle.loadString(asset));

  Future<Map<String, String>> _loadImageCredits() async {
    try {
      final decoded = await _decode(_creditsAsset);
      final raw = (decoded is Map && decoded['credits'] is Map)
          ? decoded['credits'] as Map
          : (decoded is Map ? decoded : const {});
      final out = <String, String>{};
      raw.forEach((k, v) {
        if (k is String && v is String) out[k] = v;
      });
      return out;
    } catch (e) {
      // Optional file — absence just means no credits to show yet.
      debugPrint('[ReferenceData] image credits skipped: $e');
      return const {};
    }
  }

  /// Image copyright/attribution for a species' photo, keyed by slug, or '' when
  /// none is recorded. Populated from assets/data/image_credits.json (which the
  /// image downloader can emit alongside the photos).
  String imageCreditFor(Species s) => _imageCredits[s.slug] ?? '';

  /// Focal point [x, y] in 0..1 for a species' photo, or null for centre.
  /// Populated from assets/data/image_focus.json (written by the focus tagger),
  /// and used to keep the subject framed when the photo is cropped to the grid
  /// tile or the species-page hero.
  List<double>? imageFocusFor(Species s) => _imageFocus[s.slug];

  Future<Map<String, List<double>>> _loadImageFocus() async {
    try {
      final decoded = await _decode(_focusAsset);
      final raw = (decoded is Map && decoded['focus'] is Map)
          ? decoded['focus'] as Map
          : (decoded is Map ? decoded : const {});
      final out = <String, List<double>>{};
      raw.forEach((k, v) {
        if (k is String && v is List && v.length == 2) {
          out[k] = [(v[0] as num).toDouble(), (v[1] as num).toDouble()];
        }
      });
      return out;
    } catch (e) {
      debugPrint('[ReferenceData] image focus skipped: $e');
      return const {};
    }
  }

  /// Non-fatal catalogue problems found at load (e.g. a subspecies whose
  /// parent_id doesn't resolve). Surfaced by the dev "Check catalogue data" tool.
  List<String> get dataWarnings => _dataWarnings;

  Future<Map<String, String>> _loadAliases() async {
    try {
      final decoded = await _decode(_aliasesAsset);
      final raw = (decoded is Map && decoded['aliases'] is Map)
          ? decoded['aliases'] as Map
          : (decoded is Map ? decoded : const {});
      final out = <String, String>{};
      raw.forEach((k, v) {
        if (k is String && v is String) out[k] = v;
      });
      return out;
    } catch (e) {
      debugPrint('[ReferenceData] aliases skipped: $e');
      return const {};
    }
  }

  /// Per-locale catalogue overlay: slug -> translated fields (common_name,
  /// description, long_description, group). English is the base catalogue, so
  /// 'en' has no overlay. Accepts either `{ "species": { slug: {...} } }` or a
  /// flat `{ slug: {...} }`. Missing or unreadable files just mean no overrides.
  Future<Map<String, Map<String, dynamic>>> _loadOverlay(String code) async {
    if (code == 'en') return const {};
    try {
      final decoded = await _decode(_overlayAsset(code));
      final raw = (decoded is Map && decoded['species'] is Map)
          ? decoded['species'] as Map
          : (decoded is Map ? decoded : const {});
      final out = <String, Map<String, dynamic>>{};
      raw.forEach((k, v) {
        if (k is String && v is Map) out[k] = Map<String, dynamic>.from(v);
      });
      return out;
    } catch (e) {
      debugPrint('[ReferenceData] overlay "$code" skipped: $e');
      return const {};
    }
  }

  Future<List<Species>> _loadCatalog() async {
    final List list;
    try {
      final decoded = await _decode(_catalogAsset);
      list = decoded is List
          ? decoded
          : (decoded is Map && decoded['species'] is List
              ? decoded['species'] as List
              : const []);
    } catch (e) {
      debugPrint('[ReferenceData] catalog unreadable: $e');
      return const [];
    }

    final out = <Species>[];
    final seenIds = <String>{};
    var skipped = 0;
    for (final e in list) {
      if (e is! Map) {
        skipped++;
        continue;
      }
      try {
        final s = Species.fromJson(Map<String, dynamic>.from(e));
        if (!seenIds.add(s.id)) {
          debugPrint('[ReferenceData] duplicate species id "${s.id}" ignored');
          continue;
        }
        out.add(s);
      } catch (_) {
        skipped++;
      }
    }
    if (skipped > 0) {
      debugPrint('[ReferenceData] catalog: skipped $skipped invalid entr(ies)');
    }
    return out;
  }

  Future<List<Zoo>> _loadZoos() async {
    final List list;
    try {
      final decoded = await _decode(_zoosAsset);
      list = decoded is List
          ? decoded
          : (decoded is Map && decoded['zoos'] is List
              ? decoded['zoos'] as List
              : const []);
    } catch (e) {
      debugPrint('[ReferenceData] zoos unreadable: $e');
      return const [];
    }

    final out = <Zoo>[];
    for (final e in list) {
      if (e is! Map) continue;
      try {
        final z = Zoo.fromJson(Map<String, dynamic>.from(e));
        if (z.id.isEmpty) continue;
        out.add(z);
      } catch (_) {}
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// Build a [ZooInventory] for [zooId]. Item `species_id` values may be opaque
  /// ids, slugs, or aliased old ids — all resolve to the canonical species.
  /// Unresolvable ids are skipped and logged (never thrown). Supports `items`
  /// (preferred), `species` (full objects) and `species_ids` shapes.
  Future<ZooInventory> loadZooInventory(String zooId) async {
    final cached = _inventoryCache[zooId];
    if (cached != null) return cached;
    if (!_initialised) await init();

    final zoo = zooById(zooId) ?? Zoo(id: zooId, name: zooId);

    final dynamic decoded;
    try {
      decoded = await _decode(_inventoryAsset(zooId));
    } catch (e) {
      debugPrint('[ReferenceData] inventory "$zooId" unreadable: $e');
      return _cache(zooId, ZooInventory(zoo: zoo, species: const []));
    }

    final invMap =
        decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};

    final sv = invMap['schema_version'];
    if (sv is int && sv > supportedSchemaVersion) {
      debugPrint(
        '[ReferenceData] inventory "$zooId" schema_version $sv > '
        'supported $supportedSchemaVersion; loading leniently',
      );
    }

    final species = <Species>[];
    final items = invMap['items'];
    final fullSpecies = invMap['species'];
    final speciesIds = invMap['species_ids'];

    if (items is List) {
      var skipped = 0;
      for (final it in items) {
        if (it is! Map) {
          skipped++;
          continue;
        }
        final rawId = it['species_id'];
        if (rawId is! String || rawId.isEmpty) {
          skipped++;
          continue;
        }
        final base = speciesById(rawId); // resolves slug / alias / id
        if (base == null) {
          debugPrint('[ReferenceData] "$zooId": unknown species_id "$rawId" skipped');
          skipped++;
          continue;
        }
        final zoneRaw = it['zone'];
        final zone = (zoneRaw is String && zoneRaw.trim().isNotEmpty)
            ? zoneRaw.trim()
            : base.zone;
        final descRaw = it['description'];
        final zooDesc = (descRaw is String && descRaw.trim().isNotEmpty)
            ? descRaw.trim()
            : '';
        species.add(base.copyWith(zone: zone, zooDescription: zooDesc));
      }
      if (skipped > 0) {
        debugPrint('[ReferenceData] "$zooId": skipped $skipped inventory item(s)');
      }
    } else if (fullSpecies is List) {
      for (final m in fullSpecies) {
        if (m is! Map) continue;
        try {
          species.add(Species.fromJson(Map<String, dynamic>.from(m)));
        } catch (_) {}
      }
    } else if (speciesIds is List) {
      for (final sid in speciesIds) {
        if (sid is! String) continue;
        final s = speciesById(sid);
        if (s != null) species.add(s);
      }
    }

    species.sort((a, b) => a.commonName.compareTo(b.commonName));
    return _cache(zooId, ZooInventory(zoo: zoo, species: species));
  }

  ZooInventory _cache(String zooId, ZooInventory inv) {
    _inventoryCache[zooId] = inv;
    return inv;
  }

  // ---------------------------------------------------------------------------
  // Async convenience accessors.
  // ---------------------------------------------------------------------------

  Future<List<Zoo>> loadZoos() async {
    if (!_initialised) await init();
    return _zoos;
  }

  Future<List<Species>> loadSpeciesCatalog() async {
    if (!_initialised) await init();
    return _byId.values.toList(growable: false);
  }
}
