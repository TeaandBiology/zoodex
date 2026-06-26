#!/usr/bin/env python3
"""
fetch_species_images.py — find a representative, licence-appropriate photo for
every species in the ZooDex catalogue, from several sources, saved as
images/<slug>.webp.

Sources are tried in order until one returns a usable image:
  1. iNaturalist        photographer photos (commercial-licensed only)
  2. Wikimedia Commons  via Wikidata's "image" property (P18); commercial-OK
  3. Openverse          CC/PD aggregator, filtered to commercial use
  4. Flickr             optional, needs --flickr-key

Whatever stays unmatched keeps the app's per-group placeholder.

NO API KEY NEEDED for iNaturalist, Wikimedia, or Openverse. Flickr needs a free
key. Be polite: a short delay between species, and a User-Agent identifying you.

REQUIREMENTS
  pip install requests Pillow

TYPICAL USE (run from the project root)
  python tools/fetch_species_images.py --contact "you@example.com"

  # add Flickr as a last resort:
  python tools/fetch_species_images.py --contact "you@..." \
      --sources inat,wikimedia,openverse,flickr --flickr-key YOURKEY

  # test on the first 10:
  python tools/fetch_species_images.py --limit 10 --contact "you@example.com"

LICENCES (important if you charge for the app)
  Never downloads "all rights reserved", NonCommercial, or NoDerivatives. By
  default keeps CC0 / public-domain, CC-BY and CC-BY-SA (commercial-OK). CC-BY
  and CC-BY-SA require visible attribution — image_credits.csv records it per
  species and per source, so you can show it in-app. --allow-noncommercial
  widens to CC-BY-NC variants (NOT for a paid app).
"""

import argparse
import csv
import io
import json
import os
import re
import sys
import time

try:
    import requests
except ImportError:
    sys.exit("Missing dependency: pip install requests Pillow")
try:
    from PIL import Image
except ImportError:
    sys.exit("Missing dependency: pip install Pillow")

EXT = {"webp": "webp", "jpeg": "jpg", "png": "png"}

COMMERCIAL_SAFE = {"cc0", "cc-by", "cc-by-sa"}
NONCOMMERCIAL = {"cc-by-nc", "cc-by-nc-sa"}

# Flickr licence id -> (canonical code, display name). 7/8/9/10 are PD-equivalent
# / public-domain and treated as commercial-OK. (Flickr later added CC 4.0 ids;
# extend --flickr-licenses and these maps if you want those too.)
FLICKR = {
    "1": ("cc-by-nc-sa", "CC BY-NC-SA 2.0"),
    "2": ("cc-by-nc", "CC BY-NC 2.0"),
    "3": ("cc-by-nc-nd", "CC BY-NC-ND 2.0"),
    "4": ("cc-by", "CC BY 2.0"),
    "5": ("cc-by-sa", "CC BY-SA 2.0"),
    "6": ("cc-by-nd", "CC BY-ND 2.0"),
    "7": ("cc0", "No known copyright restrictions"),
    "8": ("cc0", "United States Government Work"),
    "9": ("cc0", "CC0 1.0"),
    "10": ("cc0", "Public Domain Mark 1.0"),
}


class RateLimited(Exception):
    pass


def acceptable_licences(allow_nc):
    out = set(COMMERCIAL_SAFE)
    if allow_nc:
        out |= NONCOMMERCIAL
    return out


def canon_license(raw):
    """Normalise many spellings to one of: cc0, cc-by, cc-by-sa, cc-by-nc,
    cc-by-nc-sa, cc-by-nd (rejected), or the raw string if unrecognised."""
    s = (raw or "").strip().lower().replace("_", "-").replace(" ", "-")
    if not s:
        return None
    if "cc0" in s or "publicdomain" in s or "public-domain" in s or s in ("pd", "pdm"):
        return "cc0"
    if "nd" in s:
        return "cc-by-nd"  # no-derivatives — never accepted (resize = derivative)
    if "by" in s:
        code = "cc-by"
        if "nc" in s:
            code += "-nc"
        if "sa" in s:
            code += "-sa"
        return code
    return s


def strip_html(text):
    return re.sub(r"<[^>]+>", "", text or "").strip()


_LICENCE_BASE = {
    "cc0": "CC0",
    "cc-by": "CC-BY",
    "cc-by-sa": "CC-BY-SA",
    "cc-by-nc": "CC-BY-NC",
    "cc-by-nc-sa": "CC-BY-NC-SA",
    "cc-by-nd": "CC-BY-ND",
    "cc-by-nc-nd": "CC-BY-NC-ND",
}


