import 'package:hive_flutter/hive_flutter.dart';

class HiveStore {
  HiveStore._();

  static const String seenBoxName = 'seen';
  static const String settingsBoxName = 'settings';

  static bool _initialised = false;

  /// Call once at app startup (main()).
  static Future<void> init() async {
    if (_initialised) return;
    await Hive.initFlutter();

    // Open all boxes your app needs here.
    await Hive.openBox(seenBoxName);
    await Hive.openBox(settingsBoxName);

    _initialised = true;
  }

  /// Typed convenience getter for the seen box.
  static Box get seenBox => Hive.box(seenBoxName);

  /// Typed convenience getter for the settings box.
  static Box get settingsBox => Hive.box(settingsBoxName);

  /// Optional: close all boxes (rarely needed on mobile).
  static Future<void> close() async {
    await Hive.close();
    _initialised = false;
  }
}
