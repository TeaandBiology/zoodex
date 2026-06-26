import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../data/entitlement_store.dart';
import '../data/profile_store.dart';
import '../data/reference_data.dart';
import '../models/zoo.dart';
import '../util/country_names.dart';
import '../widgets/app_avatar.dart';

/// First-run setup. Local-only (no login): collects a display name, a desired
/// @username, an avatar, a home country, and an optional first free zoo, then
/// flips [ProfileStore.onboardingComplete]. A permanent user id was already
/// minted by [ProfileStore.init], so this can upgrade to a real account later
/// with no login screen (see DESIGN §8).
/// Language display names shown in their own language (autonyms). These are
/// intentionally NOT localized — each language is always shown in itself.
const Map<String, String> _languageAutonyms = <String, String>{
  'en': 'English',
  'fr': 'Français',
  'de': 'Deutsch',
  'es': 'Español',
  'cy': 'Cymraeg',
};

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _saving = false;

  final _name = TextEditingController();
  final _username = TextEditingController();
  String _avatarId = defaultAvatarId;
  String? _country;
  String? _zooId;
  late Locale _locale;

  late final List<String> _countryOptions;

  static const int _steps = 6; // welcome, name, username, avatar, country, zoo

  @override
  void initState() {
    super.initState();
    final set = <String>{};
    for (final z in ReferenceData.instance.zoos) {
      if (z.country.isNotEmpty) set.add(z.country);
    }
    _countryOptions = set.toList()..sort();
    // Seed the language picker from the locale ProfileStore already resolved
    // (saved choice or device default), matched against supportedLocales.
    final activeCode = ProfileStore.locale.value.languageCode;
    _locale = ProfileStore.supportedLocales.firstWhere(
      (l) => l.languageCode == activeCode,
      orElse: () => ProfileStore.supportedLocales.first,
    );
    final cc = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    _country = (cc != null && _countryOptions.contains(cc))
        ? cc
        : (_countryOptions.isNotEmpty ? _countryOptions.first : null);
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  String _sanitizeUsername(String raw) {
    var s = raw.trim().toLowerCase().replaceAll(RegExp(r'^@+'), '');
    s = s.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return s;
  }

  bool get _canContinue {
    switch (_step) {
      case 1:
        return _name.text.trim().isNotEmpty;
      case 2:
        return _sanitizeUsername(_username.text).isNotEmpty;
      case 4:
        return _country != null;
      default:
        return true; // welcome, avatar, zoo (zoo is skippable)
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final p = ProfileStore.current.value.copyWith(
      displayName: _name.text.trim(),
      username: _sanitizeUsername(_username.text),
      avatarId: _avatarId,
      localZooId: _zooId ?? '',
    );
    await ProfileStore.save(p);
    if (_country != null) await EntitlementStore.setHomeCountryOnce(_country!);
    if (_zooId != null) await EntitlementStore.unlockFreeZoo(_zooId!);
    await ProfileStore.completeOnboarding(); // swaps the app to HomeShell
  }

  void _next() {
    if (_step == _steps - 1) {
      _finish();
    } else {
      // Pre-fill a username suggestion from the name on the way past the name step.
      if (_step == 1 && _username.text.trim().isEmpty) {
        _username.text = _sanitizeUsername(_name.text);
      }
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == _steps - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  for (var i = 0; i < _steps; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: SingleChildScrollView(child: _body(context)),
              ),
            ),
            // Nav bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _saving ? null : () => setState(() => _step--),
                      child: Text(AppLocalizations.of(context).commonBack),
                    ),
                  const Spacer(),
                  if (_step == _steps - 1 && _zooId == null)
                    TextButton(
                      onPressed: _saving ? null : _finish,
                      child: Text(AppLocalizations.of(context).commonSkip),
                    ),
                  FilledButton(
                    onPressed: (_canContinue && !_saving) ? _next : null,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(isLast
                            ? AppLocalizations.of(context).onboardingStartExploring
                            : AppLocalizations.of(context).onboardingContinue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
        ],
      );

  Widget _body(BuildContext context) {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Icon(Icons.pets,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).onboardingWelcomeTitle,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context).onboardingWelcomeBody,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(AppLocalizations.of(context).onboardingNameTitle,
                AppLocalizations.of(context).onboardingNameSubtitle),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).onboardingNameLabel,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(AppLocalizations.of(context).onboardingUsernameTitle,
                AppLocalizations.of(context).onboardingUsernameSubtitle),
            TextField(
              controller: _username,
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '@',
                labelText:
                    AppLocalizations.of(context).onboardingUsernameLabel,
                border: const OutlineInputBorder(),
                helperText:
                    AppLocalizations.of(context).onboardingUsernameHelper,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(AppLocalizations.of(context).onboardingAvatarTitle,
                AppLocalizations.of(context).onboardingAvatarSubtitle),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final a in kAvatars)
                  GestureDetector(
                    onTap: () => setState(() => _avatarId = a.id),
                    child: AppAvatar(
                        avatarId: a.id, size: 64, selected: _avatarId == a.id),
                  ),
              ],
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(
                AppLocalizations.of(context).onboardingCountryTitle,
                AppLocalizations.of(context).onboardingCountrySubtitle),
            if (_countryOptions.isEmpty)
              Text(AppLocalizations.of(context).onboardingNoCountries)
            else
              InputDecorator(
                decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context).onboardingHomeCountryLabel,
                  border: const OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _country,
                    items: [
                      for (final c in _countryOptions)
                        DropdownMenuItem(value: c, child: Text(countryName(c))),
                    ],
                    onChanged: (v) => setState(() => _country = v),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).onboardingLanguageLabel,
                border: const OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Locale>(
                  isExpanded: true,
                  value: _locale,
                  items: [
                    for (final l in ProfileStore.supportedLocales)
                      DropdownMenuItem(
                        value: l,
                        child: Text(_languageAutonyms[l.languageCode] ??
                            l.languageCode),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _locale = v);
                    // Apply live so the rest of onboarding is in the chosen
                    // language; setLocale also persists the choice.
                    ProfileStore.setLocale(v);
                  },
                ),
              ),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(AppLocalizations.of(context).onboardingZooTitle,
                AppLocalizations.of(context).onboardingZooSubtitle),
            for (final z in ReferenceData.instance.zoos) _zooTile(z),
          ],
        );
    }
  }

  Widget _zooTile(Zoo z) {
    final selected = _zooId == z.id;
    return Card(
      elevation: 0,
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(selected ? Icons.check_circle : Icons.park_outlined),
        title: Text(z.name),
        subtitle: z.country.isNotEmpty ? Text(countryName(z.country)) : null,
        onTap: () => setState(() => _zooId = selected ? null : z.id),
      ),
    );
  }
}