def license_label(code, version=None, raw=None):
    """Human-readable licence such as 'CC-BY-SA 4.0'. Uses the canonical code for
    consistent hyphenation and appends a version when one is known (passed in, or
    parsed from a source's raw licence string). iNaturalist does not expose a
    version, so its credits read without one."""
    base = _LICENCE_BASE.get(code, (code or "").upper())
    if code == "cc0" and not version and not raw:
        version = "1.0"
    if not version and raw:
        m = re.search(r"(\d+\.\d+)", raw)
        if m:
            version = m.group(1)
    return ("%s %s" % (base, version)).strip() if version else base


def inat_author(attribution):
    """Pull the photographer name out of an iNaturalist attribution string like
    '(c) Dan Akira, some rights reserved (CC-BY-SA)'."""
    s = strip_html(attribution or "")
    s = re.sub(r"^\s*(\(c\)|\(C\)|©)\s*", "", s)
    s = s.split(",")[0].strip()
    return s or "Unknown"


def format_credit(author, licence):
    """Uniform credit string: 'Photo by NAME; licenced under LICENCE.'"""
    author = ((author or "").strip().rstrip(".")) or "Unknown"
    licence = (licence or "").strip().rstrip(".")
    if licence:
        return "Photo by %s; licenced under %s." % (author, licence)
    return "Photo by %s." % author


def get_with_retry(session, url, *, params=None, tries=4, base_sleep=2.0, timeout=60):
    last = None
    for attempt in range(tries):
        try:
            resp = session.get(url, params=params, timeout=timeout)
            if resp.status_code == 429:
                raise RateLimited()
            resp.raise_for_status()
            return resp
        except (requests.RequestException, RateLimited) as exc:
            last = exc
            time.sleep(base_sleep * (attempt + 1))
    raise last


class Found:
    def __init__(self, url, license_code, attribution, source, page):
        self.url = url
        self.license = license_code
        self.attribution = attribution
        self.source = source
        self.page = page


# --- sources -------------------------------------------------------------

def source_inat(session, sci, allowed, args):
    resp = get_with_retry(session, "https://api.inaturalist.org/v1/taxa",
                          params={"q": sci, "rank": "species", "per_page": 5,
                                  "is_active": "true"})
    results = resp.json().get("results", [])
    taxon = next((t for t in results
                  if (t.get("name") or "").lower() == sci.lower()), None)
    if taxon is None and results:
        taxon = results[0]
    if not taxon:
        return None
    photos = [tp["photo"] for tp in (taxon.get("taxon_photos") or [])
              if tp.get("photo")]
    if taxon.get("default_photo"):
        photos.append(taxon["default_photo"])
    for p in photos:
        code = canon_license(p.get("license_code"))
        if code in allowed and p.get("url"):
            url = p["url"]
            for tok in ("square", "small", "medium", "large", "original"):
                if "/%s." % tok in url:
                    url = url.replace("/%s." % tok, "/%s." % args.size)
                    break
            credit = format_credit(inat_author(p.get("attribution")),
                                   license_label(code))
            return Found(url, code, credit, "iNaturalist",
                         "https://www.inaturalist.org/taxa/%s" % taxon.get("id"))
    return None


def source_wikimedia(session, sci, allowed, args):
    # 1) Wikidata item whose taxon name (P225) is this species
    r = get_with_retry(session, "https://www.wikidata.org/w/api.php", params={
        "action": "query", "list": "search", "format": "json",
        "srsearch": "haswbstatement:P225=%s" % sci, "srlimit": 1})
    hits = r.json().get("query", {}).get("search", [])
    if not hits:
        return None
    qid = hits[0]["title"]
    # 2) its image (P18) -> a Commons filename
    r2 = get_with_retry(session, "https://www.wikidata.org/w/api.php", params={
        "action": "wbgetclaims", "format": "json", "entity": qid, "property": "P18"})
    claims = r2.json().get("claims", {}).get("P18", [])
    if not claims:
        return None
    try:
        filename = claims[0]["mainsnak"]["datavalue"]["value"]
    except (KeyError, IndexError, TypeError):
        return None
    # 3) Commons imageinfo: a scaled url + licence/attribution
    width = max(args.max_dim, 1) if args.max_dim else 1400
    r3 = get_with_retry(session, "https://commons.wikimedia.org/w/api.php", params={
        "action": "query", "format": "json", "titles": "File:%s" % filename,
        "prop": "imageinfo", "iiprop": "url|extmetadata", "iiurlwidth": width})
    pages = r3.json().get("query", {}).get("pages", {})
    page = next(iter(pages.values()), {})
    info = (page.get("imageinfo") or [{}])[0]
    if not info:
        return None
    meta = info.get("extmetadata", {})
    raw_lic = (meta.get("LicenseShortName", {}).get("value")
               or meta.get("License", {}).get("value"))
    code = canon_license(raw_lic)
    if code not in allowed:
        return None
    artist = strip_html(meta.get("Artist", {}).get("value", ""))
    short = strip_html(meta.get("LicenseShortName", {}).get("value", "")) or raw_lic
    attribution = format_credit(artist, license_label(code, raw=short))
    return Found(info.get("thumburl") or info.get("url"), code, attribution,
                 "Wikimedia Commons", info.get("descriptionurl", ""))


