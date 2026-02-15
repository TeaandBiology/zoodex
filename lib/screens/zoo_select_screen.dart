import 'package:flutter/material.dart';

import '../data/data_loader.dart';
import '../models/inventory.dart';
import '../models/zoo.dart';
import 'zoo_inventory_screen.dart';

class ZooSelectScreen extends StatelessWidget {
  const ZooSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a Zoo')),
      body: FutureBuilder<List<Zoo>>(
        future: DataLoader.loadZoos(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final zoos = snap.data ?? const <Zoo>[];

          return ListView.separated(
            itemCount: zoos.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final z = zoos[i];
              final zooId = z.id;
              final name = z.name;

              // Try to load inventory to show species count; inventory files
              // exist for all zoos (we generated them), but fall back silently.
              return FutureBuilder<ZooInventory>(
                future: DataLoader.loadZooInventory(zooId),
                builder: (context, invSnap) {
                  final title = invSnap.hasData ? invSnap.data!.zoo.name : name;
                  final subtitle = invSnap.hasData ? '${invSnap.data!.species.length} species' : null;

                  final asset = DataLoader.inventories[zooId] ?? 'assets/data/inventories/$zooId.json';

                  return ListTile(
                    title: Text(title),
                    subtitle: subtitle == null ? null : Text(subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        '/inventory',
                        arguments: ZooInventoryArgs(zooId: zooId, zooName: title, assetPath: asset),
                      );
                    },
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
