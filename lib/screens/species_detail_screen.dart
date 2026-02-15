import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../data/data_loader.dart';
import '../data/seen_store.dart';
import '../models/inventory.dart';
import '../models/observation.dart';
import '../models/species.dart';
import '../widgets/chip.dart';
import '../widgets/scientific_name.dart';
import '../widgets/iucn_badge.dart';

class SpeciesDetailArgs {
  final String zooId;
  final String? zooName;
  final Species species;

  const SpeciesDetailArgs({
    required this.zooId,
    required this.species,
    this.zooName,
  });
}

class SpeciesDetailScreen extends StatefulWidget {
  final SpeciesDetailArgs args;
  const SpeciesDetailScreen({super.key, required this.args});

  @override
  State<SpeciesDetailScreen> createState() => _SpeciesDetailScreenState();
}

class _SpeciesDetailScreenState extends State<SpeciesDetailScreen> {
  late List<Observation> _history;
  late final TextEditingController _notesController;
  bool _saving = false;

  ZooInventory? _invMeta;
  List<String> _zones = const [];
  String _zooName = '';

  @override
  void initState() {
    super.initState();
    _history = SeenStore.list(widget.args.zooId, widget.args.species.id).toList()
      ..sort((a, b) => b.seenAt.compareTo(a.seenAt));
    _notesController = TextEditingController();

    // If caller passed a zooName, use it immediately (no need to block UI).
    _zooName = widget.args.zooName ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _ensureInventoryMeta() async {
    if (_invMeta != null) return;

    final inv = await DataLoader.loadZooInventory(widget.args.zooId);
    final zones = inv.species.map((s) => s.zone).toSet().toList()..sort();

    if (!mounted) return;
    setState(() {
      _invMeta = inv;
      _zones = zones;
      _zooName = _zooName.isNotEmpty ? _zooName : inv.zoo.name;
    });
  }

  Future<({DateTime when, String zone})?> _promptVisitTimeAndZone() async {
    await _ensureInventoryMeta();
    if (!mounted) return null;

    DateTime chosen = DateTime.now();

    String zone = widget.args.species.zone;
    if (_zones.isNotEmpty && !_zones.contains(zone)) zone = _zones.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('Log observation • ${_zooName.isEmpty ? widget.args.zooId : _zooName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Zone', style: Theme.of(context).textTheme.labelLarge),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: zone,
                    items: (_zones.isEmpty ? <String>[zone] : _zones)
                        .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                        .toList(),
                    onChanged: (v) => setLocal(() => zone = v ?? zone),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('When', style: Theme.of(context).textTheme.labelLarge),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: chosen,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (d == null) return;
                            setLocal(() {
                              chosen = DateTime(
                                d.year,
                                d.month,
                                d.day,
                                chosen.hour,
                                chosen.minute,
                              );
                            });
                          },
                          child: const Text('Pick date'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(chosen),
                            );
                            if (t == null) return;
                            setLocal(() {
                              chosen = DateTime(
                                chosen.year,
                                chosen.month,
                                chosen.day,
                                t.hour,
                                t.minute,
                              );
                            });
                          },
                          child: const Text('Pick time'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Selected: ${formatLocalDateTime(chosen)}'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Log'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return null;
    return (when: chosen, zone: zone);
  }

