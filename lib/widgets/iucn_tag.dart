import 'package:flutter/material.dart';

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

/// A coloured tag for a species' IUCN Red List status. It spells out the code
/// (e.g. "CR" -> "Critically Endangered") and colours the tag with the Wikipedia
/// conservation-status colour.
///
/// Text is bright white on the coloured categories (regardless of contrast); the
/// neutral grey categories (DD/NE/NA) use black text instead.
class IucnTag extends StatelessWidget {
  final String status;
  const IucnTag({super.key, required this.status});

  // code -> (full label, tag colour, text colour) as 0xAARRGGBB
  static const Map<String, (String, int, int)> _categories = {
    'EX': ('Extinct', 0xFF000000, 0xFFFFFFFF),
    'EW': ('Extinct in the Wild', 0xFF000000, 0xFFFFFFFF),
    'CR': ('Critically Endangered', 0xFFCC3333, 0xFFFFFFFF),
    'EN': ('Endangered', 0xFFCC6633, 0xFFFFFFFF),
    'VU': ('Vulnerable', 0xFFCC9900, 0xFFFFFFFF),
    'NT': ('Near Threatened', 0xFF006666, 0xFFFFFFFF),
    'LC': ('Least Concern', 0xFF006666, 0xFFFFFFFF),
    'DD': ('Data Deficient', 0xFF6E6E6E, 0xFFFFFFFF),
    'NE': ('Not Evaluated', 0xFF8A8A8A, 0xFF000000),
    'NA': ('Not Applicable', 0xFF7A7468, 0xFF000000),
  };

  @override
  Widget build(BuildContext context) {
    final code = status.trim().toUpperCase();
    final info = _categories[code];

    // Known category -> Wikipedia colour + the rule above; unknown -> theme chip.
    final String label = info?.$1 ?? status.trim();
    final Color background =
        info != null ? Color(info.$2) : Theme.of(context).colorScheme.secondaryContainer;
    final Color foreground = info != null
        ? Color(info.$3)
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
