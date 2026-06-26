import 'package:flutter/material.dart';

/// A top-to-bottom fade (semi-opaque black fading to clear) for use as an
/// AppBar's [AppBar.flexibleSpace] over a full-bleed image. Replaces a solid
/// translucent bar so there's no hard bottom edge.
class FadeAppBarBackground extends StatelessWidget {
  const FadeAppBarBackground({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x99000000), Color(0x00000000)],
          ),
        ),
      );
}