  Future<Position?> _tryGetPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      return null;
    }
  }

  String _formatRange(String raw) {
    var text = raw.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\s+\n'), '\n');
    return text.trim();
  }

  Future<void> _seenNow() async {
    setState(() => _saving = true);

    await _ensureInventoryMeta();

    final now = DateTime.now();
    Position? pos;
    try {
      pos = await _tryGetPosition();
    } catch (_) {
      pos = null;
    }

    final notes = _notesController.text.trim();
    final obs = Observation(
      seenAt: now,
      lat: pos?.latitude,
      lng: pos?.longitude,
      accuracyM: pos?.accuracy,
      notes: notes.isEmpty ? null : notes,
      zooName: _zooName.isEmpty ? null : _zooName,
      zone: widget.args.species.zone,
    );

    await SeenStore.add(widget.args.zooId, widget.args.species.id, obs);

    setState(() {
      _notesController.clear();
      _history = SeenStore.list(widget.args.zooId, widget.args.species.id).toList()
        ..sort((a, b) => b.seenAt.compareTo(a.seenAt));
      _saving = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved: Seen now')),
    );
  }

  Future<void> _logObservation() async {
    final result = await _promptVisitTimeAndZone();
    if (result == null) return;

    setState(() => _saving = true);

    Position? pos;
    try {
      pos = await _tryGetPosition();
    } catch (_) {
      pos = null;
    }

    final obs = Observation(
      seenAt: result.when,
      lat: pos?.latitude,
      lng: pos?.longitude,
      accuracyM: pos?.accuracy,
      notes: null,
      zooName: _zooName.isEmpty ? null : _zooName,
      zone: result.zone,
    );

    await SeenStore.add(widget.args.zooId, widget.args.species.id, obs);

    setState(() {
      _history = SeenStore.list(widget.args.zooId, widget.args.species.id).toList()
        ..sort((a, b) => b.seenAt.compareTo(a.seenAt));
      _saving = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged: ${formatLocalDateTime(result.when)} • ${result.zone}')),
    );
  }

  Future<void> _deleteObservation(int index) async {
    final obs = _history[index];

    await SeenStore.deleteExact(widget.args.zooId, widget.args.species.id, obs);

    setState(() {
      _history = SeenStore.list(widget.args.zooId, widget.args.species.id).toList()
        ..sort((a, b) => b.seenAt.compareTo(a.seenAt));
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Observation deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await SeenStore.add(widget.args.zooId, widget.args.species.id, obs);
            if (!mounted) return;
            setState(() {
              _history = SeenStore.list(widget.args.zooId, widget.args.species.id).toList()
                ..sort((a, b) => b.seenAt.compareTo(a.seenAt));
            });
          },
        ),
      ),
    );
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all observations?'),
        content: const Text('This will remove all saved observations for this species.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await SeenStore.clear(widget.args.zooId, widget.args.species.id);
    setState(() => _history = []);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.args.species;
    final lastSeen = _history.isEmpty ? null : _history.first.seenAt;
    final rangeText = _formatRange(s.range);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          s.commonName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              tooltip: 'Clear all observations',
              onPressed: _saving ? null : _clearAll,
              icon: const Icon(Icons.delete_forever),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScientificName(
              name: s.scientificName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                IucnBadge(code: s.iucn),
                AppChip(label: s.group),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              s.description.isEmpty ? 'No description yet.' : s.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Range',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              rangeText.isEmpty ? 'No range info yet.' : rangeText,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              _history.isEmpty
                  ? 'No observations yet'
                  : 'Observations: ${_history.length} • Last: ${formatLocalDateTime(lastSeen!)}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _seenNow,
                    icon: const Icon(Icons.check),
                    label: const Text('Seen Now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _logObservation,
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text('Log Observation'),
                  ),
                ),
              ],
            ),
            if (_saving) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _history.isEmpty
                  ? const Center(child: Text('No observations yet.'))
                  : ListView.separated(
                      itemCount: _history.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final o = _history[i];
                        final when = formatLocalDateTime(o.seenAt);
                        final loc = (o.lat != null && o.lng != null)
                            ? '${o.lat!.toStringAsFixed(5)}, ${o.lng!.toStringAsFixed(5)}'
                            : 'No GPS';
                        final acc = o.accuracyM == null ? '' : ' (±${o.accuracyM!.round()}m)';

                        final header = [
                          if (o.zooName != null && o.zooName!.isNotEmpty) o.zooName!,
                          if (o.zone != null && o.zone!.isNotEmpty) o.zone!,
                        ].join(' • ');

                        return ListTile(
                          title: Text(when),
                          subtitle: Text(
                            '${header.isEmpty ? '' : '$header\n'}$loc$acc'
                            '${o.notes == null ? '' : '\n${o.notes}'}',
                          ),
                          isThreeLine: header.isNotEmpty || o.notes != null,
                          trailing: IconButton(
                            tooltip: 'Delete this observation',
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteObservation(i),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
