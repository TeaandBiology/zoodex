import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
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

/// Language display names shown in their own language (autonyms). These are
/// intentionally NOT localized — each language is always shown in itself.
const Map<String, String> _languageAutonyms = <String, String>{
  'en': 'English',
  'fr': 'Français',
  'de': 'Deutsch',
  'es': 'Español',
  'cy': 'Cymraeg',
};

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
      appBar: AppBar(title: Text(AppLocalizations.of(context).commonSettings)),
      body: ListView(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: SettingsStore.nightMode,
            builder: (context, v, _) => SwitchListTile(
              title: Text(AppLocalizations.of(context).settingsNightMode),
              value: v,
              onChanged: (nv) => SettingsStore.nightMode.value = nv,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(AppLocalizations.of(context).settingsLanguage),
            trailing: ValueListenableBuilder<Locale>(
              valueListenable: ProfileStore.locale,
              builder: (context, current, _) => DropdownButton<Locale>(
                value: ProfileStore.supportedLocales.firstWhere(
                  (l) => l.languageCode == current.languageCode,
                  orElse: () => ProfileStore.supportedLocales.first,
                ),
                items: [
                  for (final l in ProfileStore.supportedLocales)
                    DropdownMenuItem(
                      value: l,
                      child: Text(_languageAutonyms[l.languageCode] ??
                          l.languageCode),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) ProfileStore.setLocale(v);
                },
              ),
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
                  title: Text(AppLocalizations.of(context).settingsHomeCountry),
                  subtitle: Text(AppLocalizations.of(context)
                      .settingsHomeCountrySetSubtitle(countryName(home))),
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
                    Expanded(
                        child: Text(AppLocalizations.of(context)
                            .settingsSetHomeCountry)),
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
                      child: Text(AppLocalizations.of(context).settingsSet),
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
                plan = AppLocalizations.of(context).settingsPlanUnlimited;
              } else if (ent.isPremium) {
                plan = AppLocalizations.of(context)
                    .settingsPlanPremium(ent.premiumCountry ?? '');
              } else {
                plan = AppLocalizations.of(context).settingsPlanFree(
                    ent.freeZooIds.length, Entitlement.maxFree);
              }
              return ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: Text(AppLocalizations.of(context).settingsPlan),
                subtitle: Text(plan),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: Text(AppLocalizations.of(context).settingsRestorePurchases),
            onTap: () async {
              await PurchaseService.instance.restore();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        AppLocalizations.of(context).settingsRestoreRequested)),
              );
            },
          ),

          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(AppLocalizations.of(context).settingsFeedback),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(AppLocalizations.of(context).settingsReportProblem),
            subtitle:
                Text(AppLocalizations.of(context).settingsReportProblemSubtitle),
            onTap: () => showReportSheet(context),
          ),

          // Development tools (only when not using a validated store)
          if (!PurchaseService.instance.isProductionValidated) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(AppLocalizations.of(context).settingsDeveloper),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title:
                  Text(AppLocalizations.of(context).settingsResetEntitlements),
              subtitle: Text(AppLocalizations.of(context)
                  .settingsResetEntitlementsSubtitle),
              onTap: () async {
                await EntitlementStore.resetToFree();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(AppLocalizations.of(context)
                          .settingsEntitlementsReset)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: Text(AppLocalizations.of(context).settingsResetOnboarding),
              subtitle: Text(AppLocalizations.of(context)
                  .settingsResetOnboardingSubtitle),
              onTap: () async {
                await EntitlementStore.resetToFree();
                await EntitlementStore.devClearHomeCountry();
                // Flipping this routes the app straight back to onboarding.
                await ProfileStore.resetOnboarding();
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_check),
              title: Text(AppLocalizations.of(context).settingsAddAllSpecies),
              subtitle: Text(
                  AppLocalizations.of(context).settingsAddAllSpeciesSubtitle),
              onTap: () async {
                final n = await VisitStore.devAddAllSpecies();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(AppLocalizations.of(context)
                          .settingsAddedSpecies(n))),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_remove),
              title: Text(AppLocalizations.of(context).settingsRemoveDevSpecies),
              subtitle: Text(AppLocalizations.of(context)
                  .settingsRemoveDevSpeciesSubtitle),
              onTap: () async {
                await VisitStore.devRemoveAllSpecies();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(AppLocalizations.of(context)
                          .settingsDevSpeciesRemoved)),
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
                title: Text(
                    AppLocalizations.of(context).settingsCheckCatalogueData),
                subtitle: Text(warnings.isEmpty
                    ? AppLocalizations.of(context).settingsNoProblemsFound
                    : AppLocalizations.of(context)
                        .settingsProblemsFound(warnings.length)),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                        AppLocalizations.of(context).settingsCatalogueData),
                    content: warnings.isEmpty
                        ? Text(AppLocalizations.of(context)
                            .settingsCatalogueDataNoProblems)
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
                        child: Text(AppLocalizations.of(context).commonClose),
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
                title: Text(AppLocalizations.of(context)
                    .settingsExportReports(ReportStore.count)),
                subtitle: Text(
                    AppLocalizations.of(context).settingsExportReportsSubtitle),
                onTap: ReportStore.count == 0
                    ? null
                    : () async {
                        final text = ReportStore.exportText();
                        final l10n = AppLocalizations.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await SharePlus.instance.share(
                            ShareParams(
                                text: text,
                                subject: l10n.settingsReportsShareSubject),
                          );
                        } catch (_) {
                          await Clipboard.setData(ClipboardData(text: text));
                          messenger.showSnackBar(SnackBar(
                              content: Text(l10n.settingsCopiedReports)));
                        }
                      },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: Text(AppLocalizations.of(context).settingsClearReports),
              onTap: () async {
                await ReportStore.clear();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(AppLocalizations.of(context)
                          .settingsReportsCleared)),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
