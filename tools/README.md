# Build and maintenance tools (not shipped)

Everything in this folder is for building and maintaining ZooDex. It is not part
of the app. Flutter bundles compiled Dart from `lib/` plus the assets declared in
`pubspec.yaml` (`assets/`, `images/`), so the scripts and reports here never end
up in the APK or IPA. Nothing in `tools/` needs deleting before release.

These scripts are run occasionally to regenerate bundled data and images. They
require Python 3 and the dependencies noted in each section.

## fetch_species_images.py

Finds a representative, licence-appropriate photo for each species in the
catalogue and saves it as `images/<slug>.webp`, the exact filename the in-app
`SpeciesImage` widget looks for. It tries several sources in order until one
returns a commercially usable image:

1. iNaturalist (photographer photos, commercial-licensed only)
2. Wikimedia Commons, via Wikidata's image property (P18); Commons content is
   commercial-OK
3. Openverse (a CC/public-domain aggregator, filtered to commercial use)
4. Flickr (optional, only when `--flickr-key` is supplied)

```bash
pip install requests Pillow
# run from the project root:
python tools/fetch_species_images.py --contact "you@example.com"

# include Flickr as a last resort:
python tools/fetch_species_images.py --contact "you@example.com" \
    --sources inat,wikimedia,openverse,flickr --flickr-key YOURKEY

# re-fetch in place at the current resolution, replacing existing files:
python tools/fetch_species_images.py --contact "you@example.com" --overwrite
```

By default the script resumes and skips any species that already has an image.
Pass `--overwrite` to re-download and replace existing files, which is how to
refresh older photos saved at the previous 800px size to the current 1400px.

No API key is needed for iNaturalist, Wikimedia, or Openverse. By default the
script reads `assets/data/species_catalog.json`, writes WebP into `images/`
(downloads the original source and resizes the longest side to 1400px at quality
82, so the species-page hero crop stays sharp on high-DPR phones), resumes (skips
existing files), and writes two reports into `tools/reports/`:

- `image_credits.csv`: per-species source, licence, and attribution. CC-BY and
  CC-BY-SA photos require visible credit, so this feeds the in-app image credits.
- `failures.csv`: species that no source could satisfy; review and fill by hand.

Licensing: the script never takes "all rights reserved", NonCommercial, or
NoDerivatives photos. CC0 and public-domain images need no attribution; CC-BY and
CC-BY-SA do. The `--allow-noncommercial` flag widens to CC-BY-NC and must not be
used for a paid app. Two caveats: Openverse and Flickr match by keyword, so a
wrong-species image is possible (check the results), and Flickr's CC 4.0 licence
ids may need adding via `--flickr-licenses`.

## fetch_range_maps.py

Expert-only. Produces a range map at `assets/range/<slug>.webp` only where a
trustworthy, commercial-use-safe source exists. A wrong map is worse than none, so
anything without a good source is left out and falls back at runtime to the parent
species' map, then to `_unavailable.png`. iNaturalist's modelled ranges were
deliberately dropped because they over-predict, include captive and vagrant
points, and bleed into the oceans. See `docs/RANGE_MAPS.md` for the full rationale.

```bash
pip install requests geopandas shapely matplotlib pillow
# reptiles need the GARD file (CC0), downloaded once (see below):
python tools/fetch_range_maps.py --contact "you@example.com" \
    --gard-gpkg path/to/GARD_1_7_ranges.gpkg --sample 12
# full batch:
python tools/fetch_range_maps.py --contact "you@example.com" \
    --gard-gpkg path/to/GARD_1_7_ranges.gpkg
```

Sources, in priority order, all commercial-use-safe:

1. GARD 1.7 (reptiles): CC0 expert range polygons, rendered in the app's house
   style on a Natural Earth basemap (public domain), land-clipped so nothing
   bleeds into the sea. Download once from the GARD initiative
   (<https://www.gardinitiative.org/data.html>) and pass `--gard-gpkg`.
2. Wikimedia Commons range-map images via Wikidata property P181: pre-made expert
   maps. The script keeps only CC0, public-domain, CC-BY, and CC-BY-SA images,
   pulls a raster at 1100px, and records attribution. These keep their own
   cartography, so the look is less uniform than the GARD renders.

Attribution for every produced map is written to
`assets/data/range_credits.json` (CC-BY and CC-BY-SA require a visible credit,
surfaced under the map on the species page like photo credits).
`tools/.range_cache/range_failures.csv` lists species with no expert source.
Existing `.webp` files are skipped unless `--overwrite` is passed.

Do not use IUCN, BirdLife, eBird Status and Trends, AmphibiaWeb, or Map of Life:
all are non-commercial-only and/or forbid redistribution to end users, so they
cannot ship in a paid app. Re-confirm licence tags and keep download records
before release.

Subspecies: P181 occasionally has a subspecies-specific map; usually it does not,
and the subspecies falls back to the parent species range automatically.

## fetch_translations.py

Seeds the per-language catalogue overlays at `assets/data/i18n/<locale>/species.json`
with translated common names (and optional short descriptions), so the catalogue
can be translated without typing each name by hand. For each species it resolves
the Wikidata entity by scientific name (property P225, the same link the image
fetcher uses), reads the multilingual label as the common name, and optionally
takes the first sentence or two of the matching Wikipedia article as a
description.

```bash
pip install requests
# run from the project root:
python tools/fetch_translations.py --contact "you@example.com"

# names only, specific languages:
python tools/fetch_translations.py --contact "you@example.com" \
    --langs fr,de --no-descriptions

# re-fetch and overwrite; quick test on 20 species:
python tools/fetch_translations.py --contact "you@example.com" \
    --overwrite --sample 20
```

It resumes by default (a species already present in a language file is skipped
unless `--overwrite`), and prints per-language coverage plus any species with no
Wikidata match. The result is a SEED for review, not a final translation: machine
labels and article snippets should be checked, and Welsh (cy) coverage on
Wikidata is thin, so it will be sparse and fall back to English in the app. No
API key is needed. See `docs/LOCALISATION.md` for how the overlays are consumed.

## What ships, and what does not

- Ships: `lib/`, `assets/`, and `images/` (the `<slug>.webp` photos and the
  `default_*.png` placeholders).
- Does not ship: `tools/` (this folder), `tools/reports/`, and `docs/`.
  `tools/reports/` and the generated platform folders are also git-ignored.
