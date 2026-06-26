import 'package:flutter/material.dart';

import '../data/reference_data.dart';
import '../models/species.dart';
import '../l10n/app_localizations.dart';
import 'fallback_image.dart';

/// Shows a species' geographic range map, resolved through an ordered fallback
/// list (same mechanism as [SpeciesImage]/[FallbackImage]).
///
/// Resolution order for a normal species/subspecies:
///   assets/range/<rangeMap>            (explicit override, if the catalog sets one)
///   assets/range/<slug>.webp / .png    (this taxon's own range)
///   assets/range/<parentSlug>.webp/.png  (subspecies → whole-species range)
///   assets/range/_unavailable.png      (never blank)
///
/// Domestic species/breeds short-circuit to a shared "no natural range" map:
///   assets/range/_domestic.png
///
/// Drop a real `assets/range/<slug>.webp` in and it appears on the next build —
/// no code or catalog change needed.
class RangeMap extends StatelessWidget {
  final Species species;
  final double? height;
  final BoxFit fit;

  const RangeMap({
    super.key,
    required this.species,
    this.height,
    this.fit = BoxFit.contain,
  });

  static const String _domestic = 'assets/range/_domestic.png';
  static const String _unavailable = 'assets/range/_unavailable.png';

  /// Ordered fallback paths for a species' range map.
  static List<String> pathsFor(Species species) {
    if (species.domestic) return const [_domestic, _unavailable];

    final paths = <String>[];

    // Optional explicit override from the catalog (`range_map`). Accept either a
    // bare filename or a full asset path.
    final override = species.rangeMap.trim();
    if (override.isNotEmpty) {
      paths.add(override.contains('/') ? override : 'assets/range/$override');
    }

    if (species.slug.isNotEmpty) {
      paths.add('assets/range/${species.slug}.webp');
      paths.add('assets/range/${species.slug}.png');
    }

    // A subspecies/breed with no map of its own falls back to the parent species'
    // whole-range map.
    final parent = ReferenceData.instance.parentOf(species.id);
    if (parent != null && parent.slug.isNotEmpty) {
      paths.add('assets/range/${parent.slug}.webp');
      paths.add('assets/range/${parent.slug}.png');
    }

    paths.add(_unavailable);
    return paths;
  }

  @override
  Widget build(BuildContext context) {
    return FallbackImage(paths: pathsFor(species), height: height, fit: fit);
  }
}

/// Opens the range map full-screen, pinch/drag zoomable.
Future<void> showFullRangeMap(BuildContext context, Species species) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (context) => _FullRangeView(
      paths: RangeMap.pathsFor(species),
      caption: AppLocalizations.of(context).rangeMapCaption(species.commonName),
    ),
  );
}

class _FullRangeView extends StatelessWidget {
  final List<String> paths;
  final String caption;
  const _FullRangeView({required this.paths, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 8,
            child: Center(child: FallbackImage(paths: paths, fit: BoxFit.contain)),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: IconButton(
              tooltip: AppLocalizations.of(context).commonClose,
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0x88000000),
              child: Text(
                caption,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
