# ZooDex — Data Model & Architecture

> **For new developers:** this is the design/rationale document for the app — why
> the data model, location verification, privacy, and payment choices are the way
> they are. It was written before the code, so it occasionally talks about the
> work in future tense and refers to a three-part ("slice") build plan. **That
> plan is now implemented** in the current codebase; read this for the *why*, and
> the code + `README.md` for the *what*. Section references like "§6" point to the
> numbered sections within this same document.

**Purpose:** A single reference for how data is structured, updated, verified, gated, and (later) synced — so the species/zoo databases can grow constantly without breaking the app, and the offline-now / social-later phases share one set of rails.

---

## 1. Core principle: two kinds of data

Everything in the app is one of two kinds, with different owners, lifetimes, and trust models. Keeping them separate is the single most important structural decision.

| | **Reference data** | **User data** |
|---|---|---|
| Examples | species catalog, zoos, per-zoo inventories, avatar roster | visits, per-species seen/no-show, profile, friends, likes, entitlements/purchases |
| Owned by | you / the server | the user / the device |
| App's view | read-only | read-write |
| Updated by | publishing a new version (no app release) | the user, as they use the app |
| Trust | validated before use | private by default; minimal sharing |
| Phase 2 | served from a CDN/API | synced to the backend |

A single component — call it the **`ReferenceDataRepository`** — owns all reference data and hides where it comes from (bundled copy today, remote later). A separate component owns user data. The two never blur together. This is what lets "add a zoo" become a data change rather than a code change, and lets the social and paid features bolt on without a rewrite.

---

## 2. Identity & ID stability (the load-bearing rule)

User observations are keyed by species and zoo IDs. If an ID ever changes upstream, every observation keyed to the old ID orphans. This is cheap to get right now and very expensive to retrofit once real users have data.

**Rules:**

1. Every species, zoo, and avatar has a permanent `id` that is **assigned once and never changed or reused.**
2. `id` is treated as **opaque**. Names — including `scientific_name` — are *mutable attributes*, not identity. (Scientific names get revised by taxonomists; if the ID is derived from the name, a revision silently orphans data.)
3. Renaming an entity (common or scientific name) **does not** change its `id`.
4. If two entries must be merged (duplicate, or a split/lump in taxonomy), one `id` stays canonical and the other is recorded in an **alias table** so old references — including stored user observations — resolve forward.

**Scheme (decided):** species use an **opaque** id (e.g. `sp_d97ba4d96420`) with the old readable name carried as a separate, non-identity **`slug`** attribute. Opacity removes any temptation to derive ids from names and survives the bulk-imports/taxonomic churn that species data attracts. **Users** likewise get opaque, server-assigned ids (UUID v4, Supabase-native). **Zoos keep readable, frozen ids** (`london_zoo`) — the set is small and hand-curated, a rebrand changes the `name` not the id, and it keeps inventory filenames legible. The `slug` lets inventories and humans still refer to a species by `elephas_maximus`; the loader resolves it to the opaque id. (Forward-compat: a `sources` block holds external authority ids — IUCN `sis_id`, GBIF — so the data pipeline can key off a stable external id instead of re-matching scientific names.)

**Alias table** (reference data):

```json
{ "aliases": { "old_or_merged_id": "canonical_id" } }
```

Resolution order everywhere: look up `id`; if absent, follow `aliases`; if still absent, match a species `slug`; if still absent, treat as unknown (skip + log — see §3.1).

---

## 3. Reference data

### 3.1 Versioning & the update mechanism

This is the heart of "update constantly without breaking." Reference data is published as versioned datasets described by a **manifest**.

```json
{
  "schema_version": 1,
  "content_version": 14,
  "datasets": {
    "species_catalog": { "version": 7,  "url": "…/species_catalog.json", "sha256": "…" },
    "zoos":            { "version": 3,  "url": "…/zoos.json",            "sha256": "…" },
    "avatars":         { "version": 2,  "url": "…/avatars.json",         "sha256": "…" },
    "inventories":     { "version": 12, "index": [
        { "zoo_id": "london_zoo",  "version": 9, "url": "…/london_zoo.json",  "sha256": "…" },
        { "zoo_id": "chester_zoo", "version": 4, "url": "…/chester_zoo.json", "sha256": "…" }
    ]}
  }
}
```

