import 'package:flutter/material.dart';

import '../models/zoo.dart';
import '../widgets/zoo_image.dart';

/// Skeleton "zoo info" page reached from the (i) button on a zoo's page.
/// Sections are placeholders for now — a blurb, opening times, website, and
/// social links will be filled in later (and eventually come from zoo data).
class ZooInfoScreen extends StatelessWidget {
  final Zoo zoo;
  const ZooInfoScreen({super.key, required this.zoo});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outline;

    Widget header(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            t,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        );

    Widget placeholder(String t) => Text(t, style: TextStyle(color: muted));

    Widget detail(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: 120,
                  child: Text(k, style: TextStyle(color: muted))),
              Expanded(child: Text(v)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(zoo.name)),
      body: ListView(
        children: [
          ZooImage(zooId: zoo.id, height: 180),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header('About'),
                placeholder('A short description of ${zoo.name} will go here.'),
                const SizedBox(height: 24),

                header('Opening times'),
                placeholder('Opening times coming soon.'),
                const SizedBox(height: 24),

                header('Website'),
                placeholder('Not added yet.'),
                const SizedBox(height: 24),

                header('Social media'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in const ['Facebook', 'Instagram', 'X', 'YouTube'])
                      Chip(
                        avatar: const Icon(Icons.link, size: 16),
                        label: Text(s),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Links coming soon.',
                    style: TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 24),

                header('Details'),
                if (zoo.country.isNotEmpty) detail('Country', zoo.country),
                if (zoo.lastUpdated.isNotEmpty)
                  detail('Info updated', zoo.lastUpdated),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
