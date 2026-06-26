import 'package:flutter/material.dart';

/// A small rounded label used for short tags such as a species' group, its
/// enclosure zone, or its IUCN status.
class AppChip extends StatelessWidget {
  final String label;
  const AppChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}
