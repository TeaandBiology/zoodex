import 'package:flutter/material.dart';
import 'data/entitlement_store.dart';
import 'data/hive_store.dart';
import 'data/profile_store.dart';
import 'data/reference_data.dart';
import 'data/settings_store.dart';
import 'data/visit_store.dart';
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
        return MaterialApp(
          title: 'Species',
          theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
          darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
          themeMode: night ? ThemeMode.dark : ThemeMode.light,
          home: ValueListenableBuilder<bool>(
            valueListenable: ProfileStore.onboardingComplete,
            builder: (context, done, _) =>
                done ? const HomeShell() : const OnboardingScreen(),
          ),
        );
      },
    );
  }
}
