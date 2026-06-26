#!/usr/bin/env python3
"""
fetch_translations.py - seed catalogue translations from Wikidata + Wikipedia.

Fills the per-language overlay files the app reads at
assets/data/i18n/<locale>/species.json with translated common names (and,
optionally, short descriptions), so most of the catalogue can be translated
without typing each name by hand.

How it works, per species (keyed by slug):
  1. Resolve the species to a Wikidata entity by its scientific name
     (property P225, "taxon name") - the same link the image fetcher uses.
  2. Read that entity's multilingual labels: the label in each target language
     is the localised common name (e.g. fr "Panda roux", de "Roter Panda").
  3. Optionally, follow the entity's Wikipedia sitelink in each language and take
     the first sentence or two of the article as a short description.

Output is merged into the overlay files, keyed by slug, holding only the fields
found. Missing fields fall back to English in the app, so partial results are
fine. Scientific names are never translated.

This is a SEED, not a final translation: machine labels and article snippets
should be reviewed (Welsh coverage on Wikidata is thin, so cy will be sparse).

Usage (run from the project root):
    pip install requests
    python tools/fetch_translations.py --contact "you@example.com"

    # only some languages, and skip descriptions (names only):
    python tools/fetch_translations.py --contact "you@example.com" \
        --langs fr,de --no-descriptions

    # re-fetch and overwrite existing entries; quick test on 20 species:
    python tools/fetch_translations.py --contact "you@example.com" \
        --overwrite --sample 20

By default it resumes: a species already present in a language file is skipped
(no network call) unless --overwrite is given.
"""

import argparse
import json
import os
import re
import sys
import time

try:
    import requests
except ImportError:
    sys.exit("This tool needs requests:  pip install requests")

WIKIDATA_API = "https://www.wikidata.org/w/api.php"
DEFAULT_LANGS = ["fr", "de", "es", "cy"]


class RateLimited(Exception):
    pass


def get_with_retry(session, url, *, params, tries=4, base_sleep=2.0, timeout=60):
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


def wikidata_qid(session, scientific_name):
    """The Wikidata entity id whose taxon name (P225) is this species, or None."""
    name = (scientific_name or "").strip()
    if not name:
        return None
    r = get_with_retry(session, WIKIDATA_API, params={
        "action": "query", "list": "search", "format": "json",
        "srsearch": 'haswbstatement:P225=%s' % name, "srlimit": 1})
    hits = r.json().get("query", {}).get("search", [])
    return hits[0]["title"] if hits else None


def fetch_entity(session, qid, langs):
    """Return (labels, sitelinks) for the entity. labels: lang -> common name.
    sitelinks: lang -> Wikipedia article title (for the <lang>wiki)."""
    r = get_with_retry(session, WIKIDATA_API, params={
        "action": "wbgetentities", "ids": qid, "format": "json",
        "props": "labels|sitelinks", "languages": "|".join(langs)})
    ent = r.json().get("entities", {}).get(qid, {})
    labels = {}
    for lang, v in (ent.get("labels") or {}).items():
        val = (v or {}).get("value", "").strip()
        if val:
            labels[lang] = val
    sitelinks = {}
    for lang in langs:
        sl = (ent.get("sitelinks") or {}).get("%swiki" % lang)
        if sl and sl.get("title"):
            sitelinks[lang] = sl["title"]
    return labels, sitelinks


def first_sentences(text, max_sentences=2, max_chars=320):
    """Trim a Wikipedia intro to a short, reviewable blurb."""
    text = re.sub(r"\s+", " ", text or "").strip()
    if not text:
        return ""
    parts = re.split(r"(?<=[.!?])\s+", text)
    out = " ".join(parts[:max_sentences]).strip()
    if len(out) > max_chars:
        out = out[:max_chars].rsplit(" ", 1)[0].rstrip(" ,;:") + "..."
    return out


def wiki_intro(session, lang, title):
    """The lead extract (intro) of a Wikipedia article, plain text, or ''."""
    api = "https://%s.wikipedia.org/w/api.php" % lang
    r = get_with_retry(session, api, params={
        "action": "query", "format": "json", "prop": "extracts",
        "exintro": 1, "explaintext": 1, "redirects": 1, "titles": title})
    pages = r.json().get("query", {}).get("pages", {})
    page = next(iter(pages.values()), {})
    return (page.get("extract") or "").strip()


