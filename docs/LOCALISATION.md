# Localisation

ZooDex supports multiple languages. Two independent systems do the work, because
the two kinds of text have different lifecycles:

1. UI strings (buttons, labels, dialogs, onboarding) - translated once, via
   Flutter's gen-l10n / ARB toolchain.
2. Catalogue content (species common names, descriptions, group labels) - a
   large, ongoing data translation, via per-locale overlay files.

Scientific names are never translated; they are the same in every language.

Languages currently declared: English (en), French (fr), German (de),
Spanish (es), Welsh (cy). The single source of truth for the list is
`ProfileStore.supportedLocales`.

## Building

The AppLocalizations class is generated, not committed. After pulling or after
editing any ARB file:

```
flutter pub get
flutter gen-l10n
```

`generate: true` in `pubspec.yaml` also runs this on a normal build. The
generated file lands at `lib/l10n/app_localizations.dart` (configured by
`l10n.yaml`). Until it is generated, the imports of `app_localizations.dart`
will not resolve - this is expected on a fresh checkout.

## UI strings (ARB)

- Source files: `lib/l10n/app_en.arb` (the template) and `app_fr/de/es/cy.arb`.
- The non-English files currently hold English placeholder values; overwrite the
  values to translate. Keys and placeholders must stay identical across files.
- In code: `import '../l10n/app_localizations.dart';` then
  `AppLocalizations.of(context).someKey`. Parameterised strings are methods, e.g.
  `AppLocalizations.of(context).zoodexTitle(count)`.
- `of(context)` is non-null (configured by `nullable-getter: false`).
- Common words shared across screens use `common*` keys; screen-specific strings
  are prefixed by screen (e.g. `settings*`, `paywall*`, `speciesDetail*`).

To add a UI string: add the key to every `app_*.arb`, run `flutter gen-l10n`,
then use it via `AppLocalizations.of(context)`.

## Catalogue content (overlays)

- English is canonical in `assets/data/species_catalog.json`.
- Translations live in `assets/data/i18n/<locale>/species.json`, keyed by slug,
  holding only the translatable fields (`common_name`, `description`,
  `long_description`, `group`). See `assets/data/i18n/README.md`.
- `reference_data.dart` applies the active locale's overlay over the English
  catalogue (`applyLocale` / `_loadOverlay` / `Species.localized`), falling back
  to English field by field, so partial translations are fine.
- Because the species objects themselves carry the resolved text, the rest of the
  app reads `species.commonName` as usual and gets the active language for free.

These overlay files start empty. `tools/fetch_translations.py` seeds them: it
resolves each species to its Wikidata entity by scientific name (the link the
image fetcher already uses), takes the multilingual label as the common name, and
optionally the first sentence or two of the matching Wikipedia article as a
description. Run it from the project root, e.g.
`python tools/fetch_translations.py --contact "you@example.com"` (see
`tools/README.md`). The output is a seed for review, not a final translation;
Welsh coverage on Wikidata is thinner and falls back to English more often until
filled in by hand.

## Switching language

- `ProfileStore.locale` (a `ValueNotifier<Locale>`) drives `MaterialApp.locale`;
  changing it rebuilds the app. It is persisted across launches.
- First run defaults to the device language if it is supported, else English.
- Users change it in two places: the onboarding language step, and Settings ->
  Language. Both call `ProfileStore.setLocale`, which swaps the catalogue overlay
  first and then flips the notifier.
- Language names in the picker are shown as autonyms (English, Francais, Deutsch,
  Espanol, Cymraeg) and are deliberately not translated.

## Welsh framework strings

Flutter does not ship Material or Cupertino translations for Welsh (cy). The
app's own strings are translated through `app_cy.arb`; the framework widget
strings (dialog buttons, tooltips, date pickers) fall back to English via two
small delegates in `main.dart` (`_WelshMaterialLocalizations`,
`_WelshCupertinoLocalizations`). These must precede the Global delegates in the
delegate list. If Flutter later ships Welsh support, remove them.

## Adding a new language

1. Add the locale to `ProfileStore.supportedLocales`.
2. Create `lib/l10n/app_<code>.arb` (copy `app_en.arb`, change `@@locale`, then
   translate values).
3. Create `assets/data/i18n/<code>/species.json` (start from `{ "species": {} }`)
   and register the folder under `flutter: assets:` in `pubspec.yaml`.
4. Run `flutter gen-l10n`.
5. If the language is not one Flutter's Global delegates support, add fallback
   delegates like the Welsh ones in `main.dart`.

## Known remaining UI strings (follow-ups)

The IUCN category labels (`iucn_tag.dart`, via `iucnLabel`), the sort-field menu
labels (`zoodex_screen.dart`, via `_sortFieldLabel`), and the tree-of-life centre
label (`tree_view.dart`, threaded into the painter) are now localised through
ARB keys.

One thing is deliberately left in English:

- `lib/screens/profile_screen.dart`: CSV export headers and cell values are
  written to an exported data file by context-less helpers. A CSV is data rather
  than UI, and mixing languages into exported data is usually worse for
  re-import, so these stay English on purpose. Revisit if exports should follow
  the app language.

## Layout note

German and Welsh strings run longer than English. Prefer wrapping text and
flexible widths over fixed sizes so translated strings do not overflow.
