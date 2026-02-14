import 'package:flutter/material.dart';

class AppChip extends StatelessWidget {
  final String label;
  const AppChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}