- **`schema_version`** — bumped only on a *breaking* shape change. The app declares the max schema it understands. If the remote `schema_version` is higher, the app **ignores the remote data and keeps what it has.** A new dataset can never break an old app.
- **`version`** (per dataset) — monotonic. The app downloads a dataset only when remote `version` > locally cached `version`.
- **`sha256`** — integrity check. A dataset that fails its checksum is rejected, and the previous good copy is kept.

**App flow:**
1. Ship a **bundled seed copy** (manifest + all datasets) so the app works fully offline on first launch, before it has ever reached the network.
2. On launch / periodically, fetch the remote manifest.
3. For each dataset where `remote.version > cached.version` *and* `schema_version` is compatible: download → validate (schema + checksum) → **atomically swap** into the local cache.
4. Until a remote host exists, step 2 is a no-op. Going online later is a config change, not new architecture.

**Tolerant loading (mandatory).** Loading reference data must never throw on bad input:
- Unknown fields → ignored.
- An inventory item with an unknown/aliasable-missing `species_id` → **skipped and logged**, not fatal. (This is the bug that currently bricks both zoos.)
- An individual entry that fails validation → skipped, not fatal; the rest still load.
- A whole dataset that fails to parse/validate → discard it, keep the last good cached/bundled copy.

### 3.2 Species (catalog)

```json
{
  "id": "sp_d97ba4d96420",
  "slug": "acanthurus_bariene",
  "common_name": "Roundspot Surgeonfish",
  "scientific_name": "Acanthurus bariene",
  "group": "Marine Fish",
  "description": "",
  "iucn_status": "LC",
  "taxonomy": {
    "kingdom": "Animalia", "phylum": "Chordata", "class": "Actinopterygii",
    "order": "Perciformes", "family": "Acanthuridae",
    "genus": "Acanthurus", "species": "bariene"
  },
  "sources": { "sis_id": null, "gbif_id": null }
}
```

