import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale, WidgetsBinding;
import 'package:hive_flutter/hive_flutter.dart';

import '../models/profile.dart';
import '../util/uuid.dart';
import 'reference_data.dart';

/// Reactive, persisted local profile. On first launch a permanent [Profile.userId]
/// (UUID) is generated and frozen — the seed for a future anonymous/linked
/// account (no login screen; see DESIGN §8). Onboarding fills in the display
/// name, @username, avatar and local zoo and flips [onboardingComplete].
class ProfileStore {
  ProfileStore._();

  static const String boxName = 'profile';
  static const String _key = 'profile';
  static const String _onboardedKey = 'onboardingComplete';
  static const String _localeKey = 'localeCode';

  /// The languages the app offers. Single source of truth: MaterialApp's
  /// supportedLocales, the Settings/onboarding pickers, and the catalogue
  /// overlays all key off this list. Add a locale here when its ARB and overlay
  /// files exist.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('de'),
    Locale('es'),
    Locale('cy'),
  ];

  /// Active UI + content language. Drives MaterialApp.locale; changes here
  /// rebuild the whole app. Persisted across launches.
  static final ValueNotifier<Locale> locale =
      ValueNotifier<Locale>(const Locale('en'));

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

    // Locale: a saved choice wins; otherwise default to the device language if it
    // is one we support, else English. ReferenceData is told the language by
    // main() after this, so the catalogue loads in the right language too.
    final supportedCodes = supportedLocales.map((l) => l.languageCode).toSet();
    final saved = _box.get(_localeKey);
    final String code;
    if (saved is String && supportedCodes.contains(saved)) {
      code = saved;
    } else {
      final device =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      code = supportedCodes.contains(device) ? device : 'en';
    }
    locale.value = Locale(code);
  }

  /// Change the active language: swap the catalogue overlay first (so the new
  /// strings are ready), then flip the notifier to rebuild the UI, then persist.
  static Future<void> setLocale(Locale value) async {
    final code = value.languageCode;
    if (!supportedLocales.any((l) => l.languageCode == code)) return;
    await ReferenceData.instance.applyLocale(code);
    locale.value = Locale(code);
    await _box.put(_localeKey, code);
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