def source_openverse(session, sci, allowed, args):
    params = {"q": sci, "page_size": 1, "mature": "false"}
    if args.allow_noncommercial:
        params["license"] = "cc0,pdm,by,by-sa,by-nc,by-nc-sa"
    else:
        params["license_type"] = "commercial"
    r = get_with_retry(session, "https://api.openverse.org/v1/images/", params=params)
    results = r.json().get("results", [])
    if not results:
        return None
    it = results[0]
    code = canon_license(it.get("license"))
    if code not in allowed or not it.get("url"):
        return None
    attribution = format_credit(it.get("creator"),
                                license_label(code, version=it.get("license_version")))
    return Found(it.get("url"), code, attribution, "Openverse",
                 it.get("foreign_landing_url", ""))


def source_flickr(session, sci, allowed, args):
    if not args.flickr_key:
        return None
    r = get_with_retry(session, "https://api.flickr.com/services/rest/", params={
        "method": "flickr.photos.search", "api_key": args.flickr_key,
        "text": sci, "license": args.flickr_licenses, "sort": "relevance",
        "content_type": 1, "media": "photos", "per_page": 1,
        "extras": "license,owner_name,url_l,url_c", "format": "json",
        "nojsoncallback": 1})
    photos = r.json().get("photos", {}).get("photo", [])
    if not photos:
        return None
    p = photos[0]
    code, name = FLICKR.get(str(p.get("license")), (None, "Flickr"))
    if code not in allowed:
        return None
    url = p.get("url_l") or p.get("url_c")
    if not url:
        return None
    attribution = format_credit(p.get("owner_name"), license_label(code, raw=name))
    page = "https://www.flickr.com/photos/%s/%s" % (p.get("owner", ""), p.get("id", ""))
    return Found(url, code, attribution, "Flickr", page)


SOURCES = {
    "inat": source_inat,
    "wikimedia": source_wikimedia,
    "openverse": source_openverse,
    "flickr": source_flickr,
}


def fetch_for_species(session, sci, allowed, args, order):
    for name in order:
        fn = SOURCES.get(name)
        if not fn:
            continue
        try:
            found = fn(session, sci, allowed, args)
        except RateLimited:
            print("      [%s] rate limited; pausing 20s" % name)
            time.sleep(20)
            found = None
        except Exception as exc:  # noqa: BLE001  (report, try next source)
            print("      [%s] error: %s" % (name, exc))
            found = None
        if found and found.url:
            return found
        time.sleep(0.3)  # gentle between sources
    return None


