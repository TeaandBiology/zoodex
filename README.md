# ZooDex

A Flutter app for tracking which animal species you've seen at the zoos you
visit — a bit like a Pokédex for real zoo animals. It works fully offline: all
the species and zoo data ships inside the app, and your sightings are stored on
your device.

This README assumes you've never seen the project before.

---

## 1. What you need

- **Flutter** (stable channel). Install it from
  https://docs.flutter.dev/get-started/install and confirm with:
  ```bash
  flutter --version
  flutter doctor
  ```
- An emulator/simulator or a physical device to run on.

## 2. Run it

This archive contains the app's source code, data, and configuration, but **not**
the platform folders (`android/`, `ios/`, etc.). Those are machine-generated, so
you create them once with a single command:

```bash
cd zoodex

# 1. Generate the platform folders (android/ios/web/…). This does NOT touch
#    lib/, assets/, or pubspec.yaml — your code is preserved.
flutter create .

# 2. Fetch dependencies.
flutter pub get

# 3. Run on a connected device or emulator.
flutter run
```

That's it — the app launches with two demo zoos (London Zoo and Chester Zoo) and
a catalog of ~377 species.

> Tip: `flutter analyze` runs the static analyzer (lints + type checks). It's the
> quickest way to catch anything before running.

## 3. Try out the features

- **Zoos tab** — opens on a **Map** by default (toggle to **List** top-right).
  The map centres on your current location and drops a pin on every zoo with
  confirmed coordinates (`coords_set: true`); tap a pin to open that zoo. Pan and
  zoom freely, or tap the locate button to re-centre on yourself. Map tiles come
  from OpenStreetMap, so the map (unlike the rest of the app) needs an internet
  connection; zoos without real coordinates simply don't appear on it. Pick a
  zoo from either view. The first three zoos are free to unlock; tap a
  locked zoo to open the unlock sheet (free unlock / Premium / Unlimited).
  Purchases are **simulated** for now (see "Payments" below), so you can test the
  whole flow without spending anything.
- **Inside a zoo** — search/filter the species list; the title shows how many
  you've seen out of the total.
