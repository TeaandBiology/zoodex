import 'package:flutter/material.dart';

import 'fallback_image.dart';

/// Banner image for a zoo, preferring a real WebP photo and falling back to the
/// `default_zoo.png` placeholder.
///
/// Resolution order:
///   images/zoo_<zooId>.webp   (downloaded photo)
///   images/zoo_<zooId>.png    (a manually dropped-in PNG, if any)
///   images/default_zoo.png    (placeholder)
class ZooImage extends StatelessWidget {
  final String zooId;
  final double? height;
  final BoxFit fit;

  const ZooImage({
    super.key,
    required this.zooId,
    this.height,
    this.fit = BoxFit.cover,
  });

  static const String _fallback = 'images/default_zoo.png';

  @override
  Widget build(BuildContext context) {
    final paths = <String>[
      if (zooId.isNotEmpty) 'images/zoo_$zooId.webp',
      if (zooId.isNotEmpty) 'images/zoo_$zooId.png',
      _fallback,
    ];
    return FallbackImage(paths: paths, height: height, fit: fit);
  }
}
