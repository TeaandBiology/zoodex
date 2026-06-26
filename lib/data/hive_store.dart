import 'package:hive_flutter/hive_flutter.dart';

class HiveStore {
  HiveStore._();

  static const String seenBoxName = 'seen'; // legacy; kept for one-time migration
  static const String settingsBoxName = 'settings';
  static const String visitsBoxName = 'visits';
  static const String entitlementBoxName = 'entitlement';
  static const String profileBoxName = 'profile';
  static const String reportsBoxName = 'reports';

  static bool _initialised = false;

  /// Call once at app startup (main()).
  static Future<void> init() async {
    if (_initialised) return;
    await Hive.initFlutter();

    await Hive.openBox(seenBoxName);
    await Hive.openBox(settingsBoxName);
    await Hive.openBox(visitsBoxName);
    await Hive.openBox(entitlementBoxName);
    await Hive.openBox(profileBoxName);
    await Hive.openBox(reportsBoxName);

    _initialised = true;
  }

  static Box get seenBox => Hive.box(seenBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
  static Box get visitsBox => Hive.box(visitsBoxName);
  static Box get entitlementBox => Hive.box(entitlementBoxName);
  static Box get profileBox => Hive.box(profileBoxName);
  static Box get reportsBox => Hive.box(reportsBoxName);

  static Future<void> close() async {
    await Hive.close();
    _initialised = false;
  }
}
