/// The Linnaean ranks, in order from broadest to narrowest. Declared in order,
/// so `TaxonRank.values` is the rank order — used by taxonomy filtering and by
/// building a tree of logged species.
enum TaxonRank {
  kingdom('Kingdom'),
  phylum('Phylum'),
  taxClass('Class'),
  order('Order'),
  family('Family'),
  genus('Genus'),
  species('Species');

  const TaxonRank(this.label);

  /// Human-readable label for UI (e.g. "Class").
  final String label;
}

/// Taxonomic classification for a species.
///
/// `class` is a reserved word in Dart, so the field is named [className] while
/// the JSON key stays `"class"`.
class Taxonomy {
  final String? kingdom;
  final String? phylum;
  final String? className;
  final String? order;
  final String? family;
  final String? genus;
  final String? species;

  /// Trinomial epithet for a subspecies (e.g. "sumatrae"). Not a [TaxonRank];
  /// it's display metadata and deliberately excluded from lineage/tree grouping.
  final String? subspecies;

  const Taxonomy({
    this.kingdom,
    this.phylum,
    this.className,
    this.order,
    this.family,
    this.genus,
    this.species,
    this.subspecies,
  });

  static const Taxonomy empty = Taxonomy();

  factory Taxonomy.fromJson(Map<String, dynamic> json) => Taxonomy(
        kingdom: json['kingdom'] as String?,
        phylum: json['phylum'] as String?,
        className: json['class'] as String?,
        order: json['order'] as String?,
        family: json['family'] as String?,
        genus: json['genus'] as String?,
        species: json['species'] as String?,
        subspecies: json['subspecies'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (kingdom != null) 'kingdom': kingdom,
        if (phylum != null) 'phylum': phylum,
        if (className != null) 'class': className,
        if (order != null) 'order': order,
        if (family != null) 'family': family,
        if (genus != null) 'genus': genus,
        if (species != null) 'species': species,
        if (subspecies != null) 'subspecies': subspecies,
      };

  /// The value at a given rank (or null if absent).
  String? valueFor(TaxonRank rank) {
    switch (rank) {
      case TaxonRank.kingdom:
        return kingdom;
      case TaxonRank.phylum:
        return phylum;
      case TaxonRank.taxClass:
        return className;
      case TaxonRank.order:
        return order;
      case TaxonRank.family:
        return family;
      case TaxonRank.genus:
        return genus;
      case TaxonRank.species:
        return species;
    }
  }

  /// The filled ranks from kingdom downward — i.e. this species' path through
  /// the tree of life. Handy both for grouping (a tree node per step) and for
  /// filtering (match a value at any rank).
  List<({TaxonRank rank, String value})> get lineage => [
        for (final r in TaxonRank.values)
          if ((valueFor(r) ?? '').trim().isNotEmpty)
            (rank: r, value: valueFor(r)!.trim()),
      ];
}

class Species {
  /// Opaque, permanent, rename-proof key. User observations store this.
  final String id;

  /// Human-readable handle (e.g. "elephas_maximus"). A *non-identity* attribute:
  /// convenient for inventories/debugging/URLs, and may change — never key on it.
  final String slug;

  final String commonName;
  final String scientificName;
  final String group;

  /// Which area of the zoo this species is in (e.g. "Aquarium"). This belongs to
  /// the zoo's inventory rather than the species itself, so the catalog leaves it
  /// blank and the inventory loader fills it in per zoo.
  final String zone;

  /// Short default blurb (a couple of sentences) shown at the top of the species
  /// page. On a zoo's page this is overridden by [zooDescription] when set.
  final String description;

  /// Long, detailed write-up shown under the range map on the Species-tab page.
  /// Defaults to empty until authored.
  final String longDescription;

  /// Per-zoo description, filled by the inventory loader from the zoo's inventory
  /// item (e.g. "…find these near the South Entrance"). Empty on the catalog
  /// species; only set on the per-zoo copy. Shown on that zoo's species page.
  final String zooDescription;

  /// IUCN Red List category: EX, EW, CR, EN, VU, NT, LC, DD, NE, NA, or ''.
  final String iucnStatus;

  /// "species" (default), "subspecies", or "breed". A subspecies/breed rolls up
  /// to its [parentId] in the Species tab and appears as a chip on its parent's
  /// page.
  final String rank;

  /// For a subspecies/breed, the parent species (authored as a slug, resolved to
  /// an opaque id at load). Empty for a top-level species.
  final String parentId;

  /// True for domesticated species and their breeds. Drives the "no range —
  /// domestic animal" range map (a domestic animal has no natural wild range).
  final bool domestic;

  /// Reserved: asset path for a range map, resolved later like images. Empty for
  /// now — the range-map pipeline comes later.
  final String rangeMap;

  /// Copyright/attribution for this species' photo, shown at the bottom of the
  /// species page and under the full-screen image. Empty when unknown.
  final String imageCredit;

  final Taxonomy taxonomy;

  const Species({
    required this.id,
    this.slug = '',
    this.commonName = '',
    this.scientificName = '',
    this.group = '',
    this.zone = '',
    this.description = '',
    this.longDescription = '',
    this.zooDescription = '',
    this.iucnStatus = '',
    this.rank = 'species',
    this.parentId = '',
    this.domestic = false,
    this.rangeMap = '',
    this.imageCredit = '',
    this.taxonomy = Taxonomy.empty,
  });

