import 'package:flutter/foundation.dart';
import 'hive_store.dart';

/// Stores user preferences. Right now that's only the night-mode toggle, kept in
/// the on-device 'settings' box so it survives app restarts.
class SettingsStore {
  SettingsStore._();

  static const String _nightModeKey = 'nightMode';

  /// Whether dark mode is on. The app listens to this and rebuilds when it
  /// changes (see `main.dart`).
  static final ValueNotifier<bool> nightMode = ValueNotifier<bool>(false);

  /// Loads the saved preference and starts persisting changes.
  /// Call once at startup, after [HiveStore.init].
  static void init() {
    final box = HiveStore.settingsBox;
    nightMode.value = box.get(_nightModeKey, defaultValue: false) as bool;
    nightMode.addListener(() => box.put(_nightModeKey, nightMode.value));
  }
}
