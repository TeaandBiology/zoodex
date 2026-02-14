import 'package:flutter/material.dart';
import 'data/hive_store.dart';
import 'data/settings_store.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveStore.init();
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
          home: const HomeShell(),
        );
      },
    );
  }
}
