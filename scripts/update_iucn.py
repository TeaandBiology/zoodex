#!/usr/bin/env python3
import argparse
import os
import json
import re
import sys
import time
from typing import Any, Dict, Optional, Tuple

import requests

# --- HARD-CODED IUCN API TOKEN ---
IUCN_TOKEN = "KEY_IN_HERE"

URL_SCI = "https://api.iucnredlist.org/api/v4/taxa/scientific_name"
URL_SIS = "https://api.iucnredlist.org/api/v4/taxa/sis/{sis_id}"

VALID_CATEGORIES = {"EX", "EW", "CR", "EN", "VU", "NT", "LC", "DD", "NE"}

# Default paths: resolve relative to this script so running from any CWD works
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_IN_PATH = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "assets", "data", "species_catalog.json"))
DEFAULT_OUT_PATH = DEFAULT_IN_PATH


def parse_scientific_name(name: str) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    if not name:
        return None, None, None
    parts = re.findall(r"[A-Za-z-]+", name.strip())
    if len(parts) < 2:
        return None, None, None
    genus, species = parts[0], parts[1]
    infra = parts[2] if len(parts) >= 3 else None
    return genus, species, infra


def set_iucn_status(entry: Dict[str, Any], value: str) -> None:
    if "IUCN status" in entry:
        entry["IUCN status"] = value
    elif "iucn_status" in entry:
        entry["iucn_status"] = value
    else:
        entry["IUCN status"] = value


def pick_latest_category(payload: Any) -> Optional[str]:
    """
    v4 sis payload contains top-level "assessments" list.
    In your account, each assessment uses:
      - red_list_category_code
      - latest
      - year_published
    """
    if not isinstance(payload, dict):
        return None
    assessments = payload.get("assessments")
    if not isinstance(assessments, list) or not assessments:
        return None

    def year_val(a: Dict[str, Any]) -> int:
        v = a.get("year_published")
        try:
            return int(v)
        except Exception:
            return -1

    def get_code(a: Dict[str, Any]) -> Optional[str]:
        v = a.get("red_list_category_code")
        if isinstance(v, str) and v.strip():
            return v.strip().upper()
        v = a.get("category")
        if isinstance(v, str) and v.strip():
            return v.strip().upper()
        return None

    latest = [a for a in assessments if isinstance(a, dict) and a.get("latest") is True]
    pool = latest if latest else [a for a in assessments if isinstance(a, dict)]
    pool = sorted(pool, key=year_val, reverse=True)

    for a in pool:
        code = get_code(a)
        if code in VALID_CATEGORIES:
            return code

    for a in pool:
        code = get_code(a)
        if code:
            return code

    return None


def fetch_sis_id(
    session: requests.Session,
    headers: Dict[str, str],
    genus: str,
    species: str,
    infra: Optional[str],
    wait_s: float,
    timeout_s: float,
    verbose: bool,
) -> Optional[int]:
    params = {"genus_name": genus, "species_name": species}
    if infra:
        params["infra_name"] = infra

    time.sleep(wait_s)
    r = session.get(URL_SCI, headers=headers, params=params, timeout=timeout_s)
    if verbose:
        print(f"[scientific_name] {genus} {species} {infra or ''} -> HTTP {r.status_code}", file=sys.stderr)

    if r.status_code != 200:
        if verbose:
            print((r.text or "")[:300], file=sys.stderr)
        return None

    j = r.json()
    taxon = j.get("taxon")
    if isinstance(taxon, dict) and isinstance(taxon.get("sis_id"), int):
        return taxon["sis_id"]
    return None


def fetch_category_by_sis(
    session: requests.Session,
    headers: Dict[str, str],
    sis_id: int,
    wait_s: float,
    timeout_s: float,
    verbose: bool,
) -> Optional[str]:
    time.sleep(wait_s)
    r = session.get(URL_SIS.format(sis_id=sis_id), headers=headers, timeout=timeout_s)
    if verbose:
        print(f"[sis] {sis_id} -> HTTP {r.status_code}", file=sys.stderr)

    if r.status_code != 200:
        if verbose:
            print((r.text or "")[:300], file=sys.stderr)
        return None

    j = r.json()
    return pick_latest_category(j)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="in_path", default=DEFAULT_IN_PATH)
    # Default output overwrites the input file
    ap.add_argument("--out", dest="out_path", default=DEFAULT_OUT_PATH)
    ap.add_argument("--wait", type=float, default=0.6)
    ap.add_argument("--timeout", type=float, default=30.0)
    ap.add_argument("--only-dd", action="store_true")
    ap.add_argument(
        "--print-status",
        action="store_true",
        help="Print each species' resolved IUCN code while running",
    )
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    if not IUCN_TOKEN or IUCN_TOKEN == "PASTE_YOUR_TOKEN_HERE":
        print("ERROR: Set IUCN_TOKEN at the top of the script.", file=sys.stderr)
        return 2

    headers = {"Authorization": f"Bearer {IUCN_TOKEN}"}
    session = requests.Session()

    with open(args.in_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        print("ERROR: Root JSON must be an array.", file=sys.stderr)
        return 2

    # caches
    sis_cache: Dict[Tuple[str, str, Optional[str]], Optional[int]] = {}
    cat_cache: Dict[int, Optional[str]] = {}

    updated = unresolved = skipped_bad_name = 0

    for entry in data:
        if not isinstance(entry, dict):
            continue

        if args.only_dd:
            cur = entry.get("IUCN status", entry.get("iucn_status"))
            if cur not in (None, "", "DD"):
                continue

        sci = entry.get("scientific_name", "")
        genus, species, infra = parse_scientific_name(sci)
        if not genus or not species:
            skipped_bad_name += 1
            if args.print_status:
                print(f"{sci or '(missing scientific_name)'} -> DD (bad scientific_name)")
            continue

        key = (genus, species, infra)

        if key not in sis_cache:
            sis_cache[key] = fetch_sis_id(session, headers, genus, species, infra, args.wait, args.timeout, args.verbose)

            # subspecies -> species fallback
            if sis_cache[key] is None and infra:
                key2 = (genus, species, None)
                if key2 not in sis_cache:
                    sis_cache[key2] = fetch_sis_id(
                        session, headers, genus, species, None, args.wait, args.timeout, args.verbose
                    )
                sis_cache[key] = sis_cache[key2]

        sis_id = sis_cache[key]
        if sis_id is None:
            set_iucn_status(entry, "DD")
            unresolved += 1
            if args.print_status:
                print(f"{sci} -> DD (no sis_id)")
            continue

        if sis_id not in cat_cache:
            cat_cache[sis_id] = fetch_category_by_sis(session, headers, sis_id, args.wait, args.timeout, args.verbose)

        cat = cat_cache[sis_id]
        if cat is None:
            set_iucn_status(entry, "DD")
            unresolved += 1
            if args.print_status:
                print(f"{sci} -> DD (no assessment code)")
        else:
            set_iucn_status(entry, cat)
            updated += 1
            if args.print_status:
                print(f"{sci} -> {cat}")

    with open(args.out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(
        f"Updated species: {updated}\n"
        f"Unresolved (left/set DD): {unresolved}\n"
        f"Skipped bad scientific_name: {skipped_bad_name}\n"
        f"Wrote: {args.out_path}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
