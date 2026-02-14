import 'package:flutter/foundation.dart';
import 'hive_store.dart';

class SettingsStore {
  SettingsStore._();

  static const String _nightModeKey = 'nightMode';

  /// A ValueNotifier that holds whether night mode is enabled.
  /// Initialize by calling [init] after Hive is ready.
  static final ValueNotifier<bool> nightMode = ValueNotifier<bool>(false);

  static void init() {
    final box = HiveStore.settingsBox;
    final v = box.get(_nightModeKey, defaultValue: false) as bool;
    nightMode.value = v;

    // Persist when changed.
    nightMode.addListener(() {
      box.put(_nightModeKey, nightMode.value);
    });
  }
}
