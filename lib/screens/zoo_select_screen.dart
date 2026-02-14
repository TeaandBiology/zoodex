import 'package:flutter/material.dart';

import '../data/data_loader.dart';
import '../models/inventory.dart';
import 'zoo_inventory_screen.dart';

class ZooSelectScreen extends StatelessWidget {
  const ZooSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a zoo')),
      body: ListView.separated(
        itemCount: DataLoader.knownZooPacks.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final zooId = DataLoader.knownZooPacks[i]['id']!;
          final asset = DataLoader.knownZooPacks[i]['asset']!;

          return FutureBuilder<ZooInventory>(
            future: DataLoader.loadZooInventory(zooId),
            builder: (context, snap) {
              final title = (snap.hasData)
                  ? snap.data!.zoo.name
                  : (snap.hasError ? zooId : 'Loading…');

              final subtitle = (snap.hasData)
                  ? '${snap.data!.species.length} species'
                  : null;

              return ListTile(
                title: Text(title),
                subtitle: subtitle == null ? null : Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    '/inventory',
                    arguments: ZooInventoryArgs(zooId: zooId, assetPath: asset),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
