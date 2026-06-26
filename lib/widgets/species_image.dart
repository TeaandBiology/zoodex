import 'package:flutter/material.dart';

import '../data/reference_data.dart';
import '../models/species.dart';
import 'fallback_image.dart';

/// Shows a species photo, preferring a real WebP photo and otherwise falling
/// back to a per-group placeholder, then the universal placeholder.
///
/// Resolution order:
///   images/<slug>.webp   (downloaded photo)
///   images/<slug>.png    (a manually dropped-in PNG photo, if any)
///   images/default_<group>.png   (per major group)
///   images/default.png   (ultimate fallback)
///
/// To add a real photo, drop `images/<slug>.webp` (e.g. `elephas_maximus.webp`)
/// into the folder — it appears automatically on the next build. Placeholders
/// stay PNG.
class SpeciesImage extends StatelessWidget {
  final Species species;
  final double? height;
  final BoxFit fit;

  const SpeciesImage({
    super.key,
    required this.species,
    this.height,
    this.fit = BoxFit.cover,
  });

  static const String _ultimate = 'images/default.png';

  static const Map<String, String> _groupDefaults = {
    'Mammals': 'images/default_mammal.png',
    'Birds': 'images/default_bird.png',
    'Reptiles': 'images/default_reptile.png',
    'Amphibians': 'images/default_amphibian.png',
    'Fish': 'images/default_fish.png',
    'Invertebrates': 'images/default_invertebrate.png',
  };

  /// The ordered fallback path list for a species' photo. Shared by the inline
  /// image and the full-screen viewer so both resolve to the same file.
  static List<String> pathsFor(Species species) {
    final groupDefault = _groupDefaults[species.majorGroup] ?? _ultimate;
    final slug = species.slug;
    return <String>[
      if (slug.isNotEmpty) 'images/$slug.webp',
      if (slug.isNotEmpty) 'images/$slug.png',
      groupDefault,
      _ultimate,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final f = ReferenceData.instance.imageFocusFor(species);
    final alignment =
        f == null ? Alignment.center : Alignment(f[0] * 2 - 1, f[1] * 2 - 1);
    return FallbackImage(
      paths: pathsFor(species),
      height: height,
      fit: fit,
      alignment: alignment,
    );
  }
}

/// Opens the species photo full-screen and uncropped, pinch/drag zoomable, with
/// the image copyright shown underneath. Triggered by the magnifier on the hero.
Future<void> showFullSpeciesImage(
  BuildContext context,
  Species species, {
  String credit = '',
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (context) => _FullImageView(
      paths: SpeciesImage.pathsFor(species),
      caption: species.commonName,
      credit: credit,
    ),
  );
}

class _FullImageView extends StatelessWidget {
  final List<String> paths;
  final String caption;
  final String credit;
  const _FullImageView({
    required this.paths,
    required this.caption,
    required this.credit,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              // Uncropped: contain rather than cover.
              child: FallbackImage(paths: paths, fit: BoxFit.contain),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        if (credit.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0x88000000),
                child: Text(
                  credit,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
