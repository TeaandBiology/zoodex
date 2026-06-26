# Range maps: status and plan

> **Status: parked.** The in-app plumbing is built and working; the data (the
> actual range images) is deferred until a consistent house style across all
> species can be produced. This note captures the context so the work can be
> picked up without re-deriving it.

## Goal

Every species page shows a geographic range map. Rules:

- Subspecies show their own range where available; otherwise they fall back to
  the parent species' range.
- Parent species show the whole-species range.
- Domestic species and breeds show a shared "no natural range, domestic animal"
  graphic (there is no wild range to draw).
- Anything with no good map shows a neutral "range not available" placeholder,
  never a blank, and never a wrong map.

## What is already built (code, keep)

The app side is done and does not need revisiting; only the images are missing.

- `lib/widgets/range_map.dart`: the `RangeMap` widget plus a full-screen zoomable
  viewer. Resolves an ordered fallback list (same mechanism as `SpeciesImage` and
  `FallbackImage`): `assets/range/<slug>.webp`, then the parent species'
  `<slug>.webp`, then `_domestic.png` (if the species is domestic), then
  `_unavailable.png`.
- `lib/screens/species_detail_screen.dart`: a "Range" section under the taxonomy
  line, driven by the displayed species, so it follows the subspecies chip
  selector automatically.
- `lib/models/species.dart`: a `domestic` bool (parsed from `domestic: true`),
  set on the domestic catalogue entries (Alpaca, Domestic Pig, Domestic Goat,
  Ferret, and their breeds). Also the long-reserved `rangeMap` field, usable as
  an explicit per-entry override.
- `assets/range/` is registered in `pubspec.yaml` and ships the two placeholders
  (`_domestic.png`, `_unavailable.png`).

**To add real maps later:** drop `assets/range/<slug>.webp` files in. No code or
catalogue changes needed.

## The hard constraint

ZooDex is a paid app, so range data must be licensed for commercial use and
redistribution to end users. That rules out the gold-standard expert ranges:

- IUCN Red List, BirdLife, eBird Status and Trends, AmphibiaWeb, and Map of Life
  are all non-commercial-only and/or forbid redistribution. Map of Life's
  commercial arm (mapoflife.ai) is enterprise-priced; IUCN's commercial route
  (IBAT) runs roughly $15k to $35k per year and is aimed at corporate reporting,
  not consumer-app redistribution.

That leaves only free, commercial-safe sources, which are rougher.

## What was tried, and why it is parked

1. **iNaturalist Open Range Maps (CC-BY).** Comprehensive, polygon, scriptable,
   but modelled from observations (a neural suitability model), so they
   over-predict into empty regions, include captive and vagrant specks, and are
   not land-masked (Komodo dragons appeared across the oceans). Not accurate
   enough.
2. **Wikimedia Commons range images via Wikidata P181 (CC-BY/CC-BY-SA).** Often
   genuinely expert and accurate, commercial-OK with attribution, but every image
   has its own cartographic style, projection, and label language, so a deck of
   them looks incoherent. This is what forced a stop: accuracy was fine,
   consistency was not.

## The actual problem to solve

One uniform house style across the whole catalogue. That means rendering the maps
from underlying geometry onto a single basemap, rather than collecting pre-made
images. The renderer already exists in `tools/fetch_range_maps.py`
(`render_range()`: Natural Earth basemap, fixed palette, land-clipped, exported
to WebP). The open question is purely the geometry source for non-reptiles.

Commercial-safe geometry options to weigh up on return:

- **GARD 1.7 (reptiles), CC0, expert polygons.** Already wired in
  (`--gard-gpkg`). Render these in the house style; this is the one taxon group
  that can be done well right now. Worth doing on its own.
- **GBIF occurrence data, CC0/CC-BY (filterable per record).** Points, not
  polygons. Two ways to use it: (a) render honest "where recorded" dot maps in
  the house style (avoids fake precision; filter out captive records); or (b)
  derive rough range polygons (alpha-hull / kernel density), which is more work
  and still approximate.
- **Self-drawn or curated polygons** for the headline species, in the house
  style. Highest quality, does not scale to roughly 785 species.
- **Natural Earth.** Public-domain basemap (already used). Not a range source.

A likely shape for "v1 done right": GARD for reptiles plus GBIF dot maps (or
curated polygons) for charismatic mammals and birds, all rendered in the single
house style, everything else left as "range not available" until filled in.
Quality and consistency over coverage.

## Decisions to make on return

- Polygons vs occurrence dots for non-reptiles (consistency and honesty vs the
  "filled range" users expect).
- Whether to hand-curate the top roughly 50 zoo headline species for quality.
- Whether to hide the "Range" section entirely until a species has a real map
  (currently it shows the `_unavailable` placeholder).
- Re-confirm every source's licence and keep download and attribution records
  before shipping (licences drift).

## Tooling

`tools/fetch_range_maps.py`: build-time only, never ships. Currently set up
"expert-only": GARD (reptiles) rendered house-style plus Wikimedia P181 images.
The GARD path and `render_range()` are the keepers; the Wikimedia-image path is
what to move away from in favour of self-rendered geometry. See `tools/README.md`.
