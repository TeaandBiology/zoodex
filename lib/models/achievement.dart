import 'package:flutter/material.dart';

/// An award earned for a milestone (e.g. "Seen 100 mammals", "Visited 10 zoos").
///
/// Skeleton only — the actual awards, their criteria, and the rule that only
/// *verified* sightings count toward them are still to be defined. The profile
/// page renders [kAchievements] when it's populated, and a placeholder until then.
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    this.icon = Icons.emoji_events_outlined,
    this.unlocked = false,
  });
}

/// To be defined later. Kept empty for now so the profile shows a placeholder.
const List<Achievement> kAchievements = <Achievement>[];
