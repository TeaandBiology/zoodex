import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../l10n/app_localizations.dart';
import '../data/reference_data.dart';
import '../data/visit_store.dart';
import '../models/dex_entry.dart';
import '../models/species.dart';
import '../util/date_format.dart';
import '../widgets/count_badge.dart';
import '../widgets/iucn_tag.dart';
import '../widgets/species_image.dart';
import 'species_detail_screen.dart';
import 'tree_view.dart';

enum _SortField {
  taxonomy('Taxonomy'),
  firstObserved('First observed'),
  alphaCommon('Alphabetical (common name)'),
  alphaScientific('Alphabetical (scientific name)'),
  totalSeen('Total number seen'),
  iucn('IUCN status');

  const _SortField(this.label);
  final String label;
}

/// Localised label for a sort field (the enum's [label] stays English as a
/// stable fallback / for any non-UI use).
String _sortFieldLabel(BuildContext context, _SortField f) {
  final l = AppLocalizations.of(context);
  switch (f) {
    case _SortField.taxonomy:
      return l.zoodexSortTaxonomy;
    case _SortField.firstObserved:
      return l.zoodexSortFirstObserved;
    case _SortField.alphaCommon:
      return l.zoodexSortAlphaCommon;
    case _SortField.alphaScientific:
      return l.zoodexSortAlphaScientific;
    case _SortField.totalSeen:
      return l.zoodexSortTotalSeen;
    case _SortField.iucn:
      return l.zoodexSortIucn;
  }
}

typedef _Row = ({Species species, DexEntry dex});

enum _ViewMode { list, grid, tree }

class ZooDexScreen extends StatefulWidget {
  const ZooDexScreen({super.key});

  @override
  State<ZooDexScreen> createState() => _ZooDexScreenState();
}

