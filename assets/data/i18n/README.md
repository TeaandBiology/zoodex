# Catalogue content overlays

These files translate the catalogue's free-text fields. English lives in
`assets/data/species_catalog.json` and is the canonical source; each language
here overrides only the fields it provides, falling back to English field by
field. Scientific names are never translated.

## Format

`<locale>/species.json`, keyed by species slug:

```json
{
  "species": {
    "ailurus_fulgens": {
      "common_name": "Panda roux",
      "description": "Petit mammifere arboricole de l'Himalaya...",
      "long_description": "...",
      "group": "..."
    }
  }
}
```

Translatable fields: `common_name`, `description`, `long_description`, `group`.
Any field you omit keeps the English text, so partial translations are fine.

## Adding a language

1. Create `assets/data/i18n/<locale>/species.json` (start from `{ "species": {} }`).
2. Register the folder under `flutter: assets:` in `pubspec.yaml`.
3. Add the locale to `ProfileStore.supportedLocales` and to the UI ARB files in
   `lib/l10n/`.

The loader (`reference_data.dart`, `_loadOverlay` / `applyLocale`) picks these up
automatically; no other code changes are needed.

## Populating

These start empty. The planned `tools/fetch_translations.py` will seed
`common_name` (and where possible `description`) from Wikidata's multilingual
labels and Wikipedia extracts, using the same Wikidata link the image fetcher
already resolves. Welsh (cy) coverage on Wikidata is thinner, so it will fall
back to English more often until filled in by hand.
