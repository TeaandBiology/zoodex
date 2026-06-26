import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/entitlement_store.dart';
import '../data/profile_store.dart';
import '../data/report_store.dart';
import '../data/visit_store.dart';
import '../data/purchase_service.dart';
import '../data/reference_data.dart';
import '../data/settings_store.dart';
import '../models/entitlement.dart';
import '../util/country_names.dart';
import '../widgets/report_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _pendingCountry;

  List<String> get _countryOptions {
    final set = <String>{};
    for (final z in ReferenceData.instance.zoos) {
      if (z.country.isNotEmpty) set.add(z.country);
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: SettingsStore.nightMode,
            builder: (context, v, _) => SwitchListTile(
              title: const Text('Night Mode'),
              value: v,
              onChanged: (nv) => SettingsStore.nightMode.value = nv,
            ),
          ),
          const Divider(),

          // Home country (set once)
          ValueListenableBuilder<String?>(
            valueListenable: EntitlementStore.homeCountry,
            builder: (context, home, _) {
              if (home != null && home.isNotEmpty) {
                return ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('Home country'),
                  subtitle: Text('${countryName(home)} (set once — premium applies here)'),
                );
              }
              final options = _countryOptions;
              final value = _pendingCountry ??
                  (options.isNotEmpty ? options.first : null);
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.public),
                    const SizedBox(width: 16),
                    const Expanded(child: Text('Set home country')),
                    DropdownButton<String>(
                      value: value,
                      items: options
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(countryName(c))))
                          .toList(),
                      onChanged: (v) => setState(() => _pendingCountry = v),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: value == null
                          ? null
                          : () async {
                              await EntitlementStore.setHomeCountryOnce(value);
                              if (!mounted) return;
                              setState(() {});
                            },
                      child: const Text('Set'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),

          // Plan status
          ValueListenableBuilder<Entitlement>(
            valueListenable: EntitlementStore.current,
            builder: (context, ent, _) {
              final String plan;
              if (ent.isUnlimited) {
                plan = 'Unlimited — every zoo';
              } else if (ent.isPremium) {
                plan = 'Premium — all ${ent.premiumCountry} zoos';
              } else {
                plan =
                    'Free — ${ent.freeZooIds.length}/${Entitlement.maxFree} unlocks used';
              }
              return ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Plan'),
                subtitle: Text(plan),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore purchases'),
            onTap: () async {
              await PurchaseService.instance.restore();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restore requested')),
              );
            },
          ),

          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('Feedback'),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report a problem'),
            subtitle: const Text('Wrong image, factual error, missing species…'),
            onTap: () => showReportSheet(context),
          ),

          // Development tools (only when not using a validated store)
          if (!PurchaseService.instance.isProductionValidated) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Developer'),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Reset entitlements (dev)'),
              subtitle: const Text('Clears plan and free unlocks'),
              onTap: () async {
                await EntitlementStore.resetToFree();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Entitlements reset')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Reset onboarding (dev)'),
              subtitle: const Text(
                  'Re-shows the first-run flow; also clears home country + free '
                  'unlocks so the flow takes effect again (keeps your user id)'),
              onTap: () async {
                await EntitlementStore.resetToFree();
                await EntitlementStore.devClearHomeCountry();
                // Flipping this routes the app straight back to onboarding.
                await ProfileStore.resetOnboarding();
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_check),
              title: const Text('Add all species (dev)'),
              subtitle: const Text(
                  'Marks every catalogue species seen so the Species tab is fully populated'),
              onTap: () async {
                final n = await VisitStore.devAddAllSpecies();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added $n species to the Dex')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_remove),
              title: const Text('Remove dev species'),
              subtitle: const Text('Removes only the "add all species" sightings'),
              onTap: () async {
                await VisitStore.devRemoveAllSpecies();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dev species removed')),
                );
              },
            ),
            Builder(builder: (context) {
              final warnings = ReferenceData.instance.dataWarnings;
              return ListTile(
                leading: Icon(
                  warnings.isEmpty
                      ? Icons.verified_outlined
                      : Icons.warning_amber_outlined,
                  color: warnings.isEmpty
                      ? null
                      : Theme.of(context).colorScheme.error,
                ),
                title: const Text('Check catalogue data'),
                subtitle: Text(warnings.isEmpty
                    ? 'No problems found'
                    : '${warnings.length} problem(s) found — tap for details'),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Catalogue data'),
                    content: warnings.isEmpty
                        ? const Text(
                            'No problems found. Every subspecies/breed points '
                            'at a species that exists in the catalogue.')
                        : SizedBox(
                            width: double.maxFinite,
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                for (final w in warnings)
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Text('• $w'),
                                  ),
                              ],
                            ),
                          ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              );
            }),
            ValueListenableBuilder(
              valueListenable: ReportStore.listenable(),
              builder: (context, _, __) => ListTile(
                leading: const Icon(Icons.outbox_outlined),
                title: Text('Export reports (${ReportStore.count})'),
                subtitle: const Text('Share all collected problem reports'),
                onTap: ReportStore.count == 0
                    ? null
                    : () async {
                        final text = ReportStore.exportText();
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await SharePlus.instance.share(
                            ShareParams(
                                text: text, subject: 'ZooDex problem reports'),
                          );
                        } catch (_) {
                          await Clipboard.setData(ClipboardData(text: text));
                          messenger.showSnackBar(const SnackBar(
                              content: Text('Copied reports to clipboard')));
                        }
                      },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Clear reports'),
              onTap: () async {
                await ReportStore.clear();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reports cleared')),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