class _ZooDexScreenState extends State<ZooDexScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _ViewMode _view = _ViewMode.list;
  String? _groupFilter; // null = all groups
  String? _iucnFilter; // null = all statuses
  _SortField _sort = _SortField.firstObserved;
  bool _asc = false; // false = descending

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// All logged species (unfiltered, unsorted).
  List<_Row> _allRows() {
    final ref = ReferenceData.instance;
    final rows = <_Row>[];
    for (final e in VisitStore.buildDex(rollUp: true)) {
      final s = ref.speciesById(e.speciesId);
      if (s == null) continue; // species no longer in catalog
      rows.add((species: s, dex: e));
    }
    return rows;
  }

  String _zoosLabel(DexEntry e) {
    final ref = ReferenceData.instance;
    final names = e.zoosSeenAt.map((id) => ref.zooById(id)?.name ?? id).toList()
      ..sort();
    return names.join(', ');
  }

  // Full taxonomic path (kingdom -> species) as a sortable key.
  String _taxonKey(Species s) => TaxonRank.values
      .map((r) => (s.taxonomy.valueFor(r) ?? '').toLowerCase())
      .join('\u0001');

  int _compare(_Row a, _Row b) {
    int cmp;
    switch (_sort) {
      case _SortField.taxonomy:
        cmp = _taxonKey(a.species).compareTo(_taxonKey(b.species));
      case _SortField.firstObserved:
        final da = a.dex.firstSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.dex.firstSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        cmp = da.compareTo(db);
      case _SortField.alphaCommon:
        cmp = a.species.commonName
            .toLowerCase()
            .compareTo(b.species.commonName.toLowerCase());
      case _SortField.alphaScientific:
        cmp = a.species.scientificName
            .toLowerCase()
            .compareTo(b.species.scientificName.toLowerCase());
      case _SortField.totalSeen:
        cmp = a.dex.visitsSeenCount.compareTo(b.dex.visitsSeenCount);
      case _SortField.iucn:
        // Higher rank = rarer; with descending (default) the rarest sort first.
        cmp = iucnRarityRank(a.species.iucnStatus)
            .compareTo(iucnRarityRank(b.species.iucnStatus));
    }
    // Stable tiebreak so equal keys keep a predictable order.
    if (cmp == 0) {
      cmp = a.species.commonName
          .toLowerCase()
          .compareTo(b.species.commonName.toLowerCase());
    }
    return _asc ? cmp : -cmp;
  }

  void _openDetail(_Row r) {
    final e = r.dex;
    final zooId =
        e.lastZooId ?? (e.zoosSeenAt.isNotEmpty ? e.zoosSeenAt.first : '');
    final zooName = ReferenceData.instance.zooById(zooId)?.name;
    Navigator.of(context).pushNamed(
      '/detail',
      arguments: SpeciesDetailArgs(
        zooId: zooId,
        zooName: zooName,
        species: r.species,
        interactive: false,
      ),
    );
  }

  void _openFilterSheet(List<_Row> all, List<String> groupOptions) {
    final iucnOptions = <String>{
      for (final r in all)
        if (r.species.iucnStatus.trim().isNotEmpty) r.species.iucnStatus.trim(),
    }.toList()
      ..sort((a, b) => iucnRarityRank(b).compareTo(iucnRarityRank(a)));

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            void apply(VoidCallback fn) {
              setState(fn);
              setSheet(() {});
            }

            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(AppLocalizations.of(sheetContext).zoodexFilter,
                              style:
                                  Theme.of(sheetContext).textTheme.titleMedium),
                          if (_groupFilter != null || _iucnFilter != null)
                            TextButton(
                              onPressed: () => apply(() {
                                _groupFilter = null;
                                _iucnFilter = null;
                              }),
                              child: Text(
                                  AppLocalizations.of(sheetContext)
                                      .zoodexClearAll),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(AppLocalizations.of(sheetContext).zoodexGroup,
                          style: Theme.of(sheetContext).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(
                                AppLocalizations.of(sheetContext).commonAll),
                            selected: _groupFilter == null,
                            onSelected: (_) => apply(() => _groupFilter = null),
                          ),
                          for (final g in groupOptions)
                            ChoiceChip(
                              label: Text(g),
                              selected: _groupFilter == g,
                              onSelected: (_) => apply(() =>
                                  _groupFilter = _groupFilter == g ? null : g),
                            ),
                        ],
                      ),
                      if (iucnOptions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(AppLocalizations.of(sheetContext).zoodexIucnStatus,
                            style: Theme.of(sheetContext).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text(
                                  AppLocalizations.of(sheetContext).commonAll),
                              selected: _iucnFilter == null,
                              onSelected: (_) =>
                                  apply(() => _iucnFilter = null),
                            ),
                            for (final code in iucnOptions)
                              ChoiceChip(
                                label: Text(code),
                                selected: _iucnFilter == code,
                                onSelected: (_) => apply(() => _iucnFilter =
                                    _iucnFilter == code ? null : code),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            void apply(VoidCallback fn) {
              setState(fn);
              setSheet(() {});
            }

            return SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(AppLocalizations.of(sheetContext).zoodexSortBy,
                        style: Theme.of(sheetContext).textTheme.titleMedium),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                            value: true,
                            label: Text(AppLocalizations.of(sheetContext)
                                .zoodexAscending)),
                        ButtonSegment(
                            value: false,
                            label: Text(AppLocalizations.of(sheetContext)
                                .zoodexDescending)),
                      ],
                      selected: {_asc},
                      onSelectionChanged: (s) => apply(() => _asc = s.first),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final f in _SortField.values)
                    ListTile(
                      title: Text(_sortFieldLabel(context, f)),
                      selected: _sort == f,
                      trailing: _sort == f
                          ? Icon(_asc
                              ? Icons.arrow_upward
                              : Icons.arrow_downward)
                          : null,
                      onTap: () => apply(() => _sort = f),
                    ),
                  const SizedBox(height: 8),
                ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: VisitStore.listenable(),
      builder: (context, _, __) {
        final all = _allRows();

        // Groups present among logged species, in canonical order.
        final present = <String>{for (final r in all) r.species.majorGroup};
        final groupOptions = [
          ...Species.majorGroups.where(present.contains),
          ...present.where((g) => !Species.majorGroups.contains(g)).toList()
            ..sort(),
        ];

        final q = _query.trim().toLowerCase();
        var rows = all.where((r) {
          if (_groupFilter != null && r.species.majorGroup != _groupFilter) {
            return false;
          }
          if (_iucnFilter != null &&
              r.species.iucnStatus.trim() != _iucnFilter) {
            return false;
          }
          if (q.isEmpty) return true;
          return r.species.commonName.toLowerCase().contains(q) ||
              r.species.scientificName.toLowerCase().contains(q) ||
              r.species.majorGroup.toLowerCase().contains(q) ||
              _zoosLabel(r.dex).toLowerCase().contains(q);
        }).toList()
          ..sort(_compare);

        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context).zoodexTitle(rows.length)),
            actions: [
              IconButton(
                tooltip: AppLocalizations.of(context).zoodexListView,
                color: _view == _ViewMode.list
                    ? Theme.of(context).colorScheme.primary
                    : null,
                icon: const Icon(Icons.view_list),
                onPressed: () => setState(() => _view = _ViewMode.list),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).zoodexGridView,
                color: _view == _ViewMode.grid
                    ? Theme.of(context).colorScheme.primary
                    : null,
                icon: const Icon(Icons.grid_view),
                onPressed: () => setState(() => _view = _ViewMode.grid),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).zoodexTreeOfLife,
                color: _view == _ViewMode.tree
                    ? Theme.of(context).colorScheme.primary
                    : null,
                icon: const Icon(Icons.account_tree),
                onPressed: () => setState(() => _view = _ViewMode.tree),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).zoodexFilter,
                color: (_groupFilter != null || _iucnFilter != null)
                    ? Theme.of(context).colorScheme.primary
                    : null,
                icon: Icon((_groupFilter != null || _iucnFilter != null)
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined),
                onPressed: () => _openFilterSheet(all, groupOptions),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).zoodexSort,
                icon: const Icon(Icons.sort),
                onPressed: _openSortSheet,
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: AppLocalizations.of(context).zoodexSearchHint,
                    border: const OutlineInputBorder(),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: AppLocalizations.of(context).zoodexClear,
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              _query = '';
                              _searchController.clear();
                            }),
                          ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(all.isEmpty
                            ? AppLocalizations.of(context).zoodexNoSightingsYet
                            : AppLocalizations.of(context).zoodexNoMatches))
                    : switch (_view) {
                        _ViewMode.list => _buildList(rows),
                        _ViewMode.grid => _buildGrid(rows),
                        _ViewMode.tree => TaxonomyTreeView(
                            species: [for (final r in rows) r.species],
                            onOpenSpecies: (sp) {
                              final m = rows
                                  .where((r) => r.species.id == sp.id);
                              if (m.isNotEmpty) _openDetail(m.first);
                            },
                          ),
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(List<_Row> rows) {
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = rows[i];
        final e = r.dex;
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  r.species.commonName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (e.everVerified)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.verified, size: 18),
                ),
              CountBadge(count: e.visitsSeenCount),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.species.scientificName} • ${r.species.majorGroup}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Pill(text: _zoosLabel(e)),
                    if (e.lastSeenAt != null)
                      Text(
                        AppLocalizations.of(context)
                            .zoodexLastSeen(formatLocalDate(e.lastSeenAt!)),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openDetail(r),
        );
      },
    );
  }

  Widget _buildGrid(List<_Row> rows) {
    const cross = 3;
    const radius = Radius.circular(12);
    final n = rows.length;
    final numRows = (n + cross - 1) ~/ cross;
    final lastRowStart = (numRows - 1) * cross;
    final lastRowFull = n % cross == 0;
    final firstRowLast = n < cross ? n - 1 : cross - 1;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      // A very thin gap between images; only the block's outer corners round.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 1, // square cells
      ),
      itemCount: n,
      itemBuilder: (context, i) {
        final r = rows[i];
        // Round only the four outer corners of the whole grid. The bottom-right
        // is rounded only when the last row is full (otherwise it's ragged, so
        // just the bottom-left of the last row is rounded).
        final border = BorderRadius.only(
          topLeft: i == 0 ? radius : Radius.zero,
          topRight: i == firstRowLast ? radius : Radius.zero,
          bottomLeft: i == lastRowStart ? radius : Radius.zero,
          bottomRight: (lastRowFull && i == n - 1) ? radius : Radius.zero,
        );
        return _SpeciesGridCell(
          species: r.species,
          onTap: () => _openDetail(r),
          borderRadius: border,
        );
      },
    );
  }
}

class _SpeciesGridCell extends StatelessWidget {
  final Species species;
  final VoidCallback onTap;
  final BorderRadius borderRadius;
  const _SpeciesGridCell({
    required this.species,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SpeciesImage(species: species),
          // Shaded bar with the common name across the bottom.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Text(
                species.commonName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap),
            ),
          ),
        ],
      ),
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
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