def encode_image(image_bytes, max_dim, fmt, quality):
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    if max_dim and max(img.size) > max_dim:
        img.thumbnail((max_dim, max_dim), Image.LANCZOS)
    buf = io.BytesIO()
    if fmt == "webp":
        img.save(buf, format="WEBP", quality=quality, method=6)
    elif fmt == "jpeg":
        img.save(buf, format="JPEG", quality=quality, optimize=True, progressive=True)
    else:
        img.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def main():
    ap = argparse.ArgumentParser(description="Fetch licence-appropriate species images from multiple sources.")
    ap.add_argument("--catalog", default="assets/data/species_catalog.json",
                    help="Path to species_catalog.json")
    ap.add_argument("--out", default="images", help="Output folder for images")
    ap.add_argument("--reports-dir", default="tools/reports",
                    help="Where to write image_credits.csv / failures.csv")
    ap.add_argument("--sources", default="inat,wikimedia,openverse",
                    help="Comma list, tried in order: inat,wikimedia,openverse,flickr")
    ap.add_argument("--flickr-key", default="", help="Flickr API key (enables flickr)")
    ap.add_argument("--flickr-licenses", default="4,5,7,8,9,10",
                    help="Flickr licence ids to accept (commercial-OK by default)")
    ap.add_argument("--format", default="webp", choices=["webp", "jpeg", "png"],
                    help="Output image format (default: webp)")
    ap.add_argument("--quality", type=int, default=82,
                    help="Encoder quality 1-100 for webp/jpeg (default: 82)")
    ap.add_argument("--size", default="original",
                    choices=["small", "medium", "large", "original"],
                    help="iNat source size to download (default: original, so "
                         "the source is large enough to fill the species-page "
                         "hero without upscaling)")
    ap.add_argument("--max-dim", type=int, default=1400,
                    help="Resize so the longest side is at most this many px "
                         "(0 = keep source size). Default 1400 keeps the hero "
                         "crop (about 1236x1200 px on a high-DPR phone) sharp.")
    ap.add_argument("--delay", type=float, default=1.0,
                    help="Seconds to wait between species (be polite)")
    ap.add_argument("--allow-noncommercial", action="store_true",
                    help="Also accept CC-BY-NC / CC-BY-NC-SA (NOT for paid apps)")
    ap.add_argument("--overwrite", action="store_true",
                    help="Re-download even if the output file already exists")
    ap.add_argument("--limit", type=int, default=0,
                    help="Only process the first N species (0 = all)")
    ap.add_argument("--contact", default="",
                    help="Your email or app URL, added to the User-Agent")
    args = ap.parse_args()

    if not os.path.exists(args.catalog):
        sys.exit("Catalog not found: %s" % args.catalog)
    os.makedirs(args.out, exist_ok=True)
    os.makedirs(args.reports_dir, exist_ok=True)
    ext = EXT[args.format]

    order = [s.strip() for s in args.sources.split(",") if s.strip()]
    if "flickr" in order and not args.flickr_key:
        print("Note: 'flickr' is in --sources but no --flickr-key given; skipping it.")
    if args.allow_noncommercial:
        args.flickr_licenses = args.flickr_licenses + ",1,2"

    allowed = acceptable_licences(args.allow_noncommercial)

    with open(args.catalog, encoding="utf-8") as fh:
        catalog = json.load(fh)
    if args.limit:
        catalog = catalog[:args.limit]

    session = requests.Session()
    ua = "ZooDexImageFetcher/2.0"
    if args.contact:
        ua += " (%s)" % args.contact
    session.headers.update({"User-Agent": ua})

    credits_path = os.path.join(args.reports_dir, "image_credits.csv")
    failures_path = os.path.join(args.reports_dir, "failures.csv")
    credits = open(credits_path, "w", newline="", encoding="utf-8")
    failures = open(failures_path, "w", newline="", encoding="utf-8")
    cw = csv.writer(credits)
    fw = csv.writer(failures)
    cw.writerow(["slug", "scientific_name", "common_name", "source",
                 "license", "attribution", "source_url"])
    fw.writerow(["slug", "scientific_name", "reason"])

    n_ok = n_skip = n_fail = 0
    by_source = {}
    total = len(catalog)

    for i, sp in enumerate(catalog, 1):
        slug = sp.get("slug")
        sci = sp.get("scientific_name")
        common = sp.get("common_name", "")
        if not slug or not sci:
            n_fail += 1
            fw.writerow([slug or "", sci or "", "missing slug or scientific_name"])
            continue

        dest = os.path.join(args.out, "%s.%s" % (slug, ext))
        if os.path.exists(dest) and not args.overwrite:
            n_skip += 1
            print("[%d/%d] skip (exists)  %s" % (i, total, slug))
            continue

        print("[%d/%d] %s  (%s)" % (i, total, slug, sci))
        found = fetch_for_species(session, sci, allowed, args, order)
        if not found:
            n_fail += 1
            fw.writerow([slug, sci, "no source returned a usable image"])
            time.sleep(args.delay)
            continue

        try:
            resp = get_with_retry(session, found.url)
            data = encode_image(resp.content, args.max_dim, args.format, args.quality)
            with open(dest, "wb") as out:
                out.write(data)
            cw.writerow([slug, sci, common, found.source, found.license,
                         found.attribution, found.page])
            credits.flush()
            n_ok += 1
            by_source[found.source] = by_source.get(found.source, 0) + 1
            print("      got it from %s (%s)" % (found.source, found.license))
        except Exception as exc:  # noqa: BLE001
            n_fail += 1
            fw.writerow([slug, sci, "download/encode error: %s" % exc])
            print("      error saving: %s" % exc)

        time.sleep(args.delay)

    credits.close()
    failures.close()
    print("\nDone. ok=%d  skipped=%d  failed=%d  (total %d)"
          % (n_ok, n_skip, n_fail, total))
    if by_source:
        print("By source: " + ", ".join("%s=%d" % (k, v)
                                         for k, v in sorted(by_source.items())))
    print("Output   -> %s/<slug>.%s" % (args.out, ext))
    print("Credits  -> %s   (keep this: attribution for CC-BY photos)" % credits_path)
    print("Failures -> %s   (review and fill by hand)" % failures_path)


if __name__ == "__main__":
    main()