Changes from today's catalog:
- Encoding fixed to **UTF-8** (it was UTF-16LE, which is why it wouldn't load).
- **`id` is now opaque** (`sp_…`); the old readable id moves to **`slug`** as a non-identity attribute (see §2).
- `"IUCN status"` → `iucn_status` (no spaces in keys; stable, code-friendly).
- Taxonomy and IUCN status are **kept**, not dropped by the model. The Dart `Species` class gains these fields.
- **`sources`** holds external authority ids (IUCN `sis_id`, GBIF) — empty for now, to be populated by the data pipeline so it can key off a stable external id rather than re-matching names.
- `zone` is **removed** from the catalog — it was never a property of a species in general; it's where the species sits *at a given zoo*, so it lives on the inventory item (§3.4).
- `description` (short, default blurb at the top of the species page) stays; most
  are currently empty — a data-quality backlog item, not a blocker. A new optional
  **`long_description`** holds a longer write-up shown under the range map on the
  Species-tab page.

`iucn_status` is a controlled vocabulary: `EX, EW, CR, EN, VU, NT, LC, DD, NE, NA` (plus the absence of a value). The UI maps these to labels/colours.

### 3.3 Zoos

```json
{
  "id": "london_zoo",
  "name": "London Zoo",
  "location": { "lat": 0.0, "lng": 0.0 },
  "radius_m": 500,
  "coords_set": false,
  "country": "GB",
  "last_updated": "2026-02-15"
}
```

New fields driving verification and access:
- **`location`** — authoritative centre point. Seeded as a `0,0` placeholder with `coords_set: false`; coordinates are filled in by hand per zoo (so verification can't confirm a zoo until its real centre is set).
- **`radius_m`** — per-zoo, set by hand, because a global radius fails: too small misses people deep inside a large site; too large verifies the car park next door. Compact urban zoo ≈ 300–500 m; large zoo / safari park can be several km. For oddly shaped sites a bounding polygon is a future upgrade; a generous radius is fine to start.
- **`country`** — drives both display grouping and the **premium entitlement scope** (§5): premium unlocks every zoo whose `country` matches the user's home country.

**The known-zoo list is derived from `zoos.json`, not hardcoded.** Today it's duplicated in `DataLoader.inventories` *and* `DataLoader.knownZooPacks`, which must be hand-synced. Both go away; the app lists whatever zoos the data declares.

### 3.4 Inventories (per zoo)

```json
{
  "schema_version": 1,
  "zoo_id": "london_zoo",
  "version": 9,
  "last_updated": "2026-02-15",
  "items": [
    { "species_id": "elephas_maximus", "zone": "Asian Forest",
      "description": "Find the herd near the South Entrance…" },
    { "species_id": "asian_short_clawed_otter", "zone": "Otters" }
  ]
}
```

- `items[].species_id` references the catalog by permanent ID (resolved via §2, including aliases).
- `items[].zone` is **optional** and is the *per-zoo placement*. This is the only place `zone` lives. A zone of `"Unknown"` (or blank) is treated as no zone and hidden.
- `items[].description` is **optional** and is the *per-zoo description* — shown on
  that zoo's species page in place of the species' short default `description`.
  Lets the same species read differently at each zoo (e.g. directions, keeper-talk
  times).
- Unknown `species_id` → skipped + logged (never throws).

### 3.5 Avatars (roster)

The avatar roster is just another versioned reference dataset — same loading, validation, and update path as species/zoos.

```json
{
  "version": 2,
  "avatars": [
    { "id": "avatar_red_panda", "asset": "assets/avatars/red_panda.png", "tags": ["mammal"] },
    { "id": "avatar_axolotl",   "asset": "assets/avatars/axolotl.png",   "tags": ["amphibian"] }
  ]
}
```

A user's profile stores only an `avatar_id`. "Add new avatars" becomes a data change with no new machinery.

---

## 4. User data

### 4.1 Visit (first-class entity) — one zoo, one day

A visit is **one zoo on one calendar day**. Its identity is `(zooId, localDate)`. This deliberately removes any manual "start/end visit" step: opening and closing the app throughout a day never fragments the visit, and there's nothing for the user to faff with. The first log of the day at a given zoo creates that day's visit; every later log that day attaches to it. Visiting two zoos in one day is simply two visits.

```dart
class Visit {
  final String id;                    // local id (server id added in Phase 2)
  final String zooId;                 // auto-detected when verified; chosen otherwise
  final DateTime date;                // local calendar date, midnight-normalised
  VerificationStatus verified;        // verified | unverified | skipped — upgradeable through the day
  final DateTime firstLoggedAt;
  DateTime lastLoggedAt;
}
```

- The day boundary is the user's **local** date. A rare late event spanning midnight splits into two days — acceptable and not worth special-casing.
- `verified` can be upgraded at any point during the day (see §6): a first log made from memory at home is `unverified`, but if the user later opens the app at the zoo and GPS confirms, that same day's visit becomes `verified`.

### 4.2 Per-species outcome

Within a visit, each species the user *acts on* gets one record. Three states, and the default state is the absence of a record:

- **seen** — logged a sighting.
- **noShow** — explicitly looked, wasn't on display.
- **unassessed** — the default for every species not acted on (no record stored).

This three-state design matters: an inventory can be ~375 species, so "not marked seen" must **not** be read as "no-show." No-show is an explicit, optional tap — light absence data and a gentle "assessed 40/375" completion stat for the keen, never a chore, and never shown socially (§4.7).

```dart
class SpeciesLog {
  final String visitId;
  final String speciesId;
  final Outcome outcome;      // seen | noShow
  final DateTime loggedAt;
  final String? note;         // PRIVATE personal note, optional, never shared
}
```

### 4.3 The "Dex" (derived, not stored)

A user's lifetime collection is a **view computed** by folding visits + species-logs — never a separate source of truth (which would drift). Per species:

- `seenEver` (bool), `firstSeenAt`, `lastSeenAt`
- `visitsSeenCount`
- `everVerified` (seen on at least one verified visit)
- `zoosSeenAt` (set of zoo IDs)

### 4.4 Profile (modelled now, used in Phase 2)

```dart
class Profile {
  final String userId;        // server-assigned, opaque
  final String displayName;   // filtered free text (see §7)
  final String avatarId;      // from the roster
  final String friendCode;    // non-enumerable, regeneratable
  final DateTime createdAt;
  // default visibility: friends-only (see §7)
}
```

### 4.5 Friendships

```dart
class Friendship {
  final String aUserId;
  final String bUserId;
  final FriendStatus status;  // pending | accepted
  final String requestedBy;
  final DateTime createdAt;
}
```

A friend code produces a **request the recipient must accept** — never an auto-add. (So an adult who obtains a child's code can't unilaterally start following them.)

### 4.6 Likes

```dart
class Like {
  final String userId;
  final String targetType;    // "visitSummary" (the only likeable unit, for now)
  final String targetId;
  final DateTime createdAt;
}
```

Likes are the *only* user-to-user interaction. No comments, no messages.

### 4.7 The social boundary: shareable summary vs private detail

Only one projection ever crosses to other users. Everything else stays private.

```dart
class VisitSummary {     // the ONLY thing friends can see / like
  final String visitId;
  final String userId;
  final String zooId;
  final String zooName;
  final DateTime date;          // coarse (day-level)
  final int speciesSeenCount;   // seen count only — no-show stays private
  final bool verified;
  // NO coordinates. NO notes. NO no-show or per-species detail.
}
```

Because GPS is never persisted (§6) and notes are private (§4.2), there is almost nothing sensitive to leak even by accident — which is the whole point.

---

## 5. Monetisation & access (entitlements)

Zoo access is a paid feature, sold as one-time unlocks. Access is a *derived check* over the user's **entitlement** plus `zoo.country` — it never touches reference data, so adding zoos doesn't change anyone's access logic.

### 5.1 Tiers

| Tier | Grants | Notes |
|---|---|---|
| **Free** | Any **3** zoos the user picks | Picked as the user goes; locked once full |
| **Premium** (one-time) | All zoos in the user's **home country** | Home country set once at signup |
| **Unlimited** (one-time) | All zoos, globally | Supersedes the others |

- **Free three:** unlocked **as the user goes** — each zoo they choose to open counts toward the three, and the set is **locked** once full, so a free user can't rotate through the whole catalogue. The three-free allowance is stated explicitly during account creation, so it's never a surprise.
- **Premium** is scoped to a single **home country**, set once at signup (store region / device locale as the default, user-confirmed) and not user-editable afterwards (support override only) — otherwise it could be re-pointed to game access.
- **Unlimited** is a strict superset and short-circuits every check. It is also the **only** path to more than one country — there's no second-country premium; a multi-country traveller buys Unlimited.

### 5.2 Entitlement record (user data)

```dart
class Entitlement {
  final String userId;
  final EntitlementTier tier;     // free | premiumCountry | unlimited
  final String? premiumCountry;   // e.g. "GB" — set iff tier == premiumCountry
  final List<String> freeZooIds;  // up to 3, append-only, locked when full
  final DateTime updatedAt;
}

bool canAccess(Zoo zoo, Entitlement e) =>
    e.tier == EntitlementTier.unlimited ||
    (e.tier == EntitlementTier.premiumCountry && zoo.country == e.premiumCountry) ||
    e.freeZooIds.contains(zoo.id);
```

All zoos stay **visible** to everyone so users can see what they could unlock; access is gated at "open / start logging," and locked zoos carry a clear unlock call-to-action.

### 5.3 Purchases & validation

The unlocks are digital content, so they **must** be sold through the platforms' in-app purchase systems — Apple StoreKit and Google Play Billing (≈15–30% commission); third-party processors aren't permitted for these on mobile. Both plans are **non-consumable** products, and Apple requires a working **Restore Purchases** flow.

The entitlement is **server-validated, never a bare device flag** — a local boolean is trivially flipped on a rooted device. A validation layer (e.g. a service like RevenueCat over StoreKit / Play Billing, or a minimal backend) verifies the store receipt and is the source of truth; the validated result is cached locally so that:

- a user who already owns a zoo can open it **offline**, and
- only the *purchase* itself requires connectivity.

Store-initiated **refunds must revoke** the entitlement (receipt re-check / webhook), and **restore** re-grants it on a new device.

```dart
class Purchase {              // the money ledger — kept distinct from all other records
  final String productId;     // maps to a tier (+ country for premium)
  final String platform;      // appStore | playStore
  final String transactionId; // store transaction / original id
  final bool validated;
  final DateTime purchasedAt;
}
```

A `productId → (tier, country?)` mapping lives in config, so new country-premium SKUs can be added without code changes. (Donations were considered and dropped, so there is a single money ledger; no charity flow.)

---

## 6. Location verification

GPS exists for exactly one job: confirm the user is genuinely at a zoo, to grant a visit **verified** status — then the coordinates are discarded. It auto-detects *which* zoo. It is a **badge, not a gate**: logging is never blocked; verification is the reward for a real visit.

**Algorithm** — run whenever the app has reason to think the user may be at a zoo (e.g. on opening at a location, or on logging), and re-runnable through the day:

```
verifyVisit():
  if location service off OR permission denied:
     return SKIPPED
  fix = getCurrentPosition(accuracy: when-in-use, timeout: ~10s)
  if fix == null:
     return UNVERIFIED            // retryable later that day
  best = null
  for zoo in zoos:
     d = haversine(fix, zoo.location)
     if (d - fix.accuracy) <= zoo.radius_m:   // generous: subtract the error margin
        if best == null or d < best.d: best = (zoo, d)
  if best != null:
     visit.zooId = best.zoo.id    // AUTO-DETECT today's visit for this zoo
     return VERIFIED
  return UNVERIFIED
  // the raw fix is discarded immediately; only the status (+ chosen zooId) is kept
```

Design points baked in:
- **Verify once per day per zoo, inherit to every log** — no GPS check per species tap (battery, friction, and indoor GPS is unreliable exactly where people log: aquariums, reptile houses).
- **Account for accuracy** (`d - accuracy <= radius`) so a noisy fix inside the zoo still verifies.
- **Upgradeable** — a poor or absent fix earlier in the day can become `verified` once a good fix lands. One bad reading never permanently strands a real visit.
- **Auto-detect, then confirm** — the nearest qualifying zoo becomes that day's visit zoo. If the user is near no known zoo, they may still log manually against a chosen zoo (the visit stays `unverified`).
- **Honest ceiling** — "verified" means *GPS placed you at the zoo*, not *you definitely saw the animal*. It's spoofable (mock-location apps, or standing at the gate). For a likes-only app that bar is high enough; no server-side anti-cheat is worth building now.

Access (§5) and verification are independent checks: a user must be *entitled* to a zoo to open it, and *present* to earn a verified visit. A free user logging at one of their three zoos still earns verification normally.

---

## 7. Privacy & safety

The constrained, Duolingo-style social model (no DMs, no uploads, curated avatars, likes only) removes most user-generated-content risk by construction. The residual items:

- **Default to private / friends-only.** Profiles and activity are not publicly searchable out of the box. You're UK-based and likely accessed by children, which points to the ICO **Age Appropriate Design Code** (the Children's Code): high-privacy defaults, data minimisation, and geolocation off-by-default and not persistently stored — all of which this design already follows. *(Not legal advice; worth reading the Code early, as it shapes defaults that are painful to retrofit.)*
- **Display names are filtered free text** — the one free-text surface left. A profanity/contact filter blocks bad language and contact-smuggling (e.g. "add me on snap…") and obvious impersonation ("Official London Zoo"), backed by a report path for anything that slips through.
- **Friend codes:** non-enumerable (never derived from sequential user IDs), regeneratable (roll a new one if leaked), redemption rate-limited server-side, unambiguous alphabet (no `0/O`, `1/I/l`), and **mutual-accept** required.
- **Block + report** are needed even in a likes-only model — Apple's and Google's review guidelines expect them once there's a social graph and display names. Cheap to add; design for them from the start.
- **Location permission:** request **when-in-use only**, at the moment of logging, with a clear purpose string ("to confirm you're at the zoo"). *(The iOS `Info.plist` currently has no location usage-description key at all — that would crash on first request and must be added regardless.)*
- **No raw GPS at rest** (§6) and **no free-text/images shared** (§4.7) — the strongest privacy posture is simply not holding the sensitive data.
- **Purchase data** is handled by the store/validation layer; store only what you need (product, transaction id, validated flag), never card details (you never see them).

---

## 8. Phasing: offline now → online later

**Phase 1 — offline-first content & logging (now).**
Reference data served by `ReferenceDataRepository` from the bundled seed, tolerant + validated + versioned. User data (visits, species-logs, profile-stub, entitlement cache) stored locally (Hive). Verification works fully offline (it only needs the device GPS + the bundled zoo coordinates). Two online touchpoints exist:
- the reference-data update path — present but a **no-op** until a host is configured; and
- **monetisation, which is online from day one** — pack purchases go through StoreKit / Play Billing and are validated via a validation service, with the validated entitlement cached so owned zoos open offline thereafter.

**Phase 2 — online & social.**
- Point `ReferenceDataRepository` at the real manifest URL — no app logic changes.
- Stand up a **managed backend** (recommended over a custom one for a solo dev): hosted auth + database + row-level authorisation, so user A can't read or write user B's data unless they're accepted friends, and even then only the `VisitSummary` projection. Supabase suits this app's relational, friends-scoped data well.
- Bind entitlements to the user's server account so they restore across devices via your account as well as the store.
- Sync user data: offline-first, last-write-wins is adequate for this model (single-user-owned records; no shared editing).
- Add profiles, friend codes, friend requests, likes, and the friends' activity feed — all over the `VisitSummary` boundary defined in §4.7.

The Phase-1 abstractions (repository boundary, visit/summary split, opaque stable IDs, privacy-by-default, server-validated entitlements) are exactly what make Phase 2 additive rather than a rewrite.

---

## 9. What changes in the current code

- **`DataLoader` → `ReferenceDataRepository`:** remove the hardcoded `inventories` and `knownZooPacks`; derive zoos from `zoos.json`; add manifest/version/validation/tolerant-loading; load catalog as UTF-8.
- **`Species` model:** add `iucnStatus` + `taxonomy`; drop catalog-level `zone`.
- **`Zoo` model:** add `location`, `radiusM`, `country`.
- **`Observation` → `Visit` + `SpeciesLog`:** introduce the `(zoo, day)` visit grouping; replace stored `lat`/`lng`/`accuracyM` with a `verified` status; outcomes become `seen`/`noShow`; keep an optional private `note`.
- **`SeenStore` → repository over visits/logs**, with the lifetime Dex computed as a derived view.
- **Access gating:** the zoo list and "open / start logging" run `canAccess`; locked zoos show an unlock CTA. Add purchase + restore flows (StoreKit / Play Billing via a validation service) and a locally-cached, server-validated `Entitlement`.
- **Fixes folded in along the way:** UTF-16 catalog, throw-on-unknown-id, missing iOS location key, deprecated `WillPopScope` → `PopScope`, the dead `SpeciesSearchScreen` (wire it in or remove), and the broken default widget test.
- **Secret:** rotate the hard-coded IUCN token; move it to an environment variable in `scripts/update_iucn.py`.

A one-time migration converts any existing flat `seen` records into a single synthetic "legacy" unverified visit per zoo, so early test data isn't lost.

---

## 10. Data integrity backlog (not blockers)

- Resolve the inventory IDs not present in the catalog (`acropora` for London; the elephant ID mismatch for Chester) — either add the species or correct/alias the ID.
- Backfill the 374 empty descriptions.
- Normalise the `group` vocabulary (it has both broad and narrow buckets, e.g. "Birds" alongside "Owls"/"Parrots").

---

## 11. Decisions

**Resolved (rev 3):**
- Visit lifecycle = one zoo per calendar day, no manual start/end (§4.1).
- Private per-species notes kept, self-only (§4.2).
- Manual logging against a chosen zoo allowed, stays unverified (§6).
- `VisitSummary` shows seen count only; no-show stays a private personal stat (§4.7).
- Display names = filtered free text with a profanity/contact filter + report path (§7).
- Free three picked as-you-go, locked at three, stated at signup (§5.1).
- Locked zoos shown with an unlock CTA (§5.2).
- Multi-country only via Unlimited; premium stays single home-country (§5.1).
- Backend (Phase 2) = **managed, Supabase** — built-in auth + row-level security suited to the friends-only model, and the gentlest path for a solo developer (§8).
- Apple **Family Sharing off at launch** — each account pays individually (as Duolingo and most one-time-unlock apps do); safe to enable later, disruptive to disable later (§5).

**Still open:** none. Phase 1 design is complete; build proceeds in the three slices listed in §9.
