import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../data/reference_data.dart';
import '../data/verification_service.dart';
import '../data/visit_store.dart';
import '../models/species.dart';
import '../models/report.dart';
import '../models/species_log.dart';
import '../models/verification.dart';
import '../models/visit.dart';
import '../util/date_format.dart';
import '../widgets/chip.dart';
import '../widgets/iucn_tag.dart';
import '../widgets/range_map.dart';
import '../widgets/report_sheet.dart';
import '../widgets/species_image.dart';

class SpeciesDetailArgs {
  final String zooId;
  final String? zooName;
  final Species species;

  /// When true (the default, used from the Zoos menu) the screen shows the full
  /// logging controls. When false (used from the Species tab) it's read-only:
  /// image, tags, description, and a list of sightings, with no way to log/edit.
  final bool interactive;

  const SpeciesDetailArgs({
    required this.zooId,
    required this.species,
    this.zooName,
    this.interactive = true,
  });
}

class SpeciesDetailScreen extends StatefulWidget {
  final SpeciesDetailArgs args;
  const SpeciesDetailScreen({super.key, required this.args});

  @override
  State<SpeciesDetailScreen> createState() => _SpeciesDetailScreenState();
}

class _SpeciesDetailScreenState extends State<SpeciesDetailScreen> {
  late final TextEditingController _notesController;
  late List<({Visit visit, SpeciesLog log})> _history;
  bool _saving = false;

  /// The species whose page this is. For a subspecies opened read-only this is
  /// the *parent*, so the page is always the rollup species with the subspecies
  /// preselected below.
  late Species _pageSpecies;

  /// Subspecies/breeds shown as chips (read-only only; empty otherwise).
  late List<Species> _children;

  /// Currently selected child, or null for the species-level ("All") view.
  Species? _selectedChild;

  /// zooId -> this species' zone (enclosure/area) at that zoo, when the zoo
  /// records one. Loaded asynchronously from each zoo's inventory.
  Map<String, String> _zoneByZoo = const {};

  bool get _interactive => widget.args.interactive;
  String get _zooId => widget.args.zooId;

  /// The entry shown in the hero/description/tags — the selected child, else the
  /// page species.
  Species get _displayed => _selectedChild ?? _pageSpecies;

  /// Species ids whose sightings the current view should include.
  List<String> _scopeIds() {
    if (_selectedChild != null) return [_selectedChild!.id];
    if (_children.isEmpty) return [_pageSpecies.id];
    return [_pageSpecies.id, ..._children.map((c) => c.id)];
  }

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();

    final passed = widget.args.species;
    final ref = ReferenceData.instance;
    final parent = ref.parentOf(passed.id);
    if (!_interactive && parent != null) {
      // Opened a subspecies from a browse surface: show the parent page with
      // this subspecies preselected.
      _pageSpecies = parent;
      _selectedChild = passed;
    } else {
      _pageSpecies = passed;
      _selectedChild = null;
    }
    _children = _interactive ? const [] : ref.childrenOf(_pageSpecies.id);

    _refresh();
    _loadZones();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _refresh() {
    final out = <({Visit visit, SpeciesLog log})>[];
    for (final id in _scopeIds()) {
      out.addAll(VisitStore.historyForSpecies(id));
    }
    out.sort((a, b) => b.log.loggedAt.compareTo(a.log.loggedAt));
    _history = out;
  }

  void _selectChild(Species? c) => setState(() {
        _selectedChild = c;
        _refresh();
      });

  /// The zoo name for a given sighting (sightings can span several zoos).
  String _zooNameFor(Visit visit) =>
      ReferenceData.instance.zooById(visit.zooId)?.name ?? visit.zooId;

  /// A zone worth showing: a real, named enclosure. Blank or the placeholder
  /// "unknown" returns '' so the tag/label is omitted entirely.
  String _displayZone(String? zone) {
    final z = (zone ?? '').trim();
    return (z.isEmpty || z.toLowerCase() == 'unknown') ? '' : z;
  }

