# ZooDex

ZooDex is a Flutter application for tracking the animal species a user has seen at
the zoos they visit, in the style of a collectible "dex". The species catalogue
and zoo data are bundled with the app, and a user's sightings are stored on the
device, so the app works offline. The one exception is the zoo map, which loads
OpenStreetMap tiles and therefore needs a network connection.

## Features

- Browse zoos as an interactive map or a list. The map shows a pin for each zoo
  with confirmed coordinates and centres on the user's current location.
- Browse a zoo's species inventory, search and filter it, and see how many of its
  species have been logged.
- Log a species as seen, as a no-show (looked for but not on display), or as a
  past sighting, with an optional private note.
- A "Dex" view of every species seen across all zoos, with counts and last-seen
  dates, plus list, grid, and taxonomic tree views.
- A tiered access model: three free zoos, a per-country Premium unlock, and a
  global Unlimited unlock. In-app purchases are currently simulated (see
  [In-app purchases](#in-app-purchases)).
- A first-run setup flow that collects a display name, username, avatar, home
  country, and first zoo, stored locally.

## Requirements

- Flutter, stable channel. See https://docs.flutter.dev/get-started/install and
  confirm the install with `flutter --version` and `flutter doctor`.
- An emulator, simulator, or physical device.

## Build and run

The repository contains the application source, data, and configuration, but not
the generated platform folders (`android/`, `ios/`, `web/`, and so on). These are
machine-generated and are recreated with a single command. Generating them does
not modify `lib/`, `assets/`, or `pubspec.yaml`.

```bash
flutter create .      # generate the platform folders
flutter pub get       # fetch dependencies
flutter run           # run on a connected device or emulator
```

Run `flutter analyze` to perform static analysis (lints and type checks) before
building.

The app ships with three zoos (London Zoo, Chester Zoo, and Welsh Mountain Zoo)
and a catalogue of roughly 790 species and subspecies.

## Project structure

```
lib/
  main.dart                  Entry point: initialises storage, then runs the UI.
  models/                    Plain data classes.
    species.dart             A species with its taxonomy, IUCN status, descriptions.
    zoo.dart                 A zoo, its location, geofence radius, and country.
    inventory.dart           A zoo paired with the species it holds.
    visit.dart               One zoo on one calendar day; owns that day's logs.
    species_log.dart         A seen/no-show record for one species on one visit.
    dex_entry.dart           A computed per-species summary for the Dex.
    verification.dart        Whether a visit was GPS-confirmed.
    entitlement.dart         What the user can access (free/premium/unlimited).
    profile.dart             Local profile (id, name, username, avatar).
  data/                      Storage and services.
    hive_store.dart          Opens the on-device databases at startup.
    reference_data.dart      Loads species/zoos/inventories from bundled JSON.
    visit_store.dart         Saves visits and sightings; builds the Dex.
    verification_service.dart  GPS check for presence at a zoo.
    entitlement_store.dart   Stores the plan, free unlocks, and home country.
    profile_store.dart       Stores the local profile and onboarding state.
    purchase_service.dart    The purchase/restore interface and a dev stand-in.
  screens/                   One file per screen.
  widgets/                   Reusable UI pieces.
  util/                      Helpers.
assets/data/                 Bundled species, zoos, and inventory JSON.
images/                      Species photos (named <slug>.webp) and placeholders.
docs/                        Design and reference notes.
tools/                       Build-time scripts (not shipped in the app).
```

The app distinguishes two kinds of data:

- Reference data (species, zoos, inventories, avatars) is read-only, ships in
  `assets/data/`, and is loaded by `reference_data.dart`.
- User data (visits, sightings, plan, profile) is read-write and stored on the
  device.

Key data-model points:

- Each species has a permanent opaque `id` (for example `sp_5e365fabed63`) and a
  human-readable `slug` (for example `panthera_tigris`). Sightings are keyed by
  `id`, so renaming a species, including its scientific name, does not lose
  history. `assets/data/aliases.json` maps old or merged references forward to the
  canonical `id`.
- A visit is one zoo on one calendar day. Additional sightings on the same day
  join that visit; a second zoo on the same day is a separate visit.
- A species has a short default `description`, an optional longer
  `long_description` shown on the Species-tab page, and an optional per-zoo
  `description` set on an inventory item that overrides the default on that zoo's
  page.

## Location and verification

When a sighting is logged, the app can mark the visit as "verified" if the
device's GPS confirms the user is at the zoo. Verification is a badge, not a gate:
logging is never blocked. It is only available for zoos that have real
coordinates and `coords_set: true` in `assets/data/zoos.json`; the bundled zoos
include real coordinates.

The zoo map also requests location when it opens, to centre on the user, and falls
back to framing all zoos if the request is declined.

Location access requires platform permission entries, which live in the generated
platform folders:

- Android, in `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:

  ```xml
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  ```

- iOS, in `ios/Runner/Info.plist`:

  ```xml
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Used to confirm you are at the zoo when you log a sighting.</string>
  ```

Without the iOS usage-description key, the first location request crashes on iOS.

## Species images

Each species can show a photo on its detail page. Photos live in the top-level
`images/` folder and are matched to a species by `slug`.

- To add a photo, place a file named `<slug>.webp` (or `<slug>.png`) in `images/`,
  for example `images/varanus_komodoensis.webp`. It is picked up on the next build
  with no code or JSON changes.
- A species without its own photo falls back to a per-group placeholder, then to a
  generic placeholder, so the page is never blank.

## In-app purchases

Real store purchases require products configured in App Store Connect and Google
Play, plus receipt validation. None of that is wired up, so the app uses
`DevPurchaseService`, which simulates a successful purchase and unlocks locally,
with no payment and no security. The unlock sheet shows a development-mode banner
while this stand-in is active.

This stub must not be used to ship paid features, because a local entitlement flag
can be altered on a rooted device. [`docs/GOING_LIVE_IAP.md`](docs/GOING_LIVE_IAP.md)
describes wiring a validated implementation behind the same `PurchaseService`
interface. Free unlocks remain local, as they involve no payment.

## Status and roadmap

ZooDex is in active development. The current build is offline-first with no
backend: there are no online accounts, friends, or sync. The architecture is
designed so those can be added later (see [`docs/DESIGN.md`](docs/DESIGN.md), which
describes an offline-now, online-later phasing built around a managed backend).
The local profile already carries a permanent user id intended to seed a future
anonymous or linked account.

## Documentation

- [`docs/DESIGN.md`](docs/DESIGN.md): architecture and the reasoning behind the
  data model, location verification, privacy, and monetisation.
- [`docs/GOING_LIVE_IAP.md`](docs/GOING_LIVE_IAP.md): replacing the development
  purchase stub with validated in-app purchases.
- [`docs/SUBSPECIES.md`](docs/SUBSPECIES.md): the subspecies and breed model.
- [`docs/RANGE_MAPS.md`](docs/RANGE_MAPS.md): the species range-map design (parked).
- [`tools/README.md`](tools/README.md): build-time data and image scripts.

## License

No license has been set for this repository. Add a `LICENSE` file before
distributing.
