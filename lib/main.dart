import 'package:flutter/cupertino.dart' show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/entitlement_store.dart';
import 'data/hive_store.dart';
import 'data/profile_store.dart';
import 'data/reference_data.dart';
import 'data/settings_store.dart';
import 'data/visit_store.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveStore.init();
  await ReferenceData.instance.init(); // load + validate reference data once
  await VisitStore.migrateLegacySeenIfNeeded(); // one-time, no-op afterwards
  await VisitStore.normalizeSpeciesIdsIfNeeded(); // merge any merged-species ids
  EntitlementStore.init();
  await ProfileStore.init();
  // Load the catalogue in the user's saved/device language (no-op for English).
  await ReferenceData.instance.applyLocale(ProfileStore.locale.value.languageCode);
  SettingsStore.init();
  runApp(const ZooTrackerApp());
}

class ZooTrackerApp extends StatelessWidget {
  const ZooTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsStore.nightMode,
      builder: (context, night, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: ProfileStore.locale,
          builder: (context, locale, _) {
            return MaterialApp(
              onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
              theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
              darkTheme:
                  ThemeData(useMaterial3: true, brightness: Brightness.dark),
              themeMode: night ? ThemeMode.dark : ThemeMode.light,
              locale: locale,
              supportedLocales: ProfileStore.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                // Welsh fallbacks must precede the Global delegates so they win
                // for 'cy' (which the Global delegates do not support).
                _WelshMaterialLocalizations.delegate,
                _WelshCupertinoLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: ValueListenableBuilder<bool>(
                valueListenable: ProfileStore.onboardingComplete,
                builder: (context, done, _) =>
                    done ? const HomeShell() : const OnboardingScreen(),
              ),
            );
          },
        );
      },
    );
  }
}

/// Flutter does not ship Material translations for Welsh (cy). The app's own
/// strings are translated via [AppLocalizations]; this delegate supplies the
/// framework widget strings (dialog buttons, tooltips, date pickers, etc.) for
/// Welsh by reusing the English Material translations, so nothing throws.
class _WelshMaterialLocalizations {
  const _WelshMaterialLocalizations._();
  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _WelshMaterialLocalizationsDelegate();
}

class _WelshMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _WelshMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'cy';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_WelshMaterialLocalizationsDelegate old) => false;
}

/// As above, for Cupertino widgets used anywhere in the app.
class _WelshCupertinoLocalizations {
  const _WelshCupertinoLocalizations._();
  static const LocalizationsDelegate<CupertinoLocalizations> delegate =
      _WelshCupertinoLocalizationsDelegate();
}

class _WelshCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _WelshCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'cy';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.load(const Locale('en'));

  @override
  bool shouldReload(_WelshCupertinoLocalizationsDelegate old) => false;
}