  /// Look up this species' zone at every zoo that appears in the history, so
  /// each sighting line can show where in the zoo it lives.
  Future<void> _loadZones() async {
    final scope = _scopeIds().toSet();
    final zooIds = <String>{_zooId, ..._history.map((e) => e.visit.zooId)};
    final map = <String, String>{};
    for (final zid in zooIds) {
      if (zid.isEmpty) continue;
      try {
        final inv = await ReferenceData.instance.loadZooInventory(zid);
        for (final sp in inv.species) {
          final dz = _displayZone(sp.zone);
          if (scope.contains(sp.id) && dz.isNotEmpty) {
            map[zid] = dz;
            break;
          }
        }
      } catch (_) {
        // Ignore: a missing/unreadable inventory just means no zone to show.
      }
    }
    if (!mounted) return;
    setState(() => _zoneByZoo = map);
  }

  Future<void> _log(Outcome outcome) async {
    setState(() => _saving = true);
    final now = DateTime.now();
    final note = _notesController.text.trim();

    await VisitStore.logSpecies(
      _zooId,
      _pageSpecies.id,
      outcome: outcome,
      note: note.isEmpty ? null : note,
      when: now,
    );

    // Try to verify presence (skipped if the zoo has no coordinates yet).
    final result = await VerificationService.verifyAtZoo(_zooId);
    if (result.status == VerificationStatus.verified) {
      await VisitStore.markVerified(_zooId, now);
    }

    if (!mounted) return;
    setState(() {
      _notesController.clear();
      _refresh();
      _saving = false;
    });

    final l10n = AppLocalizations.of(context);
    final what =
        outcome == Outcome.seen ? l10n.speciesDetailSeen : l10n.speciesDetailNoShow;
    final verified = result.status == VerificationStatus.verified;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(verified
              ? l10n.speciesDetailSavedVerified(what)
              : l10n.speciesDetailSaved(what))),
    );
  }

  Future<void> _logPast() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;

    setState(() => _saving = true);
    final note = _notesController.text.trim();
    // Past sightings can't be GPS-verified, so they stay unverified.
    final when = DateTime(picked.year, picked.month, picked.day, 12);
    await VisitStore.logSpecies(
      _zooId,
      _pageSpecies.id,
      outcome: Outcome.seen,
      note: note.isEmpty ? null : note,
      when: when,
    );

    if (!mounted) return;
    setState(() {
      _notesController.clear();
      _refresh();
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context)
              .speciesDetailLoggedFor(formatLocalDate(when)))),
    );
  }

  /// Edit the private personal note that gets attached to the next log. Opened
  /// from the pencil button; kept off the main row since most users won't use it.
  Future<void> _editNote() async {
    final controller = TextEditingController(text: _notesController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).speciesDetailAddPersonalNote),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).speciesDetailNotePrivateHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(AppLocalizations.of(context).commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      setState(() => _notesController.text = result.trim());
    }
  }

  /// Add/edit the private note on an existing observation record (the pencil on
  /// each sighting row). Available on both the zoo and Species-tab pages.
  Future<void> _editLogNote(({Visit visit, SpeciesLog log}) entry) async {
    final controller = TextEditingController(text: entry.log.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).speciesDetailPersonalNote),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).speciesDetailNotePrivateHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(AppLocalizations.of(context).commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    final note = result.trim();
    await VisitStore.setNote(entry.visit.zooId, entry.log.speciesId,
        entry.visit.date, note.isEmpty ? null : note);
    if (!mounted) return;
    setState(_refresh);
  }

  /// Confirm before removing a single observation record (used on both the
  /// per-zoo logging page and the read-only Species-tab page).
  Future<void> _confirmDelete(({Visit visit, SpeciesLog log}) entry) async {
    final l10n = AppLocalizations.of(context);
    final what = entry.log.outcome == Outcome.seen
        ? l10n.speciesDetailRecordSighting
        : l10n.speciesDetailRecordNoShow;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).speciesDetailRemoveRecordTitle),
        content: Text(
          AppLocalizations.of(context).speciesDetailDeleteRecordBody(
              what,
              formatLocalDate(entry.visit.date),
              _zooNameFor(entry.visit)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).speciesDetailRemove),
          ),
        ],
      ),
    );
    if (ok == true) await _deleteLog(entry);
  }

  Future<void> _deleteLog(({Visit visit, SpeciesLog log}) entry) async {
    // Delete against the zoo this particular sighting belongs to.
    await VisitStore.removeLog(
        entry.visit.zooId, entry.log.speciesId, entry.visit.date);
    if (!mounted) return;
    setState(_refresh);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).speciesDetailRemoved),
        action: SnackBarAction(
          label: AppLocalizations.of(context).speciesDetailUndo,
          onPressed: () async {
            await VisitStore.logSpecies(
              entry.visit.zooId,
              entry.log.speciesId,
              outcome: entry.log.outcome,
              note: entry.log.note,
              when: entry.log.loggedAt,
            );
            if (!mounted) return;
            setState(_refresh);
          },
        ),
      ),
    );
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).speciesDetailClearAllTitle),
        content: Text(
          AppLocalizations.of(context).speciesDetailClearAllBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).speciesDetailClear),
          ),
        ],
      ),
    );
    if (ok != true) return;

    for (final e in List.of(_history)) {
      await VisitStore.removeLog(e.visit.zooId, e.log.speciesId, e.visit.date);
    }
    if (!mounted) return;
    setState(_refresh);
  }

  /// Short chip label: the subspecies' common name with the parent's name
  /// stripped ("Sumatran Tiger" -> "Sumatran").
  String _shortLabel(Species c) {
    final parent = _pageSpecies.commonName.toLowerCase();
    var s = c.commonName;
    if (parent.isNotEmpty && s.toLowerCase().endsWith(parent)) {
      s = s.substring(0, s.length - parent.length).trim();
    }
    return s.isEmpty ? c.commonName : s;
  }

  /// Chip row of subspecies/breeds. Unseen ones are greyed but still tappable so
  /// you can read about a subspecies you haven't collected yet.
  Widget _selector(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outline;
    final allBreeds = _children.isNotEmpty && _children.every((c) => c.isBreed);
    final heading = allBreeds
        ? AppLocalizations.of(context).speciesDetailBreeds
        : AppLocalizations.of(context).speciesDetailSubspecies;
    final seenCount = _children.where((c) => VisitStore.seenEver(c.id)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(heading, style: Theme.of(context).textTheme.titleSmall),
            Text(
                AppLocalizations.of(context)
                    .speciesDetailCollectedCount(seenCount, _children.length),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: muted)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(AppLocalizations.of(context).commonAll),
              selected: _selectedChild == null,
              onSelected: (_) => _selectChild(null),
            ),
            for (final c in _children)
              Builder(builder: (context) {
                final seen = VisitStore.seenEver(c.id);
                return ChoiceChip(
                  label: Text(_shortLabel(c)),
                  selected: _selectedChild?.id == c.id,
                  onSelected: (_) => _selectChild(c),
                  avatar: seen
                      ? null
                      : Icon(Icons.lock_outline, size: 16, color: muted),
                  labelStyle: seen ? null : TextStyle(color: muted),
                );
              }),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Hero header: the species image with the common name, scientific name and
  /// tags overlaid on a dark gradient.
  Widget _buildHero(BuildContext context, Species s) {
    return Stack(
      children: [
        SpeciesImage(species: s, height: 400),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC000000), Color(0x00000000)],
                stops: [0.0, 0.6],
              ),
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Material(
            color: const Color(0x66000000),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              tooltip: AppLocalizations.of(context).speciesDetailViewFullImage,
              icon: const Icon(Icons.zoom_in, color: Colors.white),
              onPressed: () {
                final credit = ReferenceData.instance.imageCreditFor(s);
                showFullSpeciesImage(
                  context,
                  s,
                  credit: credit.isNotEmpty ? credit : s.imageCredit,
                );
              },
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.commonName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.scientificName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (s.majorGroup.isNotEmpty) AppChip(label: s.majorGroup),
                    if (_displayZone(s.zone).isNotEmpty)
                      AppChip(label: _displayZone(s.zone)),
                    if (s.iucnStatus.isNotEmpty) IucnTag(status: s.iucnStatus),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _displayed;
    final hasSelector = _children.isNotEmpty;
    final seen = _history.where((e) => e.log.outcome == Outcome.seen).toList();
    final lastSeen = seen.isEmpty ? null : seen.first.log.loggedAt;

    // Read-only shows only sightings; interactive shows seen + no-show records.
    final shown = _interactive ? _history : seen;

    // Count line wording depends on whether we're at species or subspecies level.
    final l10n = AppLocalizations.of(context);
    final String countLine;
    if (_selectedChild == null && hasSelector) {
      countLine = seen.isEmpty
          ? l10n.speciesDetailNoneSeenYet
          : l10n.speciesDetailSeenAcrossSubspecies(
              seen.length, formatLocalDate(lastSeen!));
    } else {
      countLine = seen.isEmpty
          ? (_selectedChild != null
              ? l10n.speciesDetailNotSeenYet
              : l10n.speciesDetailNoSightingsYet)
          : l10n.speciesDetailSeenTimes(
              seen.length, formatLocalDate(lastSeen!));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Fade the bar out towards the bottom instead of a hard translucent edge.
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000000), Color(0x00000000)],
            ),
          ),
        ),
        actions: [
          // "Clear all records" lives on the read-only Species-tab page (a
          // species' whole history), not on the per-zoo logging page.
          if (!_interactive && _history.isNotEmpty)
            IconButton(
              tooltip: AppLocalizations.of(context).speciesDetailClearAllRecords,
              onPressed: _saving ? null : _clearAll,
              icon: const Icon(Icons.delete_forever),
            ),
          PopupMenuButton<ReportCategory?>(
            tooltip: AppLocalizations.of(context).speciesDetailReportProblem,
            icon: const Icon(Icons.flag_outlined),
            onSelected: (cat) => showReportSheet(
              context,
              presetCategory: cat,
              speciesId: s.id,
              speciesName: s.commonName,
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: ReportCategory.speciesImage,
                child: Text(
                    AppLocalizations.of(context).speciesDetailReportWrongPhoto),
              ),
              PopupMenuItem(
                value: ReportCategory.factual,
                child: Text(
                    AppLocalizations.of(context).speciesDetailReportFactualError),
              ),
              PopupMenuItem(
                value: ReportCategory.taxonomy,
                child: Text(
                    AppLocalizations.of(context).speciesDetailReportWrongTaxonomy),
              ),
              PopupMenuItem(
                value: null,
                child: Text(
                    AppLocalizations.of(context).speciesDetailReportProblemMenu),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHero(context, s),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasSelector) _selector(context),
                Builder(builder: (context) {
                  // Zoo page → that zoo's own description; Species tab → the
                  // species' short default blurb.
                  final top = (_interactive && s.zooDescription.trim().isNotEmpty)
                      ? s.zooDescription.trim()
                      : s.description.trim();
                  return Text(
                    top.isEmpty
                        ? AppLocalizations.of(context).speciesDetailNoDescription
                        : top,
                    style: Theme.of(context).textTheme.bodyLarge,
                  );
                }),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(countLine, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),

                // Logging controls — only when opened from the Zoos menu.
                if (_interactive) ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : () => _log(Outcome.seen),
                          icon: const Icon(Icons.check),
                          label: Text(
                              AppLocalizations.of(context).speciesDetailSeenNow),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : () => _log(Outcome.noShow),
                          icon: const Icon(Icons.visibility_off_outlined),
                          label: Text(
                              AppLocalizations.of(context).speciesDetailNoShow),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Personal note is tucked behind this button — most users
                      // won't add one. Filled when a note is attached.
                      if (_notesController.text.trim().isNotEmpty)
                        IconButton.filled(
                          tooltip: AppLocalizations.of(context)
                              .speciesDetailEditPersonalNote,
                          icon: const Icon(Icons.edit_note),
                          onPressed: _saving ? null : _editNote,
                        )
                      else
                        IconButton.filledTonal(
                          tooltip: AppLocalizations.of(context)
                              .speciesDetailAddPersonalNoteTooltip,
                          icon: const Icon(Icons.edit_note),
                          onPressed: _saving ? null : _editNote,
                        ),
                    ],
                  ),
                  // Once a note is entered, show it under the buttons so the user
                  // can confirm it before logging. Tap to edit.
                  if (_notesController.text.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: InkWell(
                        onTap: _saving ? null : _editNote,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.sticky_note_2_outlined,
                                  size: 18,
                                  color:
                                      Theme.of(context).colorScheme.outline),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _notesController.text.trim(),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _saving ? null : _logPast,
                      icon: const Icon(Icons.edit_calendar),
                      label: Text(
                          AppLocalizations.of(context).speciesDetailLogPastSighting),
                    ),
                  ),
                  if (_saving) const LinearProgressIndicator(),
                  const SizedBox(height: 4),
                ],

                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: Text(AppLocalizations.of(context)
                            .speciesDetailNoSightingsYetPeriod)),
                  )
                else
                  for (int i = 0; i < shown.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _sightingTile(shown[i]),
                  ],

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                _rangeSection(context, s),
                // Long, detailed write-up — Species-tab page only.
                if (!_interactive && s.longDescription.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context).speciesDetailAbout,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(s.longDescription.trim(),
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 16),
                _taxonomyLine(context, s),
                const SizedBox(height: 12),
                _copyrightLine(context, s),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Range-map block: a tap-to-enlarge map for the displayed species/subspecies.
  /// A subspecies with no map of its own falls back to the parent species range;
  /// domestic animals show the shared "no natural range" map.
  Widget _rangeSection(BuildContext context, Species s) {
    final muted = Theme.of(context).colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context).speciesDetailRange,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => showFullRangeMap(context, s),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 200,
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: RangeMap(species: s, height: 200),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(AppLocalizations.of(context).speciesDetailTapToEnlarge,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
      ],
    );
  }

  /// Full taxonomic lineage, e.g. "Animalia › Chordata › Mammalia › … › tigris".
  Widget _taxonomyLine(BuildContext context, Species s) {
    final parts = [for (final step in s.taxonomy.lineage) step.value];
    final declared = s.taxonomy.subspecies?.trim() ?? '';
    final sci = s.scientificName.trim().split(RegExp(r'\s+'));
    final sub = declared.isNotEmpty
        ? declared
        : (sci.length == 3 ? sci.last : '');
    if (sub.isNotEmpty) parts.add(sub);
    final muted = Theme.of(context).colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context).speciesDetailTaxonomy,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          parts.isEmpty
              ? AppLocalizations.of(context).speciesDetailNotRecorded
              : parts.join(' › '),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }

  /// Small grey image-copyright line, from the bundled credits (falling back to
  /// the species' own field).
  Widget _copyrightLine(BuildContext context, Species s) {
    final credit = ReferenceData.instance.imageCreditFor(s);
    final text = credit.isNotEmpty
        ? credit
        : (s.imageCredit.isNotEmpty
            ? s.imageCredit
            : AppLocalizations.of(context).speciesDetailNotAvailable);
    return Text(
      AppLocalizations.of(context).speciesDetailCopyrightInfo(text),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
            fontSize: 11,
          ),
    );
  }

  Widget _sightingTile(({Visit visit, SpeciesLog log}) e) {
    final isSeen = e.log.outcome == Outcome.seen;
    final verified = e.visit.verified == VerificationStatus.verified;
    final zone = _zoneByZoo[e.visit.zooId];
    // When viewing "All" on a rollup page, label each sighting with which
    // subspecies it was.
    final showSub = _selectedChild == null && _children.isNotEmpty;
    final subName = showSub
        ? ReferenceData.instance.speciesById(e.log.speciesId)?.commonName
        : null;
    final zooLabel = (zone != null && zone.isNotEmpty)
        ? '${_zooNameFor(e.visit)} - $zone'
        : _zooNameFor(e.visit);
    final l10n = AppLocalizations.of(context);
    final lines = <String>[
      if (subName != null && subName != _pageSpecies.commonName) subName,
      zooLabel,
      if (verified) l10n.speciesDetailVerified,
      if (e.log.note != null && e.log.note!.isNotEmpty) e.log.note!,
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isSeen ? Icons.check_circle : Icons.remove_circle_outline,
        color: isSeen
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Text(
        l10n.speciesDetailSightingTitle(formatLocalDate(e.visit.date),
            isSeen ? l10n.speciesDetailSeen : l10n.speciesDetailNoShow),
      ),
      subtitle: lines.isEmpty ? null : Text(lines.join('\n')),
      isThreeLine: lines.length > 1,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: (e.log.note?.isNotEmpty ?? false)
                ? l10n.speciesDetailEditNote
                : l10n.speciesDetailAddNote,
            icon: const Icon(Icons.edit),
            visualDensity: VisualDensity.compact,
            onPressed: () => _editLogNote(e),
          ),
          IconButton(
            tooltip: l10n.speciesDetailRemoveThisRecord,
            icon: const Icon(Icons.close),
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmDelete(e),
          ),
        ],
      ),
    );
  }
}
