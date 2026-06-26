import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/profile_store.dart';
import '../data/entitlement_store.dart';
import '../data/reference_data.dart';
import '../data/visit_store.dart';
import '../models/achievement.dart';
import '../models/profile.dart';
import '../models/species_log.dart';
import '../models/verification.dart';
import '../util/country_names.dart';
import '../util/csv_export.dart';
import '../util/date_format.dart';
import '../widgets/app_avatar.dart';
import '../l10n/app_localizations.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).profileComingSoon(what))));
  }

  static String _csvCell(String s) => '"${s.replaceAll('"', '""')}"';

  /// One row per logged species across all visits. Returns null if there's
  /// nothing logged yet.
  String? _buildCsv() {
    final ref = ReferenceData.instance;
    final dataRows = <List<String>>[];
    for (final v in VisitStore.allVisits()) {
      final zoo = ref.zooById(v.zooId)?.name ?? v.zooId;
      for (final log in v.logs.values) {
        final s = ref.speciesById(log.speciesId);
        dataRows.add([
          formatLocalDate(v.date),
          formatLocalDateTime(log.loggedAt),
          zoo,
          s?.commonName ?? log.speciesId,
          s?.scientificName ?? '',
          s?.majorGroup ?? '',
          log.outcome == Outcome.seen ? 'Seen' : 'No-show',
          verificationToString(v.verified),
          log.note ?? '',
        ]);
      }
    }
    if (dataRows.isEmpty) return null;

    dataRows.sort((a, b) {
      final d = a[0].compareTo(b[0]);
      if (d != 0) return d;
      final z = a[2].compareTo(b[2]);
      if (z != 0) return z;
      return a[3].toLowerCase().compareTo(b[3].toLowerCase());
    });

    const header = [
      'Date', 'Logged at', 'Zoo', 'Common name', 'Scientific name',
      'Group', 'Outcome', 'Verification', 'Note',
    ];
    return [header, ...dataRows]
        .map((r) => r.map(_csvCell).join(','))
        .join('\r\n');
  }

  Future<void> _exportData(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final csv = _buildCsv();
    if (csv == null) {
      messenger.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).profileNoDataToExport)));
      return;
    }
    final filename = 'zoodex_export_${dateKey(DateTime.now())}.csv';
    try {
      await exportCsvFile(csv, filename);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: csv));
      messenger.showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).profileSharingUnavailable),
      ));
    }
  }

  Future<void> _setCountry(BuildContext context) async {
    final options = <String>{
      for (final z in ReferenceData.instance.zoos)
        if (z.country.isNotEmpty) z.country,
    }.toList()
      ..sort();
    if (options.isEmpty) return;
    var selected = options.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).profileSetHomeCountry),
        content: StatefulBuilder(
          builder: (context, setS) => DropdownButton<String>(
            value: selected,
            isExpanded: true,
            items: [
              for (final c in options)
                DropdownMenuItem(value: c, child: Text(countryName(c))),
            ],
            onChanged: (v) => setS(() => selected = v ?? selected),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).profileSet),
          ),
        ],
      ),
    );
    if (ok == true) await EntitlementStore.setHomeCountryOnce(selected);
  }

  Future<void> _addFriends(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).profileAddFriend),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).profileEnterFriendCode),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).profileFriendCode,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _comingSoon(context, AppLocalizations.of(context).profileFriends);
            },
            child: Text(AppLocalizations.of(context).profileAdd),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Profile>(
      valueListenable: ProfileStore.current,
      builder: (context, profile, _) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const SizedBox.shrink(),
            backgroundColor: const Color(0x66000000),
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              IconButton(
                tooltip: AppLocalizations.of(context).profileEditProfile,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _comingSoon(
                    context, AppLocalizations.of(context).profileProfileEditing),
              ),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    AppAvatar(avatarId: profile.avatarId, size: 96),
                    const SizedBox(height: 12),
                    Text(profile.displayName,
                        style: Theme.of(context).textTheme.headlineSmall),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // @username (left) + Joined / country (right, same line)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            '@${profile.username}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ValueListenableBuilder<String?>(
                          valueListenable: EntitlementStore.homeCountry,
                          builder: (context, home, _) {
                            final muted = Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.outline);
                            final joined = AppLocalizations.of(context)
                                .profileJoined(monthYear(profile.joinedAt));
                            if (home != null && home.isNotEmpty) {
                              return Text('$joined  ·  ${countryShort(home)}',
                                  style: muted, textAlign: TextAlign.right);
                            }
                            return GestureDetector(
                              onTap: () => _setCountry(context),
                              child: Text(
                                  '$joined  ·  ${AppLocalizations.of(context).profileSetCountry}',
                                  style: muted, textAlign: TextAlign.right),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Local zoo (chosen from zoos you've visited)
                    _LocalZooTile(profile: profile),
                    const SizedBox(height: 16),

                    // Add friends
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _addFriends(context),
                        icon: const Icon(Icons.person_add_alt),
                        label: Text(AppLocalizations.of(context).profileAddFriends),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Export data
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _exportData(context),
                        icon: const Icon(Icons.download_outlined),
                        label: Text(AppLocalizations.of(context).profileExportData),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Overview (this is what other people see)
                    Text(
                      AppLocalizations.of(context).profileOverview,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const _OverviewGrid(),
                    const SizedBox(height: 24),

                    // Achievements
                    Text(
                      AppLocalizations.of(context).profileAchievements,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const _AchievementsSection(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tile letting the user pick a "local zoo" from the zoos they've visited.
class _LocalZooTile extends StatelessWidget {
  final Profile profile;
  const _LocalZooTile({required this.profile});

  Future<void> _pick(BuildContext context, Set<String> visitedIds) async {
    final ref = ReferenceData.instance;
    final zoos = [
      for (final id in visitedIds)
        if (ref.zooById(id) != null) ref.zooById(id)!,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final z in zoos)
              ListTile(
                title: Text(z.name),
                trailing:
                    z.id == profile.localZooId ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, z.id),
              ),
            if (profile.localZooId.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pop(context, ''),
                child: Text(AppLocalizations.of(context).profileClearLocalZoo),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      await ProfileStore.save(profile.copyWith(localZooId: chosen));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: VisitStore.listenable(),
      builder: (context, _, __) {
        final ref = ReferenceData.instance;
        final visitedIds = <String>{
          for (final v in VisitStore.allVisits()) v.zooId,
        };
        final current = profile.localZooId.isNotEmpty
            ? ref.zooById(profile.localZooId)
            : null;
        final subtitle = current?.name ??
            (visitedIds.isEmpty
                ? AppLocalizations.of(context).profileVisitToSetLocalZoo
                : AppLocalizations.of(context).profileLocalZooNotSet);
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.home_outlined),
            title: Text(AppLocalizations.of(context).profileLocalZoo),
            subtitle: Text(subtitle),
            trailing: visitedIds.isEmpty ? null : const Icon(Icons.chevron_right),
            onTap: visitedIds.isEmpty ? null : () => _pick(context, visitedIds),
          ),
        );
      },
    );
  }
}

/// The public stats. Wired to real counts; more can be added later.
class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: VisitStore.listenable(),
      builder: (context, _, __) {
        final dex = VisitStore.buildDex();
        final visits = VisitStore.allVisits();
        final speciesSeen = dex.length;
        final zoosVisited = <String>{for (final v in visits) v.zooId}.length;
        final sightings =
            dex.fold<int>(0, (sum, e) => sum + e.visitsSeenCount);

        final l10n = AppLocalizations.of(context);
        final stats = <(String, String)>[
          (l10n.profileSpeciesSeen, '$speciesSeen'),
          (l10n.profileZoosVisited, '$zoosVisited'),
          (l10n.profileSightings, '$sightings'),
        ];

        return Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _StatCard(label: stats[i].$1, value: stats[i].$2)),
            ],
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Real achievements aren't defined yet, so this shows a placeholder until
/// [kAchievements] is populated.
class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection();

  @override
  Widget build(BuildContext context) {
    if (kAchievements.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(4, (_) => const _LockedBadge()),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).profileAchievementsPlaceholder,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final a in kAchievements)
          _AchievementBadge(achievement: a),
      ],
    );
  }
}

class _LockedBadge extends StatelessWidget {
  const _LockedBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.lock_outline, color: scheme.outline),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  const _AchievementBadge({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = achievement.unlocked;
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: on ? scheme.primaryContainer : scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              on ? achievement.icon : Icons.lock_outline,
              color: on ? scheme.onPrimaryContainer : scheme.outline,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
