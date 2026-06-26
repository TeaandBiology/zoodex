# Developer tools (not shipped)

Everything in this folder is for building/maintaining ZooDex — it is **not part
of the app**. Flutter only bundles compiled Dart (`lib/`) plus the assets
declared in `pubspec.yaml` (`assets/`, `images/`), so scripts and docs here never
end up in the APK/IPA. Nothing in `tools/` needs deleting before release; it
simply doesn't ship.

(The one thing that *does* need handling before charging real money is in-app
code, not here: the placeholder in-app-purchase service in
`lib/data/purchase_service.dart` — see `docs/GOING_LIVE_IAP.md`.)

## fetch_species_images.py

Finds a representative, licence-appropriate photo for every species in the
catalogue and saves it as `images/<slug>.webp` — the exact name `SpeciesImage`
looks for. It tries several sources in order until one returns a
commercially-usable image:

1. **iNaturalist** — photographer photos (commercial-licensed only)
2. **Wikimedia Commons** — via Wikidata's "image" property (P18); everything on
   Commons is commercial-OK
3. **Openverse** — CC/PD aggregator, filtered to commercial use
4. **Flickr** — optional, only if you pass `--flickr-key`

```bash
pip install requests Pillow
# run from the project root:
python tools/fetch_species_images.py --contact "you@example.com"

# include Flickr as a last resort:
python tools/fetch_species_images.py --contact "you@example.com" \
    --sources inat,wikimedia,openverse,flickr --flickr-key YOURKEY
```

No API key is needed for iNaturalist, Wikimedia, or Openverse. Defaults: reads
`assets/data/species_catalog.json`, writes WebP into `images/` (resized to 800px,
quality 82), resumes (skips existing), and writes two reports into
`tools/reports/`:

- `image_credits.csv` — per-species **source, licence, and attribution**. Keep
  this: CC-BY / CC-BY-SA photos legally require visible credit, so it feeds an
  in-app credits screen.
- `failures.csv` — species no source could satisfy; review and fill by hand.

Licensing: it never takes "all rights reserved", NonCommercial, or NoDerivatives
photos. CC0 / public-domain need no attribution; CC-BY and CC-BY-SA do.
`--allow-noncommercial` widens to CC-BY-NC (not for a paid app). A few caveats:
Openverse/Flickr match by keyword so a wrong-species image is possible (eyeball
the results), and Flickr's CC 4.0 licence ids may need adding via
`--flickr-licenses`.

## fetch_range_maps.py

**Expert-only.** Produces a `assets/range/<slug>.webp` range map *only* where we
have a trustworthy, commercial-use-safe source. A wrong map is worse than none, so
anything without a good source is left out and falls back at runtime to the parent
species' map, then `_unavailable.png`. (iNaturalist's *modelled* ranges were
deliberately dropped — they over-predict, include captive/vagrant points, and
bleed into oceans.)

```bash
pip install requests geopandas shapely matplotlib pillow
# reptiles need the GARD file (CC0), downloaded once (see below):
python tools/fetch_range_maps.py --contact "you@example.com" \
    --gard-gpkg path/to/GARD_1_7_ranges.gpkg --sample 12
# full batch:
python tools/fetch_range_maps.py --contact "you@example.com" \
    --gard-gpkg path/to/GARD_1_7_ranges.gpkg
```

Sources (priority order), all **commercial-use-safe**:

1. **GARD 1.7** (reptiles) — CC0 expert range polygons, rendered in the app's
   house style on a Natural Earth basemap (public domain), land-clipped so nothing
   bleeds into the sea. Download once from the GARD initiative
   (<https://www.gardinitiative.org/data.html>) and pass `--gard-gpkg`.
2. **Wikimedia Commons** range-map images via Wikidata property **P181**. Pre-made
   expert maps; the script keeps only CC0 / public-domain / CC-BY / CC-BY-SA
   (commercial-OK), pulls a raster at 1100px, and records attribution. These keep
   their own cartography, so the look is less uniform than the GARD renders.

Attribution for every produced map → `assets/data/range_credits.json` (CC-BY /
CC-BY-SA require a visible credit — surface it under the map on the species page,
like photo credits). `tools/.range_cache/range_failures.csv` lists species with no
expert source. Existing `.webp` files are skipped unless `--overwrite`.

**Do NOT use** IUCN, BirdLife, eBird Status & Trends, AmphibiaWeb, or Map of Life —
all non-commercial-only and/or forbid redistribution to end users, so they can't
go in a paid app. Re-confirm licence tags and keep your download records before
release.

Subspecies: P181 occasionally has a subspecies-specific map; usually it doesn't,
and the subspecies falls back to the parent species range automatically.

## What ships vs what doesn't

- Ships: `lib/`, `assets/`, `images/` (including the real `<slug>.webp` photos
  and the `default_*.png` placeholders).
- Does not ship: `tools/` (this folder), `tools/reports/`, `docs/`.

## Delivery convention (zips from the assistant)

To avoid clobbering downloaded species photos, image assets are delivered
separately from code:

- **`zoodex_integrated.zip`** — the app, with **no `images/` folder**. Extract it
  *over* the existing project; it never touches `images/`, so your
  script-downloaded `<slug>.webp` photos are safe.
- **`zoodex_images_dropin.zip`** — only the image assets the assistant produces
  (placeholders, icons, etc.). Copy its contents into your local `images/`. New
  drops contain only new/changed files.

Because the code zip omits `images/`, it's an overlay onto an existing project,
not a standalone checkout. `pubspec.yaml` still declares `images/` as an asset
folder, so a fresh clone needs at least the placeholder PNGs present before it
builds — drop them in from the latest images zip.