  bool get isSubspecies => rank == 'subspecies';
  bool get isBreed => rank == 'breed';
  bool get hasParent => parentId.isNotEmpty;

  /// Throws [FormatException] only when there is no usable `id`; the loader
  /// catches that and skips the row rather than failing the whole dataset.
  factory Species.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('species entry is missing a string "id"');
    }

    String? str(dynamic v) => v is String ? v : null;

    final iucn = str(json['iucn_status']) ?? str(json['IUCN status']) ?? '';
    final tax = json['taxonomy'];

    return Species(
      id: id,
      slug: (str(json['slug']) ?? '').trim(),
      commonName: (str(json['common_name']) ?? '').trim(),
      scientificName: (str(json['scientific_name']) ?? '').trim(),
      group: (str(json['group']) ?? '').trim(),
      zone: (str(json['zone']) ?? '').trim(),
      description: str(json['description']) ?? '',
      longDescription: str(json['long_description']) ?? '',
      iucnStatus: iucn.trim(),
      rank: (str(json['rank']) ?? 'species').trim().isEmpty
          ? 'species'
          : (str(json['rank']) ?? 'species').trim(),
      parentId: (str(json['parent_id']) ?? '').trim(),
      domestic: json['domestic'] == true,
      rangeMap: (str(json['range_map']) ?? '').trim(),
      imageCredit: (str(json['image_credit']) ?? '').trim(),
      taxonomy: tax is Map
          ? Taxonomy.fromJson(Map<String, dynamic>.from(tax))
          : Taxonomy.empty,
    );
  }

  /// Canonical order of the six high-level groups, for filter menus.
  static const List<String> majorGroups = [
    'Mammals', 'Birds', 'Reptiles', 'Amphibians', 'Fish', 'Invertebrates',
  ];

  /// One of [majorGroups] (or 'Other' when taxonomy is missing), derived from
  /// the taxonomic class/phylum. Prefer this over [group] (the fine-grained
  /// "type" like "big cats") for grouping, filtering and search.
  String get majorGroup {
    final c = (taxonomy.className ?? '').trim();
    final p = (taxonomy.phylum ?? '').trim();
    const reptiles = {
      'Reptilia', 'Squamata', 'Testudines', 'Crocodylia',
      'Sphenodontia', 'Rhynchocephalia', 'Lepidosauria', 'Archosauria',
    };
    const fish = {
      'Actinopterygii', 'Actinopteri', 'Chondrichthyes', 'Elasmobranchii',
      'Holocephali', 'Sarcopterygii', 'Dipnoi', 'Coelacanthimorpha',
      'Cephalaspidomorphi', 'Myxini', 'Petromyzontida', 'Agnatha',
      'Cladistia', 'Chondrostei',
    };
    if (p == 'Chordata') {
      if (c == 'Mammalia') return 'Mammals';
      if (c == 'Aves') return 'Birds';
      if (c == 'Amphibia') return 'Amphibians';
      if (reptiles.contains(c)) return 'Reptiles';
      if (fish.contains(c)) return 'Fish';
      return 'Other';
    }
    if (p.isNotEmpty && p != '-') return 'Invertebrates';
    return 'Other';
  }

  Species copyWith({
    String? zone,
    String? zooDescription,
    String? commonName,
    String? description,
    String? longDescription,
    String? group,
  }) =>
      Species(
        id: id,
        slug: slug,
        commonName: commonName ?? this.commonName,
        scientificName: scientificName,
        group: group ?? this.group,
        zone: zone ?? this.zone,
        description: description ?? this.description,
        longDescription: longDescription ?? this.longDescription,
        zooDescription: zooDescription ?? this.zooDescription,
        iucnStatus: iucnStatus,
        rank: rank,
        parentId: parentId,
        domestic: domestic,
        rangeMap: rangeMap,
        imageCredit: imageCredit,
        taxonomy: taxonomy,
      );

  /// Return a copy with translatable fields overridden from a per-locale overlay
  /// entry (see assets/data/i18n/<locale>/species.json). Only non-empty values
  /// override; anything missing keeps the English text, so a partial translation
  /// falls back field by field. Scientific name is never translated.
  Species localized(Map<String, dynamic>? tr) {
    if (tr == null || tr.isEmpty) return this;
    String? pick(String key) {
      final v = tr[key];
      return (v is String && v.trim().isNotEmpty) ? v.trim() : null;
    }

    return copyWith(
      commonName: pick('common_name'),
      description: pick('description'),
      longDescription: pick('long_description'),
      group: pick('group'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (slug.isNotEmpty) 'slug': slug,
        'common_name': commonName,
        'scientific_name': scientificName,
        'group': group,
        if (zone.isNotEmpty) 'zone': zone,
        'description': description,
        if (longDescription.isNotEmpty) 'long_description': longDescription,
        'iucn_status': iucnStatus,
        if (rank != 'species') 'rank': rank,
        if (parentId.isNotEmpty) 'parent_id': parentId,
        if (domestic) 'domestic': true,
        if (rangeMap.isNotEmpty) 'range_map': rangeMap,
        if (imageCredit.isNotEmpty) 'image_credit': imageCredit,
        'taxonomy': taxonomy.toJson(),
      };
}
