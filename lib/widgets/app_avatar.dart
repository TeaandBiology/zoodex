import 'package:flutter/material.dart';

/// A profile avatar. For now these are asset-free — a coloured circle with a
/// Material icon — so onboarding works before any real avatar artwork exists.
/// When art is added (see assets/data/avatars.json), swap the icon for an image
/// here and nothing else changes.
class AvatarOption {
  final String id;
  final IconData icon;
  final Color color;
  const AvatarOption(this.id, this.icon, this.color);
}

const List<AvatarOption> kAvatars = [
  AvatarOption('panda', Icons.pets, Color(0xFF6D4C41)),
  AvatarOption('bunny', Icons.cruelty_free, Color(0xFFD81B60)),
  AvatarOption('penguin', Icons.ac_unit, Color(0xFF1E88E5)),
  AvatarOption('frog', Icons.eco, Color(0xFF43A047)),
  AvatarOption('fish', Icons.set_meal, Color(0xFF00897B)),
  AvatarOption('bird', Icons.flutter_dash, Color(0xFF8E24AA)),
  AvatarOption('bug', Icons.bug_report, Color(0xFFF57C00)),
  AvatarOption('owl', Icons.nightlight_round, Color(0xFF3949AB)),
];

String get defaultAvatarId => kAvatars.first.id;

AvatarOption avatarOptionFor(String id) =>
    kAvatars.firstWhere((a) => a.id == id, orElse: () => kAvatars.first);

class AppAvatar extends StatelessWidget {
  final String avatarId;
  final double size;
  final bool selected;

  const AppAvatar({
    super.key,
    required this.avatarId,
    this.size = 48,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final opt = avatarOptionFor(avatarId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: opt.color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: selected
            ? Border.all(color: opt.color, width: 3)
            : Border.all(color: Colors.transparent, width: 3),
      ),
      alignment: Alignment.center,
      child: Icon(opt.icon, size: size * 0.52, color: opt.color),
    );
  }
}