- **A species** — tap one, then **Seen Now**, **No-show** (you looked but it
  wasn't out), or **Log a past sighting**. Add an optional private note. Your
  history shows underneath.
- **Species tab** — your "Dex": every species you've seen, across all zoos, with
  counts and last-seen dates.
- **Settings tab** — night mode, your home country (set once; used by the
  Premium plan), your current plan, Restore purchases, and a developer-only
  "Reset entitlements" button.

## 4. How the project is organised

```
lib/
  main.dart                  App entry point; initialises storage then runs the UI.
  models/                    Plain data classes (no logic/UI).
    species.dart             A species + its taxonomy and IUCN status.
    zoo.dart                 A zoo, its location, geofence radius, and country.
    inventory.dart           A zoo paired with the species living there.
    visit.dart               One zoo on one calendar day; owns that day's logs.
    species_log.dart         "Seen" or "No-show" for one species on one visit.
    dex_entry.dart           A computed per-species summary for the Dex.
    verification.dart        Whether a visit was GPS-confirmed.
    entitlement.dart         What the user can access (free/premium/unlimited).
    store_product.dart       A purchasable product + purchase result.
  data/                      Storage and "services" (the app's brain).
    hive_store.dart          Opens the on-device databases at startup.
    settings_store.dart      Night-mode preference.
    reference_data.dart      Loads species/zoos/inventories from the bundled JSON.
    visit_store.dart         Saves visits & sightings; builds the Dex; migrates old data.
    verification_service.dart  GPS check that you're actually at the zoo.
    entitlement_store.dart   Stores the user's plan and free unlocks.
    purchase_service.dart    The buy/restore interface (+ a dev stand-in).
  screens/                   One file per screen.
  widgets/                   Tiny reusable UI pieces (chip, badge, error view, species image).
  util/                      Date formatting helpers.
assets/data/                 The bundled species, zoos, and inventory JSON.
images/                      Species photos (named <slug>.png) + default.png placeholder.
docs/                        Deeper design notes (see below).
```

A useful mental model: the app has two kinds of data.

- **Reference data** (species, zoos, what lives where) is read-only, ships in
  `assets/data/`, and is loaded by `reference_data.dart`.
- **User data** (your visits, sightings, plan) is read-write and stored on the
  device by `visit_store.dart` and `entitlement_store.dart`.

A couple of design points worth knowing:

- **Species have a stable `id` and a readable `slug`.** The `id` (e.g.
  `sp_5e365fabed63`) never changes and is what your sightings are saved against,
  so renaming a species — even its scientific name — never loses your history.
  The `slug` (e.g. `panthera_tigris`) is just a human-friendly label used inside
  the data files. The `aliases.json` file maps old names forward to the right id.
- **A "visit" is one zoo on one day.** Logging more sightings the same day adds to
  the same visit; visiting a second zoo the same day is a separate visit. There's
  no start/stop button.

## 5. Location verification

When you log a sighting, the app can mark that visit "verified" if your phone's
GPS shows you're actually at the zoo. **This stays switched off until you give
each zoo real coordinates.** The two demo zoos ship with placeholder coordinates
(`0,0`, `coords_set: false`), so verification is simply skipped and the app never
even asks for location permission — handy for testing.

To turn it on for a zoo, edit `assets/data/zoos.json`:

```json
{
  "id": "london_zoo",
  "name": "London Zoo",
  "location": { "lat": 51.5353, "lng": -0.1534 },
  "radius_m": 450,
  "coords_set": true,
  "country": "GB",
  "last_updated": "2026-02-15"
}
```

The **Zoos map** (default view) also asks for location when it opens, to centre
on you — it falls back to framing all the zoos if you decline. So the app now
requests location on first launch; make sure the platform permission keys below
are in place or that request will crash on iOS.

Once any zoo uses real coordinates, the app will request location at log time, so
add the platform permissions (these files exist after `flutter create .`):

- **Android** — in `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:
  ```xml
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  ```
- **iOS** — in `ios/Runner/Info.plist`:
  ```xml
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Used to confirm you're at the zoo when you log a sighting.</string>
  ```

## 6. Species images

Each species shows a photo on its detail page. Images live in the top-level
`images/` folder and are matched to a species by its `slug` (the readable id in
`assets/data/species_catalog.json`, e.g. `varanus_komodoensis`).

- To give a species a photo, drop a PNG named `<slug>.png` into `images/`
  (e.g. `images/varanus_komodoensis.png`). It appears automatically on the next
  build — no code or JSON changes needed.
- Any species without its own file shows `images/default.png`, so there's never
  a blank. The `default.png` included here is a plain placeholder; replace it
  with your own if you like.

(If you'd added an `images/` folder somewhere else, use this top-level one — it's
the folder declared to Flutter in `pubspec.yaml`.)

## 7. Payments (important)

Real app-store purchases need products configured in App Store Connect / Google
Play plus a way to verify receipts. None of that is wired up yet, so the app uses
**`DevPurchaseService`**, which *pretends* a purchase succeeded and unlocks
locally — with **no payment and no security**. The unlock sheet shows a
"development mode" banner while this is active.

Do **not** ship paid features on this stub: a local "you paid" flag can be edited
on a rooted device. When you're ready to charge, follow
[`docs/GOING_LIVE_IAP.md`](docs/GOING_LIVE_IAP.md), which walks through wiring a
validated implementation (RevenueCat is the recommended, no-backend path) behind
the same `PurchaseService` interface. (Free unlocks staying local is fine — they
involve no money.)

## 8. Good to know / next steps

- This code was assembled carefully but **hasn't been compiled here**, so run
  `flutter analyze` and `flutter run` first and fix anything they report. Two
  version-sensitive spots to watch: the `getCurrentPosition(...)` call in
  `verification_service.dart` and the `PopScope` callback in `home_shell.dart` —
  both target current Flutter/geolocator APIs.
- Most species descriptions are currently empty — a data backlog item, not a bug.
- There's no online backend yet (no accounts, friends, or syncing). The code is
  structured so that can be added later without a rewrite.

## 9. Further reading

- [`docs/DESIGN.md`](docs/DESIGN.md) — the architecture and the reasoning behind
  the data model, verification, privacy, and monetisation choices.
- [`docs/GOING_LIVE_IAP.md`](docs/GOING_LIVE_IAP.md) — how to replace the
  development purchase stub with real, validated in-app purchases.