def load_catalog(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    rows = data if isinstance(data, list) else data.get("species", [])
    out = []
    for s in rows:
        slug = (s.get("slug") or "").strip()
        sci = (s.get("scientific_name") or "").strip()
        if slug and sci:
            out.append((slug, sci))
    return out


def overlay_path(out_dir, lang):
    return os.path.join(out_dir, lang, "species.json")


def load_overlay(path):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        species = data.get("species") if isinstance(data, dict) else None
        return species if isinstance(species, dict) else {}
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_overlay(path, species):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"species": dict(sorted(species.items()))}, f,
                  ensure_ascii=False, indent=2)
        f.write("\n")


def main():
    ap = argparse.ArgumentParser(
        description="Seed catalogue translations from Wikidata + Wikipedia.")
    ap.add_argument("--contact", required=True,
                    help="Your email or URL, sent in the User-Agent so the "
                         "Wikimedia APIs can identify the requests.")
    ap.add_argument("--catalog", default="assets/data/species_catalog.json")
    ap.add_argument("--out-dir", default="assets/data/i18n",
                    help="Folder holding the <locale>/species.json overlays")
    ap.add_argument("--langs", default=",".join(DEFAULT_LANGS),
                    help="Comma-separated locale codes (default: fr,de,es,cy)")
    ap.add_argument("--descriptions", dest="descriptions",
                    action="store_true", default=True,
                    help="Also fetch a short description (default: on)")
    ap.add_argument("--no-descriptions", dest="descriptions",
                    action="store_false",
                    help="Fetch common names only, no descriptions")
    ap.add_argument("--long", action="store_true",
                    help="Also store the fuller intro as long_description")
    ap.add_argument("--overwrite", action="store_true",
                    help="Re-fetch and replace species already present")
    ap.add_argument("--sample", type=int, default=0,
                    help="Only process the first N species (0 = all)")
    ap.add_argument("--sleep", type=float, default=0.2,
                    help="Pause between species, in seconds (be polite)")
    args = ap.parse_args()

    if not os.path.exists(args.catalog):
        sys.exit("Catalog not found: %s (run from the project root)" % args.catalog)

    langs = [c.strip() for c in args.langs.split(",") if c.strip()]
    catalog = load_catalog(args.catalog)
    if args.sample > 0:
        catalog = catalog[:args.sample]

    session = requests.Session()
    session.headers["User-Agent"] = (
        "ZooDex-translation-fetch/1.0 (%s)" % args.contact)

    overlays = {lang: load_overlay(overlay_path(args.out_dir, lang))
                for lang in langs}
    stats = {lang: {"name": 0, "desc": 0} for lang in langs}
    no_qid = []
    total = len(catalog)

    for i, (slug, sci) in enumerate(catalog, 1):
        # Resume: skip only if every language already has this slug.
        if not args.overwrite and all(slug in overlays[l] for l in langs):
            print("[%d/%d] skip (have all)  %s" % (i, total, slug))
            continue

        try:
            qid = wikidata_qid(session, sci)
        except Exception as e:
            print("[%d/%d] FAILED qid  %s (%s)" % (i, total, slug, e))
            continue
        if not qid:
            no_qid.append(slug)
            print("[%d/%d] no Wikidata match  %s (%s)" % (i, total, slug, sci))
            continue

        try:
            labels, sitelinks = fetch_entity(session, qid, langs)
        except Exception as e:
            print("[%d/%d] FAILED entity  %s (%s)" % (i, total, slug, e))
            continue

        got = []
        for lang in langs:
            if slug in overlays[lang] and not args.overwrite:
                continue
            entry = dict(overlays[lang].get(slug, {}))
            name = labels.get(lang)
            if name:
                entry["common_name"] = name
                stats[lang]["name"] += 1
            if args.descriptions and sitelinks.get(lang):
                try:
                    intro = wiki_intro(session, lang, sitelinks[lang])
                except Exception:
                    intro = ""
                if intro:
                    entry["description"] = first_sentences(intro)
                    if args.long:
                        entry["long_description"] = first_sentences(
                            intro, max_sentences=8, max_chars=1500)
                    stats[lang]["desc"] += 1
            if entry:
                overlays[lang][slug] = entry
                got.append(lang)
        print("[%d/%d] %s -> %s  [%s]" % (i, total, slug, qid,
                                          ",".join(got) or "nothing"))
        time.sleep(args.sleep)

    for lang in langs:
        save_overlay(overlay_path(args.out_dir, lang), overlays[lang])

    print("\nDone. %d species processed." % total)
    for lang in langs:
        print("  %s: %d names, %d descriptions (file has %d entries)" % (
            lang, stats[lang]["name"], stats[lang]["desc"],
            len(overlays[lang])))
    if no_qid:
        print("  %d species had no Wikidata taxon match (left untranslated): %s"
              % (len(no_qid), ", ".join(no_qid[:15])
                 + (" ..." if len(no_qid) > 15 else "")))


if __name__ == "__main__":
    main()
