import 'package:flutter/material.dart';

/// A full-bleed header image with a title (and optional extra content) overlaid
/// on a dark gradient at the bottom — the same treatment used on species pages.
/// Falls back to images/default.png if [assetPath] can't be loaded.
class ImageHeader extends StatelessWidget {
  final String assetPath;
  final String title;
  final double height;

  /// Optional widgets shown under the title, inside the overlay.
  final List<Widget> below;

  const ImageHeader({
    super.key,
    required this.assetPath,
    required this.title,
    this.height = 400,
    this.below = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Image.asset(
          assetPath,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Image.asset(
            'images/default.png',
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC000000), Color(0x00000000)],
                stops: [0.0, 0.6],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                ...below,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
