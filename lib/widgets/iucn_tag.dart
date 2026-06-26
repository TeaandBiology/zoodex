import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Rarity ordering for sorting: higher = rarer (Extinct highest, Not Applicable
/// lowest). Unknown codes sort below everything. Used by the Species tab's
/// "IUCN status" sort, where descending shows the rarest first.
int iucnRarityRank(String code) {
  const order = {
    'EX': 9, 'EW': 8, 'CR': 7, 'EN': 6, 'VU': 5,
    'NT': 4, 'LC': 3, 'DD': 2, 'NE': 1, 'NA': 0,
  };
  return order[code.trim().toUpperCase()] ?? -1;
}

/// The localised full name for an IUCN code (e.g. "CR" -> "Critically
/// Endangered"). Unknown codes return the trimmed input unchanged. The codes
/// themselves are data and stay in English.
String iucnLabel(BuildContext context, String status) {
  final l = AppLocalizations.of(context);
  switch (status.trim().toUpperCase()) {
    case 'EX':
      return l.iucnEX;
    case 'EW':
      return l.iucnEW;
    case 'CR':
      return l.iucnCR;
    case 'EN':
      return l.iucnEN;
    case 'VU':
      return l.iucnVU;
    case 'NT':
      return l.iucnNT;
    case 'LC':
      return l.iucnLC;
    case 'DD':
      return l.iucnDD;
    case 'NE':
      return l.iucnNE;
    case 'NA':
      return l.iucnNA;
    default:
      return status.trim();
  }
}

/// A coloured tag for a species' IUCN Red List status. It spells out the code
/// (e.g. "CR" -> "Critically Endangered") and colours the tag with the Wikipedia
/// conservation-status colour.
///
/// Text is bright white on the coloured categories (regardless of contrast); the
/// neutral grey categories (DD/NE/NA) use black text instead.
class IucnTag extends StatelessWidget {
  final String status;
  const IucnTag({super.key, required this.status});

  // code -> (tag colour, text colour) as 0xAARRGGBB. The label is resolved
  // separately via [iucnLabel] so it can be translated.
  static const Map<String, (int, int)> _colors = {
    'EX': (0xFF000000, 0xFFFFFFFF),
    'EW': (0xFF000000, 0xFFFFFFFF),
    'CR': (0xFFCC3333, 0xFFFFFFFF),
    'EN': (0xFFCC6633, 0xFFFFFFFF),
    'VU': (0xFFCC9900, 0xFFFFFFFF),
    'NT': (0xFF006666, 0xFFFFFFFF),
    'LC': (0xFF006666, 0xFFFFFFFF),
    'DD': (0xFF6E6E6E, 0xFFFFFFFF),
    'NE': (0xFF8A8A8A, 0xFF000000),
    'NA': (0xFF7A7468, 0xFF000000),
  };

  @override
  Widget build(BuildContext context) {
    final code = status.trim().toUpperCase();
    final colors = _colors[code];

    // Known category -> Wikipedia colour + the rule above; unknown -> theme chip.
    final String label = iucnLabel(context, status);
    final Color background = colors != null
        ? Color(colors.$1)
        : Theme.of(context).colorScheme.secondaryContainer;
    final Color foreground = colors != null
        ? Color(colors.$2)
        : Theme.of(context).colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        // Faint outline so the tag stays defined against the page.
        border: Border.all(color: const Color(0x1F000000)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}
