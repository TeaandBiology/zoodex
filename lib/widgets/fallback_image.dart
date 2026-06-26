import 'package:flutter/material.dart';

/// Shows the first asset in [paths] that loads, trying each in order. The last
/// path is assumed to always exist (a bundled placeholder), so there's never a
/// blank space.
///
/// All species/zoo photo loading funnels through this one widget. That matters
/// for scale: bundling every image stops being viable once the catalogue grows
/// into the thousands, so the photos will eventually be downloaded on demand and
/// cached on device (the way field-guide apps like Merlin ship thumbnails and
/// fetch full packs). When that happens, only this file (and the two thin
/// wrappers that build the path list) needs to change — not the screens.
class FallbackImage extends StatelessWidget {
  final List<String> paths;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Alignment alignment;

  const FallbackImage({
    super.key,
    required this.paths,
    this.height,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  }) : assert(paths.length > 0);

  @override
  Widget build(BuildContext context) => _buildAt(0);

  Widget _buildAt(int i) {
    final isLast = i == paths.length - 1;
    return Image.asset(
      paths[i],
      height: height,
      width: width,
      fit: fit,
      alignment: alignment,
      errorBuilder:
          isLast ? null : (context, error, stack) => _buildAt(i + 1),
    );
  }
}
