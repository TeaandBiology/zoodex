#!/usr/bin/env python3
"""Generate species range maps for ZooDex — EXPERT-ONLY edition.

Philosophy: ship a range map only when we have a trustworthy, commercial-use-safe
source. A wrong map is worse than none — anything we can't source well is simply
left out, and the app falls back to the parent species' map, then to
``assets/range/_unavailable.png``.

Sources (in priority order), all safe for a PAID app:

  1. GARD 1.7 (reptiles) — CC0, expert-drawn reptile range polygons. Rendered in
     the app's house style. Download once (Dryad) and pass --gard-gpkg.
     https://www.gardinitiative.org/data.html
  2. Wikimedia Commons range-map images via Wikidata property P181 ("taxon range
     map image"). Pre-made expert maps; we keep only CC0 / public-domain / CC-BY /
     CC-BY-SA (commercial-OK) and record attribution. Saved as-is (their own
     cartography), rasterised to WebP at a fixed width.

Deliberately NOT used: iNaturalist's *modelled* ranges (over-predict, include
captive/vagrant points, bleed into oceans), and IUCN / BirdLife / eBird / Map of
Life (non-commercial / no-redistribution — illegal in a paid app).

Output: ``assets/range/<slug>.webp`` (the filename the in-app RangeMap widget
wants). Attribution for every produced map → ``assets/data/range_credits.json``
(CC-BY/CC-BY-SA require visible credit — surface it on the species page). A
``range_failures.csv`` lists everything with no good source.

Usage (from the repo root or tools/):

    pip install requests geopandas shapely matplotlib pillow
    # reptiles need the GARD file (CC0), downloaded once:
    python tools/fetch_range_maps.py --contact "you@example.com" \
        --gard-gpkg path/to/GARD_1_7_ranges.gpkg --sample 12
    # full batch:
    python tools/fetch_range_maps.py --contact "you@example.com" \
        --gard-gpkg path/to/GARD_1_7_ranges.gpkg

Build-time tool; never ships in the app (see tools/README.md).
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import re
import sys
import time
from pathlib import Path
from urllib.parse import unquote

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

# ----------------------------------------------------------------------------
# House style (for the polygons we render ourselves — i.e. GARD).
# ----------------------------------------------------------------------------
LAND_FILL = "#E8E4DA"
LAND_EDGE = "#FFFFFF"
WATER = "#F2F6F8"
RANGE_FILL = "#2E7D5B"
RANGE_EDGE = "#1B5E40"
RANGE_ALPHA = 0.72
FIG_W, FIG_H, DPI = 10.0, 6.0, 110
PAD_FRAC = 0.18
WEBP_QUALITY = 82
WIKIMEDIA_WIDTH = 1100  # px raster pulled from Commons

NE_URL = ("https://naturalearth.s3.amazonaws.com/"
          "110m_cultural/ne_110m_admin_0_countries.zip")
WIKIDATA_SPARQL = "https://query.wikidata.org/sparql"
COMMONS_API = "https://commons.wikimedia.org/w/api.php"

REPTILE_CLASSES = {"Reptilia", "Squamata", "Testudines", "Crocodylia",
                   "Sphenodontia", "Rhynchocephalia"}


# ----------------------------------------------------------------------------
# Basemap + rendering (used for GARD polygons)
# ----------------------------------------------------------------------------
def load_basemap(cache_dir: Path, basemap_path: str | None):
    import geopandas as gpd
    if basemap_path:
        return gpd.read_file(basemap_path).to_crs(4326)
    cached = cache_dir / "ne_110m_admin_0_countries.zip"
    if cached.exists():
        return gpd.read_file(f"zip://{cached}").to_crs(4326)
    try:
        return gpd.read_file(
            gpd.datasets.get_path("naturalearth_lowres")).to_crs(4326)
    except Exception:
        pass
    import requests
    cache_dir.mkdir(parents=True, exist_ok=True)
    print(f"  downloading Natural Earth basemap → {cached}")
    r = requests.get(NE_URL, timeout=60)
    r.raise_for_status()
    cached.write_bytes(r.content)
    return gpd.read_file(f"zip://{cached}").to_crs(4326)


def render_range(world, land, geom, out_path: Path):
    """Render a (multi)polygon range onto the basemap in the house style."""
    import geopandas as gpd
    from PIL import Image

    # Clip to land so nothing bleeds into the ocean.
    if land is not None:
        try:
            clipped = geom.intersection(land)
            if not clipped.is_empty:
                geom = clipped
        except Exception:
            pass

    fig, ax = plt.subplots(figsize=(FIG_W, FIG_H), dpi=DPI)
    fig.patch.set_facecolor(WATER)
    ax.set_facecolor(WATER)
    world.plot(ax=ax, color=LAND_FILL, edgecolor=LAND_EDGE, linewidth=0.3)
    gpd.GeoSeries([geom], crs=4326).plot(
        ax=ax, color=RANGE_FILL, edgecolor=RANGE_EDGE,
        linewidth=0.6, alpha=RANGE_ALPHA)

    minx, miny, maxx, maxy = geom.bounds
    px = max((maxx - minx) * PAD_FRAC, 4.0)
    py = max((maxy - miny) * PAD_FRAC, 4.0)
    ax.set_xlim(max(-180, minx - px), min(180, maxx + px))
    ax.set_ylim(max(-90, miny - py), min(90, maxy + py))
    ax.set_aspect("equal")
    ax.set_axis_off()
    fig.subplots_adjust(left=0, right=1, top=1, bottom=0)

    buf = io.BytesIO()
    fig.savefig(buf, format="png", facecolor=WATER, bbox_inches="tight",
                pad_inches=0)
    plt.close(fig)
    buf.seek(0)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    Image.open(buf).convert("RGB").save(
        out_path, "WEBP", quality=WEBP_QUALITY, method=6)


# ----------------------------------------------------------------------------
# GARD (reptiles, CC0)
# ----------------------------------------------------------------------------
def load_gard(path: str | None):
    if not path:
        return None
    import geopandas as gpd
    from shapely.ops import unary_union
    gdf = gpd.read_file(path).to_crs(4326)
    name_col = next((c for c in ("Binomial", "binomial", "BINOMIAL", "species",
                                 "sci_name", "SCINAME") if c in gdf.columns), None)
    if name_col is None:
        print(f"  GARD: no recognised name column in {list(gdf.columns)}; "
              "skipping GARD")
        return None
    idx: dict[str, list] = {}
    for _, row in gdf.iterrows():
        nm = str(row[name_col]).replace("_", " ").strip().lower()
        if row.geometry is not None:
            idx.setdefault(nm, []).append(row.geometry)
    return {nm: unary_union(gs) for nm, gs in idx.items()}


# ----------------------------------------------------------------------------
# Wikimedia Commons range-map images (via Wikidata P181)
# ----------------------------------------------------------------------------
def license_ok(lic: str) -> bool:
    s = (lic or "").lower()
    if "nc" in s or "noncommercial" in s or "non-commercial" in s:
        return False
    if "nd" in s or "noderiv" in s:
        return False
    return any(k in s for k in ("cc0", "public domain", "pdm", "cc by",
                                "cc-by", "attribution"))


def wikimedia_rangemap(session, sci_name: str):
    """Return (thumb_url, license, attribution, filename) for a species' P181
    range-map image with a commercial-OK licence, or None."""
    q = ('SELECT ?img WHERE { ?t wdt:P225 "%s"; wdt:P181 ?img. } LIMIT 1'
         % sci_name.replace('"', ""))
    try:
        r = session.get(WIKIDATA_SPARQL, params={"query": q, "format": "json"},
                        headers={"Accept": "application/sparql-results+json"},
                        timeout=40)
        r.raise_for_status()
        bindings = r.json()["results"]["bindings"]
    except Exception as e:
        print(f"    wikidata query failed: {e}")
        return None
    if not bindings:
        return None
    fname = unquote(bindings[0]["img"]["value"].split("Special:FilePath/")[-1])

    try:
        r = session.get(COMMONS_API, params={
            "action": "query", "format": "json", "titles": f"File:{fname}",
            "prop": "imageinfo", "iiprop": "url|extmetadata",
            "iiurlwidth": WIKIMEDIA_WIDTH}, timeout=40)
        r.raise_for_status()
        page = next(iter(r.json()["query"]["pages"].values()))
        ii = page["imageinfo"][0]
    except Exception as e:
        print(f"    commons lookup failed for {fname!r}: {e}")
        return None

    meta = ii.get("extmetadata", {})
    lic = meta.get("LicenseShortName", {}).get("value", "")
    if not license_ok(lic):
        print(f"    skipped non-commercial image ({lic or 'unknown licence'})")
        return None
    artist = re.sub("<[^>]+>", "", meta.get("Artist", {}).get("value", "")).strip()
    thumb = ii.get("thumburl") or ii.get("url")
    return thumb, lic, artist, fname


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
def is_reptile(sp: dict) -> bool:
    return (sp.get("taxonomy", {}) or {}).get("class") in REPTILE_CLASSES


def main():
    ap = argparse.ArgumentParser(description="Generate ZooDex range maps (expert-only).")
    ap.add_argument("--catalog", default="assets/data/species_catalog.json")
    ap.add_argument("--out", default="assets/range")
    ap.add_argument("--cache", default="tools/.range_cache")
    ap.add_argument("--credits", default="assets/data/range_credits.json")
    ap.add_argument("--contact", required=True,
                    help="Your email — sent as the API User-Agent (required by "
                         "Wikidata/Commons).")
    ap.add_argument("--sources", default="gard,wikimedia",
                    help="Comma list in priority order: gard,wikimedia.")
    ap.add_argument("--gard-gpkg", default=None,
                    help="Path to the GARD reptile ranges file (CC0).")
    ap.add_argument("--basemap", default=None)
    ap.add_argument("--sample", type=int, default=0)
    ap.add_argument("--only", default=None, help="Comma list of slugs.")
    ap.add_argument("--overwrite", action="store_true")
    ap.add_argument("--throttle", type=float, default=0.5,
                    help="Seconds between network calls (be polite).")
    args = ap.parse_args()

    import requests

    root = Path(__file__).resolve().parent.parent

    def rp(p):
        p = Path(p)
        return p if p.is_absolute() else root / p

    out_dir = rp(args.out)
    cache_dir = rp(args.cache)
    credits_path = rp(args.credits)
    basemap_path = str(rp(args.basemap)) if args.basemap else None
    sources = [s.strip() for s in args.sources.split(",") if s.strip()]

    catalog = json.loads(rp(args.catalog).read_text(encoding="utf-8"))
    only = set(args.only.split(",")) if args.only else None
    todo = [s for s in catalog
            if not s.get("domestic") and s.get("slug") and s.get("scientific_name")
            and (only is None or s["slug"] in only)]
    if args.sample:
        todo = todo[:args.sample]

    session = requests.Session()
    session.headers.update({
        "User-Agent": f"ZooDex range-map build ({args.contact})",
        "Accept": "application/json",
    })
    from requests.adapters import HTTPAdapter
    from urllib3.util.retry import Retry
    session.mount("https://", HTTPAdapter(max_retries=Retry(
        total=4, connect=4, read=4, backoff_factor=1.0,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=frozenset(["GET"]))))

    # Basemap + land mask only needed if we'll render GARD polygons.
    world = land = None
    gard = None
    if "gard" in sources and args.gard_gpkg:
        print("Loading basemap + GARD…")
        world = load_basemap(cache_dir, basemap_path)
        from shapely.ops import unary_union
        land = unary_union(list(world.geometry))
        gard = load_gard(args.gard_gpkg)
    elif "gard" in sources:
        print("(no --gard-gpkg given; reptiles will be skipped)")

    credits = json.loads(credits_path.read_text()) if credits_path.exists() else {}
    failures = []
    made = skipped = 0

    for i, sp in enumerate(todo, 1):
        slug, sci = sp["slug"], sp["scientific_name"].strip()
        out = out_dir / f"{slug}.webp"
        if out.exists() and not args.overwrite:
            skipped += 1
            continue
        print(f"[{i}/{len(todo)}] {sp['common_name']} ({sci})")
        reason = "no expert source"

        # 1) GARD for reptiles (rendered house style).
        if gard is not None and is_reptile(sp):
            g = gard.get(sci.lower())
            if g is not None:
                try:
                    render_range(world, land, g, out)
                    credits[slug] = {"source": "GARD 1.7", "license": "CC0",
                                     "url": "https://www.gardinitiative.org/"}
                    print("    GARD ✓")
                    made += 1
                    continue
                except Exception as e:
                    reason = f"GARD render error: {e}"
            else:
                reason = "not in GARD"

        # 2) Wikimedia Commons expert image (saved as-is).
        if "wikimedia" in sources:
            time.sleep(args.throttle)
            res = wikimedia_rangemap(session, sci)
            if res:
                thumb, lic, artist, fname = res
                try:
                    img = session.get(thumb, timeout=60)
                    img.raise_for_status()
                    from PIL import Image
                    out.parent.mkdir(parents=True, exist_ok=True)
                    Image.open(io.BytesIO(img.content)).convert("RGB").save(
                        out, "WEBP", quality=WEBP_QUALITY, method=6)
                    credits[slug] = {
                        "source": f"Wikimedia Commons: {fname}", "license": lic,
                        "attribution": artist,
                        "url": "https://commons.wikimedia.org/wiki/File:"
                               + fname.replace(" ", "_")}
                    print(f"    Wikimedia ✓ ({lic})")
                    made += 1
                    continue
                except Exception as e:
                    reason = f"image download error: {e}"
            else:
                reason = "no P181 range image (commercial-OK)"

        failures.append((slug, sci, reason))

    credits_path.parent.mkdir(parents=True, exist_ok=True)
    credits_path.write_text(json.dumps(credits, indent=1, ensure_ascii=False))
    rep = cache_dir / "range_failures.csv"
    cache_dir.mkdir(parents=True, exist_ok=True)
    with rep.open("w", newline="", encoding="utf-8") as f:
        csv.writer(f).writerows([("slug", "scientific_name", "reason"), *failures])

    print(f"\nDone. made={made} skipped(existing)={skipped} no-source={len(failures)}")
    print(f"Credits → {credits_path}\nFailures → {rep}")
    print("Species with no expert source fall back to the parent map, then "
          "_unavailable.png, at runtime — that's intended.")


if __name__ == "__main__":
    sys.exit(main())
