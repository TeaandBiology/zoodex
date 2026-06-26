import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/profile.dart';
import '../util/uuid.dart';

/// Reactive, persisted local profile. On first launch a permanent [Profile.userId]
/// (UUID) is generated and frozen — the seed for a future anonymous/linked
/// account (no login screen; see DESIGN §8). Onboarding fills in the display
/// name, @username, avatar and local zoo and flips [onboardingComplete].
class ProfileStore {
  ProfileStore._();

  static const String boxName = 'profile';
  static const String _key = 'profile';
  static const String _onboardedKey = 'onboardingComplete';

  static final ValueNotifier<Profile> current = ValueNotifier<Profile>(
    Profile.initial(DateTime.fromMillisecondsSinceEpoch(0)),
  );

  /// Whether first-run onboarding has been completed. The app shows the
  /// onboarding flow until this is true.
  static final ValueNotifier<bool> onboardingComplete =
      ValueNotifier<bool>(false);

  static Box get _box => Hive.box(boxName);

  static Future<void> init() async {
    final raw = _box.get(_key);
    if (raw is Map) {
      var p = Profile.fromMap(raw);
      if (p.userId.isEmpty) {
        // Migrate an older profile that predates the user id.
        p = p.copyWith(userId: uuidV4());
        await _box.put(_key, p.toMap());
      }
      current.value = p;
    } else {
      final created = Profile.initial(DateTime.now(), userId: uuidV4());
      current.value = created;
      await _box.put(_key, created.toMap());
    }
    onboardingComplete.value = _box.get(_onboardedKey, defaultValue: false) as bool;
  }

  static Future<void> save(Profile profile) async {
    current.value = profile;
    await _box.put(_key, profile.toMap());
  }

  static Future<void> completeOnboarding() async {
    onboardingComplete.value = true;
    await _box.put(_onboardedKey, true);
  }

  /// Dev: re-show the first-run flow. The permanent [Profile.userId] is kept.
  static Future<void> resetOnboarding() async {
    onboardingComplete.value = false;
    await _box.put(_onboardedKey, false);
  }
}
