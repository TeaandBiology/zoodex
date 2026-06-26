# On-demand species/zoo images (design sketch)

Status: design only — nothing here is built yet. This is the plan for when the
catalogue outgrows bundling every image (roughly: once thousands of species make
the asset bundle too large to ship).

## Why

Bundling photos works fine for a curated few hundred species. At thousands,
even WebP at ~30–60 KB each adds up to hundreds of MB, which exceeds Android's
base-module size limit and bloats installs. The field-guide answer (e.g. Merlin)
is to ship the app with placeholders only, then download real photos on demand
and cache them on the device — fetching just what each user actually looks at,
plus whatever they choose to pin for offline use.

This must stay offline-first: a cached image works with no signal, and anything
not cached degrades gracefully to the bundled per-group placeholder rather than
erroring or showing blank space.

## The one place that changes

All photo loading already funnels through `FallbackImage`, with `SpeciesImage`
and `ZooImage` as thin wrappers that build the lookup list. Going remote is a
change to those three files only — no screen touches.

Resolution order per image, in remote mode:

1. Show the bundled placeholder immediately (per-group PNG for species,
   `default_zoo.png` for zoos) so there's never blank space while loading.
2. If a bundled photo asset exists for this item (an optional "starter pack",
   see below), use it and stop — no network.
3. Otherwise hand off to the cache layer: serve from the on-device cache if
   present (instant, works offline); if absent and online, download, cache, show.
4. On any failure (offline + uncached, 404, or "no photo exists"), keep showing
   the placeholder.

## Remote layout

Static object storage (S3 / R2 / GCS) behind a CDN, serving immutable files.
Two size variants so the grid isn't pulling full-res images:

```
/species/<id>/thumb.webp     ~320px  — used by the Species grid + list
/species/<id>/large.webp    ~1024px  — used by the detail hero
/zoos/<id>/banner.webp      ~1280px  — used by the zoo page
```

Key the remote path by the **permanent `id`** (e.g. `sp_9d1dd38b5ee0`), not the
slug. Slugs can change when taxonomy is corrected (the app already treats `id`
as canonical and keeps `aliases.json` for that reason); ids never do, so the URL
stays stable and the cache never goes stale for the wrong reason. The downloader
script already has both fields — when populating the bucket it would name files
by `id` instead of `slug`.

## Image manifest

A small remote manifest (or an extension of the existing `manifest.json`),
keyed by id, telling the app what exists before it makes any request:

```json
{
  "sp_9d1dd38b5ee0": {
    "v": "a1b2c3",                       // content hash → cache-busting
    "license": "CC-BY-NC",
    "attribution": "(c) Jane Doe, some rights reserved (CC-BY-NC)"
  }
}
```

Benefits:
- `has image?` — species absent from the manifest never trigger a futile fetch;
  they just show the placeholder forever.
- Cache-busting — the version hash is appended (`?v=a1b2c3`) so an updated photo
  invalidates the old cached copy without guesswork.
- Attribution travels with the image. CC-BY / CC-BY-SA legally require visible
  credit, so the detail page shows `attribution` under the photo. This is the
  in-app home for the `image_credits.csv` the downloader produces.

The manifest is small (a few hundred KB even at thousands of species) and can be
bundled and refreshed periodically, so the app knows the photo landscape offline.

## Caching: ephemeral vs pinned

Two tiers, because "the photo I happened to scroll past" and "the photos I need
at the zoo tomorrow with no signal" have different lifetimes.

- Ephemeral cache: normal browsing. LRU eviction with a size cap (e.g. 300–500 MB)
  and a stale window. The OS/cache manager can reclaim it freely.
- Pinned packs: when a user picks "Download for offline" on a zoo, that zoo's
  whole species inventory is prefetched into a separate store that is *not*
  auto-evicted, with a visible size and a "remove" control (mirrors Merlin's
  per-region packs and your existing per-zoo model).

In Flutter this maps cleanly onto `flutter_cache_manager`: the default manager
for the ephemeral tier, and a second `CacheManager` instance with its own key
and a long stale period for pinned packs.

## Prefetch is the important UX bit

People are frequently offline *at the venue* — exactly where the GPS
verification and species logging happen. So the moment that matters is before
arrival, on Wi-Fi. Surface a "Download images for this zoo" action on the zoo
page that precaches the inventory's `thumb` + `large` variants into a pinned
pack. Respect metered connections / data-saver: prefetch on Wi-Fi by default,
and never bulk-download on cellular without an explicit tap.

## The code change, concretely

Add `cached_network_image` (which sits on `flutter_cache_manager`). `SpeciesImage`
keeps its current API; only its `build` changes — instead of a list of asset
paths it returns a remote-aware widget whose placeholder/error is today's
per-group asset:

```dart
// sketch — not wired yet
Widget build(BuildContext context) {
  final placeholder = _groupDefaults[species.majorGroup] ?? _ultimate;
  final entry = ImageManifest.instance.lookup(species.id); // null => no photo
  if (entry == null) {
    return Image.asset(placeholder, height: height, width: double.infinity, fit: fit);
  }
  return CachedNetworkImage(
    imageUrl: '${ImageConfig.base}/species/${species.id}/large.webp?v=${entry.v}',
    height: height, width: double.infinity, fit: fit,
    placeholder: (_, __) => Image.asset(placeholder, height: height, width: double.infinity, fit: fit),
    errorWidget: (_, __, ___) => Image.asset(placeholder, height: height, width: double.infinity, fit: fit),
    cacheManager: ImageConfig.manager, // ephemeral or pinned
  );
}
```

A single `ImageConfig.mode` flag (`bundled` | `remote`) lets the two approaches
coexist during the transition, and lets you keep bundling a small "starter pack"
(e.g. the free three zoos' species) as assets so a fresh install looks complete
before anything is downloaded.

## Backend

Object storage + CDN serving immutable `<id>/<size>.webp` files plus the
manifest. The existing `fetch_inat_images.py` already produces exactly these
files (point `--out` at an upload staging folder, switch naming to `id`, generate
both a thumb and a large pass), so the pipeline that fills the bucket is mostly
in hand. Because images are fetched on demand and cached, CDN egress scales with
*usage*, not catalogue size, and the thumbnail tier keeps the common case cheap.

## Suggested phasing

1. Stand up the bucket + CDN + manifest; flip `SpeciesImage`/`ZooImage` to remote
   with placeholder fallback; add the ephemeral cache cap.
2. Add per-zoo "Download for offline" prefetch + the pinned-pack cache manager.
3. Show attribution on the detail page from the manifest; add Wi-Fi-only /
   data-saver handling and cache-size/clear controls in Settings.

## Open decisions

- Whether to bundle a small starter pack at all, or ship placeholders only.
- Thumbnail dimensions (320px is a starting guess for a 3-column grid).
- Manifest delivery: bundled-and-refreshed vs always-fetched-then-cached.
- Whether pinned packs follow zoo unlock/entitlement or are independent.
