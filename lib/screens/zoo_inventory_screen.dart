import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/reference_data.dart';
import '../data/visit_store.dart';
import '../models/inventory.dart';
import '../models/report.dart';
import '../models/species.dart';
import '../widgets/error_view.dart';
import '../widgets/report_sheet.dart';
import '../widgets/zoo_image.dart';
import 'species_detail_screen.dart';
import 'zoo_info_screen.dart';

class ZooInventoryArgs {
  final String zooId;
  final String assetPath;
  const ZooInventoryArgs({required this.zooId, required this.assetPath});
}

class ZooInventoryScreen extends StatefulWidget {
  final ZooInventoryArgs args;
  const ZooInventoryScreen({super.key, required this.args});

  @override
  State<ZooInventoryScreen> createState() => _ZooInventoryScreenState();
}

class _ZooInventoryScreenState extends State<ZooInventoryScreen> {
  late final Future<ZooInventory> _invFuture;
  String _query = '';
  String? _groupFilter;

  @override
  void initState() {
    super.initState();
    _invFuture = ReferenceData.instance.loadZooInventory(widget.args.zooId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ZooInventory>(
      future: _invFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: ErrorView(error: snapshot.error));
        }
        final inv = snapshot.data;
        if (inv == null) {
          return const Scaffold(body: Center(child: Text('No data.')));
        }

        final total = inv.species.length;
        final present = inv.species.map((s) => s.majorGroup).toSet();
        final groups = [
          ...Species.majorGroups.where(present.contains),
          ...present.where((g) => !Species.majorGroups.contains(g)).toList()
            ..sort(),
        ];

        final q = _query.trim().toLowerCase();
        final filtered = inv.species.where((s) {
          final matchesGroup =
              _groupFilter == null || s.majorGroup == _groupFilter;
          if (!matchesGroup) return false;
          if (q.isEmpty) return true;
          return s.commonName.toLowerCase().contains(q) ||
              s.scientificName.toLowerCase().contains(q) ||
              s.majorGroup.toLowerCase().contains(q) ||
              s.zone.toLowerCase().contains(q);
        }).toList()
          ..sort((a, b) => a.commonName.compareTo(b.commonName));

        return Scaffold(
          appBar: AppBar(
            title: ValueListenableBuilder<Box>(
              valueListenable: VisitStore.listenable(),
              builder: (context, _, __) {
                final seen = VisitStore.seenSpeciesCountAtZoo(inv.zoo.id);
                return Text('${inv.zoo.name} ($seen/$total)');
              },
            ),
            actions: [
              IconButton(
                tooltip: 'Zoo info',
                icon: const Icon(Icons.info_outline),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ZooInfoScreen(zoo: inv.zoo),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (choice) {
                  if (choice == 'missing') {
                    showReportSheet(
                      context,
                      title: 'Report a missing species',
                      presetCategory: ReportCategory.missingSpecies,
                      lockCategory: true,
                      zooId: inv.zoo.id,
                      zooName: inv.zoo.name,
                    );
                  } else {
                    showReportSheet(
                      context,
                      zooId: inv.zoo.id,
                      zooName: inv.zoo.name,
                    );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'missing',
                    child: Text('Report a missing species'),
                  ),
                  PopupMenuItem(
                    value: 'problem',
                    child: Text('Report a problem'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              ZooImage(zooId: inv.zoo.id, height: 180),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search species, group, zone…',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String?>(
                      value: _groupFilter,
                      hint: const Text('Group'),
                      onChanged: (value) => setState(() => _groupFilter = value),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All'),
                        ),
                        ...groups.map(
                          (g) => DropdownMenuItem<String?>(
                            value: g,
                            child: Text(g),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<Box>(
                  valueListenable: VisitStore.listenable(),
                  builder: (context, _, __) {
                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = filtered[i];
                        final count =
                            VisitStore.seenVisitsAtZoo(inv.zoo.id, s.id);
                        final seen = count > 0;

                        return ListTile(
                          title: Text(s.commonName),
                          subtitle: Text(
                            '${s.scientificName} • ${s.majorGroup}'
                            '${s.zone.isEmpty ? '' : ' • ${s.zone}'}',
                          ),
                          trailing: seen
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$count',
                                    style:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              '/detail',
                              arguments: SpeciesDetailArgs(
                                zooId: inv.zoo.id,
                                zooName: inv.zoo.name,
                                species: s,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
