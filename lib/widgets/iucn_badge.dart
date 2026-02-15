import 'package:flutter/material.dart';

class IucnBadge extends StatelessWidget {
  final String code;
  final bool small;
  const IucnBadge({super.key, required this.code, this.small = false});

  Color _colorFor(String c) {
    switch (c) {
      case 'CR':
        return const Color(0xFFD32F2F); // red
      case 'EN':
        return const Color(0xFFFF5722); // deep orange
      case 'VU':
        return const Color(0xFFFF9800); // orange
      case 'NT':
        return const Color(0xFFFFEB3B); // yellow
      case 'LC':
        return const Color(0xFF66BB6A); // green
      case 'DD':
        return const Color(0xFF9E9E9E); // grey
      case 'EW':
      case 'EX':
        return const Color(0xFF424242); // dark grey
      default:
        return const Color(0xFF607D8B); // blue-grey (unknown)
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeTrim = code.trim().toUpperCase();
    final display = codeTrim.isEmpty ? 'NR' : codeTrim;

    final bg = _colorFor(display);
    final textColor = bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return Chip(
      label: Text(
        display,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: small ? 12 : null,
        ),
      ),
      backgroundColor: bg,
      padding: small ? const EdgeInsets.symmetric(horizontal: 6, vertical: 0) : null,
      visualDensity: small ? VisualDensity(horizontal: -4, vertical: -4) : VisualDensity.compact,
    );
  }
}
