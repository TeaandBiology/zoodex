# ZooDex - Data Model & Architecture

> This is the design and rationale document for ZooDex: why the data model,
> location verification, privacy, and payment choices are the way they are. It
> documents the architecture of the current implementation, not a future plan.
> Read it for the *why*; read the code and `README.md` for the *what*. Section
> references like "§6" point to the numbered sections within this document.

**Purpose:** A single reference for how data is structured, updated, verified,
gated, and (later) synced, so the species and zoo databases can grow without
breaking the app, and the offline-now and social-later phases share one set of
rails.

ZooDex is a Flutter, offline-first app. Bundled reference data lives in
`assets/data/` as JSON; user data lives on the device in Hive. Only the zoo map
needs the internet (OpenStreetMap tiles); everything else works offline.

---

## 1. Core principle: two kinds of data

Everything in the app is one of two kinds, with different owners, lifetimes, and
trust models. Keeping them separate is the single most important structural
decision.

| | **Reference data** | **User data** |
|---|---|---|
| Examples | species catalogue, zoos, per-zoo inventories, avatar roster | visits, per-species seen/no-show, profile, friends, likes, entitlements/purchases |
| Owned by | the project / the server | the user / the device |
| App's view | read-only | read-write |
| Updated by | publishing a new version (no app release) | the user, as they use the app |
| Trust | validated before use | private by default; minimal sharing |
| Phase 2 | served from a CDN/API | synced to the backend |

A single component, the **`ReferenceDataRepository`**, owns all reference data
and hides where it comes from (a bundled copy today, a remote source later). A
separate component owns user data. The two never blur together. This is what
lets "add a zoo" be a data change rather than a code change, and lets the social
and paid features bolt on without a rewrite.

---

## 2. Identity & ID stability (the load-bearing rule)

User observations are keyed by species and zoo IDs. If an ID ever changes
upstream, every observation keyed to the old ID orphans. This is cheap to get
right and very expensive to retrofit once real users have data.

**Rules:**

1. Every species, zoo, and avatar has a permanent `id` that is assigned once and
   never changed or reused.
2. `id` is treated as **opaque**. Names, including `scientific_name`, are mutable
   attributes, not identity. (Scientific names get revised by taxonomists; if the
   ID is derived from the name, a revision silently orphans data.)
3. Renaming an entity (common or scientific name) does not change its `id`.
4. If two entries must be merged (a duplicate, or a split/lump in taxonomy), one
   `id` stays canonical and the other is recorded in an alias table so old
   references, including stored user observations, resolve forward.

**Scheme.** Species use an **opaque** id (for example `sp_5e365fabed63`), with the
readable name carried as a separate, non-identity **`slug`** attribute (for
example `panthera_tigris`). Opacity removes any temptation to derive ids from
names and survives the bulk imports and taxonomic churn that species data
attracts. **Users** likewise get opaque ids: a local UUID (`Profile.userId`) is
minted once on the device and is Supabase-native for Phase 2. **Zoos keep
readable, frozen ids** (`london_zoo`): the set is small and hand-curated, a
rebrand changes the `name` not the id, and it keeps inventory filenames legible.
The `slug` lets inventories and humans refer to a species by `elephas_maximus`;
the loader resolves it to the opaque id. A `sources` block holds external
authority ids (IUCN `sis_id`, GBIF `gbif_id`) so the data pipeline can key off a
stable external id instead of re-matching scientific names.

**Aliases** (`aliases.json`, reference data) map old or merged ids and old slugs
forward to the canonical id:

```json
{ "aliases": { "old_or_merged_id": "canonical_id" } }
```

Resolution order everywhere: look up `id`; if absent, follow the aliases; if
still absent, match a species `slug`; if still absent, treat as unknown (skip and
log, see §3.1).

---

## 3. Reference data

### 3.1 Versioning & the update mechanism

This is the heart of "update constantly without breaking." Reference data is
published as versioned datasets described by a **manifest**.

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

- **`schema_version`** is bumped only on a breaking shape change. The app declares
  the maximum schema it understands. If the remote `schema_version` is higher, the
  app ignores the remote data and keeps what it has, so a new dataset can never
  break an old app.
- **`version`** (per dataset) is monotonic. The app downloads a dataset only when
  the remote `version` is greater than the locally cached `version`.
- **`sha256`** is an integrity check. A dataset that fails its checksum is
  rejected, and the previous good copy is kept.

**App flow:**

1. Ship a bundled seed copy (manifest and all datasets) so the app works fully
   offline on first launch, before it has ever reached the network.
2. On launch or periodically, fetch the remote manifest.
3. For each dataset where `remote.version > cached.version` and `schema_version`
   is compatible: download, validate (schema and checksum), then atomically swap
   into the local cache.
4. Until a remote host exists, step 2 is a no-op. Going online later is a config
   change, not new architecture.

**Tolerant loading.** Loading reference data never throws on bad input:

- Unknown fields are ignored.
- An inventory item with an unknown or unresolvable `species_id` is skipped and
  logged, not fatal.
- An individual entry that fails validation is skipped, not fatal; the rest still
  load.
- A whole dataset that fails to parse or validate is discarded, keeping the last
  good cached or bundled copy.

### 3.2 Species (catalogue)

The catalogue (`species_catalog.json`) holds roughly 791 species and subspecies
entries.

```json
{
  "id": "sp_5e365fabed63",
  "slug": "panthera_tigris",
  "common_name": "Tiger",
  "scientific_name": "Panthera tigris",
  "group": "Mammals",
  "description": "",
  "long_description": "",
  "iucn_status": "EN",
  "rank": "species",
  "parent_id": null,
  "domestic": false,
  "range_map": null,
  "image_credit": null,
  "taxonomy": {
    "kingdom": "Animalia", "phylum": "Chordata", "class": "Mammalia",
    "order": "Carnivora", "family": "Felidae",
    "genus": "Panthera", "species": "tigris", "subspecies": null
  },
  "sources": { "sis_id": null, "gbif_id": null }
}
```

Fields:

- **`id`** is opaque and permanent (§2); the readable name lives in **`slug`** as a
  non-identity attribute.
- **`common_name`** and **`scientific_name`** are display attributes, both mutable.
- **`group`** is a broad grouping used by the Species tab.
- **`description`** is a short default blurb shown at the top of the species page.
  Many entries are currently empty; that is a data-quality backlog item (§10), not
  a blocker.
- **`long_description`** is an optional longer write-up shown under the range map
  on the Species-tab page.
- **`iucn_status`** is a controlled vocabulary: `EX, EW, CR, EN, VU, NT, LC, DD,
  NE, NA` (plus the absence of a value). The UI maps these to labels and colours.
- **`rank`** is one of `species`, `subspecies`, or `breed` (§3.3).
- **`parent_id`** points to the parent species for subspecies and breeds. It is
  authored in the catalogue as a slug and resolved to the opaque parent id at load
  (§3.3).
- **`domestic`** marks domestic animals; it feeds the range-map handling (§6.5).
- **`range_map`** and **`image_credit`** support the range-map plumbing (§6.5).
- **`taxonomy`** holds the full taxonomic chain, including an optional
  `subspecies`.
- **`sources`** holds external authority ids (IUCN `sis_id`, GBIF `gbif_id`),
  empty for now, populated by the data pipeline so it can key off a stable external
  id rather than re-matching names.

`zone` is not a catalogue field. A zone is where a species sits at a given zoo, so
it lives on the inventory item (§3.4), not on the species. The catalogue is loaded
as UTF-8.

### 3.3 Subspecies & breeds

A two-level model is implemented. Subspecies and breed entries carry `rank`
(`subspecies` or `breed`) and a `parent_id` pointing at the parent species. The
Species tab rolls children up to the parent species so each species shows as one
card, and the species page shows a chip selector of its children. `parent_id` is
authored as a slug and resolved to the parent's opaque id at load. See
`docs/SUBSPECIES.md` for the full model.

### 3.4 Zoos

Three zoos are bundled: London Zoo, Chester Zoo, and the Welsh Mountain Zoo. All
three have real coordinates and `coords_set: true`.

```json
{
  "id": "london_zoo",
  "name": "London Zoo",
  "lat": 51.5353,
  "lng": -0.1534,
  "radius_m": 500,
  "coords_set": true,
  "country": "GB",
  "last_updated": "2026-02-15"
}
```

The `Zoo` model fields are `id`, `name`, `lat`, `lng` (nullable), `radiusM`,
`country`, `coordsSet`, and `lastUpdated`. Derived behaviour:

- **`lat` / `lng`** are the authoritative centre point. They are nullable; a zoo
  without coordinates cannot be verified or pinned on the map.
- **`coordsSet`** records whether real coordinates have been set by hand.
  `hasLocation` requires `coordsSet` to be true and both `lat` and `lng` to be
  present, so verification cannot confirm a zoo until its real centre is set.
- **`radiusM`** is per-zoo and set by hand, because a global radius fails: too
  small misses people deep inside a large site; too large verifies the car park
  next door. A compact urban zoo is roughly 300 to 500 m; a large zoo or safari
  park can be several km. For oddly shaped sites a bounding polygon is a possible
  future upgrade; a generous radius works to start.
- **`country`** drives both display grouping and the premium entitlement scope
  (§5): premium unlocks every zoo whose `country` matches the user's home country.

The known-zoo list is derived from `zoos.json`, not hardcoded; the app lists
whatever zoos the data declares.

### 3.5 Inventories (per zoo)

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

- `items[].species_id` references the catalogue by permanent ID, resolved via §2
  including aliases.
- `items[].zone` is optional and is the per-zoo placement. This is the only place
  `zone` lives. A zone of `"Unknown"` or blank is treated as no zone and hidden.
- `items[].description` is an optional per-zoo description. It overrides the
  species' short default `description` on that zoo's page, letting the same species
  read differently at each zoo (directions, keeper-talk times, and so on). At load
  it is placed on a transient `zooDescription` on the per-zoo copy of the species.
- An unknown `species_id` is skipped and logged, never fatal.

### 3.6 Avatars (roster)

The avatar roster is another versioned reference dataset, with the same loading,
validation, and update path as species and zoos.

```json
{
  "version": 2,
  "avatars": [
    { "id": "avatar_red_panda", "asset": "assets/avatars/red_panda.png", "tags": ["mammal"] },
    { "id": "avatar_axolotl",   "asset": "assets/avatars/axolotl.png",   "tags": ["amphibian"] }
  ]
}
```

A user's profile stores only an `avatar_id`. Adding new avatars is a data change
with no new machinery.

---

## 4. User data

### 4.1 Visit (first-class entity): one zoo, one day

A visit is one zoo on one calendar day. Its identity is `(zooId, localDate)`, and
it owns that day's logs. This deliberately removes any manual "start/end visit"
step: opening and closing the app throughout a day never fragments the visit, and
there is nothing for the user to manage. The first log of the day at a given zoo
creates that day's visit; every later log that day attaches to it. Visiting two
zoos in one day is simply two visits.

```dart
class Visit {
  final String id;                    // local id (server id added in Phase 2)
  final String zooId;                 // auto-detected when verified; chosen otherwise
  final DateTime date;                // local calendar date, midnight-normalised
  VerificationStatus verified;        // verified | unverified | skipped, upgradeable through the day
  final DateTime firstLoggedAt;
  DateTime lastLoggedAt;
}
```

- The day boundary is the user's local date. A rare late event spanning midnight
  splits into two days, which is acceptable and not worth special-casing.
- `verified` can be upgraded at any point during the day (see §6): a first log
  made from memory at home is `unverified`, but if the user later opens the app at
  the zoo and GPS confirms, that same day's visit becomes `verified`.

### 4.2 Per-species outcome

Within a visit, each species the user acts on gets one record. There are three
states, and the default state is the absence of a record:

- **seen**: logged a sighting.
- **noShow**: explicitly looked, the animal was not on display.
- **unassessed**: the default for every species not acted on (no record stored).

This three-state design matters: an inventory can run to hundreds of species, so
"not marked seen" must not be read as "no-show." No-show is an explicit, optional
tap: light absence data and a gentle completion stat for the keen, never a chore,
and never shown socially (§4.7).

```dart
class SpeciesLog {
  final String visitId;
  final String speciesId;
  final Outcome outcome;      // seen | noShow
  final DateTime loggedAt;
  final String? note;         // PRIVATE personal note, optional, never shared
}
```

Per-observation private notes, edit, and delete all exist.

### 4.3 The "Dex" (derived, not stored)

A user's lifetime collection is a view computed by folding visits and species
logs, never a separate source of truth (which would drift). Per species:

- `seenEver` (bool), `firstSeenAt`, `lastSeenAt`
- `visitsSeenCount`
- `everVerified` (seen on at least one verified visit)
- `zoosSeenAt` (set of zoo IDs)

### 4.4 Profile & local identity

On first launch a local setup flow collects a display name, an `@username`, an
avatar, a home country (set once), and the first free zoo. A permanent local user
id (a UUID, `Profile.userId`) is minted once and acts as the seed for a future
anonymous or linked backend account, so Phase 2 can adopt silent anonymous
authentication (no login screen) and later optional account linking. An
`onboardingComplete` flag is persisted.

```dart
class Profile {
  final String userId;        // local UUID, the Phase-2 account seed
  final String displayName;   // filtered free text (see §7)
  final String username;      // @username
  final String avatarId;      // from the roster
  final String homeCountry;   // set once
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

A friend code produces a request the recipient must accept, never an auto-add, so
an adult who obtains a child's code cannot unilaterally start following them.

### 4.6 Likes

```dart
class Like {
  final String userId;
  final String targetType;    // "visitSummary" (the only likeable unit, for now)
  final String targetId;
  final DateTime createdAt;
}
```

Likes are the only user-to-user interaction. No comments, no messages.

### 4.7 The social boundary: shareable summary vs private detail

Only one projection ever crosses to other users. Everything else stays private.

```dart
class VisitSummary {     // the ONLY thing friends can see / like
  final String visitId;
  final String userId;
  final String zooId;
  final String zooName;
  final DateTime date;          // coarse (day-level)
  final int speciesSeenCount;   // seen count only, no-show stays private
  final bool verified;
  // NO coordinates. NO notes. NO no-show or per-species detail.
}
```

Because GPS is never persisted (§6) and notes are private (§4.2), there is almost
nothing sensitive to leak even by accident, which is the whole point.

---

## 5. Monetisation & access (entitlements)

Zoo access is a paid feature, sold as one-time unlocks. Access is a derived check
over the user's entitlement plus `zoo.country`; it never touches reference data,
so adding zoos does not change anyone's access logic. Home country is stored once
in the `EntitlementStore`.

### 5.1 Tiers

| Tier | Grants | Notes |
|---|---|---|
| **Free** | Any **3** zoos the user picks | Picked as the user goes; locked once full |
| **Premium** (one-time) | All zoos in the user's **home country** | Home country set once |
| **Unlimited** (one-time) | All zoos, globally | Supersedes the others |

- **Free three:** unlocked as the user goes; each zoo they choose to open counts
  toward the three, and the set is locked once full, so a free user cannot rotate
  through the whole catalogue. The three-free allowance is stated explicitly during
  account creation, so it is never a surprise.
- **Premium** is scoped to a single home country, set once (store region or device
  locale as the default, user-confirmed) and not user-editable afterwards (support
  override only), otherwise it could be re-pointed to gain access elsewhere.
- **Unlimited** is a strict superset and short-circuits every check. It is also the
  only path to more than one country; there is no second-country premium, so a
  multi-country traveller buys Unlimited.

### 5.2 Entitlement record (user data)

```dart
class Entitlement {
  final String userId;
  final EntitlementTier tier;     // free | premiumCountry | unlimited
  final String? premiumCountry;   // e.g. "GB", set iff tier == premiumCountry
  final List<String> freeZooIds;  // up to 3, append-only, locked when full
  final DateTime updatedAt;
}

bool canAccess(Zoo zoo, Entitlement e) =>
    e.tier == EntitlementTier.unlimited ||
    (e.tier == EntitlementTier.premiumCountry && zoo.country == e.premiumCountry) ||
    e.freeZooIds.contains(zoo.id);
```

All zoos stay visible to everyone, so users can see what they could unlock; access
is gated at "open / start logging," and locked zoos carry a clear unlock
call-to-action.

### 5.3 Purchases & validation

The unlocks are digital content, so they are sold through the platforms' in-app
purchase systems: Apple StoreKit and Google Play Billing (roughly 15 to 30 percent
commission); third-party processors are not permitted for these on mobile. Both
plans are non-consumable products, and Apple requires a working Restore Purchases
flow.

The entitlement is server-validated, never a bare device flag, because a local
boolean is trivially flipped on a rooted device. A validation layer (for example a
service such as RevenueCat over StoreKit and Play Billing, or a minimal backend)
verifies the store receipt and is the source of truth; the validated result is
cached locally so that:

- a user who already owns a zoo can open it offline, and
- only the purchase itself requires connectivity.

Store-initiated refunds revoke the entitlement (receipt re-check or webhook), and
restore re-grants it on a new device.

```dart
class Purchase {              // the money ledger, kept distinct from all other records
  final String productId;     // maps to a tier (+ country for premium)
  final String platform;      // appStore | playStore
  final String transactionId; // store transaction / original id
  final bool validated;
  final DateTime purchasedAt;
}
```

A `productId -> (tier, country?)` mapping lives in config, so new country-premium
SKUs can be added without code changes. There is a single money ledger and no
charity flow (donations were considered and dropped).

During development, purchases are simulated by `DevPurchaseService`. The path to
validated, live in-app purchases is documented in `docs/GOING_LIVE_IAP.md`.

---

## 6. Location verification & maps

### 6.1 Verification

GPS exists for exactly one job: confirm the user is genuinely at a zoo, to grant a
visit `verified` status, after which the coordinates are discarded. It
auto-detects which zoo. It is a badge, not a gate: logging is never blocked;
verification is the reward for a real visit.

The algorithm runs whenever the app has reason to think the user may be at a zoo
(for example on opening at a location, or on logging), and is re-runnable through
the day:

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

- **Verify once per day per zoo, inherit to every log.** No GPS check per species
  tap (battery, friction, and indoor GPS is unreliable exactly where people log:
  aquariums, reptile houses).
- **Account for accuracy** (`d - accuracy <= radius`) so a noisy fix inside the
  zoo still verifies.
- **Upgradeable.** A poor or absent fix earlier in the day can become `verified`
  once a good fix lands. One bad reading never permanently strands a real visit.
- **Auto-detect, then confirm.** The nearest qualifying zoo becomes that day's
  visit zoo. If the user is near no known zoo, they may still log manually against
  a chosen zoo, and the visit stays `unverified`.
- **Honest ceiling.** "Verified" means GPS placed the user at the zoo, not that
  they definitely saw the animal. It is spoofable (mock-location apps, or standing
  at the gate). For a likes-only app that bar is high enough; no server-side
  anti-cheat is worth building now.

Access (§5) and verification are independent checks: a user must be entitled to a
zoo to open it, and present to earn a verified visit. A free user logging at one
of their three zoos still earns verification normally.

### 6.2 Zoo map

The Zoos tab opens to a map (`flutter_map` plus OpenStreetMap) showing one pin per
zoo with `coords_set` true, with a toggle to a list view. The map requests
location on open so it can centre on the user. This is the one feature that needs
the internet (for the OpenStreetMap tiles); everything else works offline.

### 6.3 Range maps

The in-app plumbing for range maps is built: a `RangeMap` widget with a
slug-keyed fallback chain, a `domestic` flag, a Range section on the species page,
and placeholder assets. The map images themselves are deferred. See
`docs/RANGE_MAPS.md`.

---

## 7. Privacy & safety

The constrained, Duolingo-style social model (no DMs, no uploads, curated avatars,
likes only) removes most user-generated-content risk by construction. The residual
items:

- **Default to private / friends-only.** Profiles and activity are not publicly
  searchable out of the box. ZooDex is UK-based and likely accessed by children,
  which points to the ICO Age Appropriate Design Code (the Children's Code):
  high-privacy defaults, data minimisation, and geolocation off by default and not
  persistently stored, all of which this design follows. (Not legal advice; the
  Code is worth reading early, as it shapes defaults that are painful to retrofit.)
- **Display names are filtered free text**, the one free-text surface left. A
  profanity and contact filter blocks bad language and contact-smuggling (for
  example "add me on snap…") and obvious impersonation ("Official London Zoo"),
  backed by a report path for anything that slips through.
- **Friend codes:** non-enumerable (never derived from sequential user IDs),
  regeneratable (roll a new one if leaked), redemption rate-limited server-side,
  built from an unambiguous alphabet (no `0/O`, `1/I/l`), and mutual-accept
  required.
- **Block and report** are needed even in a likes-only model; Apple's and Google's
  review guidelines expect them once there is a social graph and display names.
  They are cheap to add, so the design accounts for them from the start.
- **Location permission** is requested when-in-use only, at the moment of logging,
  with a clear purpose string ("to confirm you're at the zoo").
- **No raw GPS at rest** (§6) and **no free-text or images shared** (§4.7). The
  strongest privacy posture is simply not holding the sensitive data.
- **Purchase data** is handled by the store and validation layer; store only what
  is needed (product, transaction id, validated flag), never card details (the app
  never sees them).

---

## 8. Phasing: offline now, online later

**Phase 1: offline-first content and logging (current).** Reference data is served
by `ReferenceDataRepository` from the bundled seed, tolerant, validated, and
versioned. User data (visits, species logs, profile, entitlement cache) is stored
locally in Hive. Verification works fully offline (it needs only the device GPS
and the bundled zoo coordinates). The reference-data update path exists but is a
no-op until a host is configured. During development, purchases are simulated by
`DevPurchaseService`; the live in-app purchase path is documented separately
(§5.3).

**Phase 2: online and social.**

- Point `ReferenceDataRepository` at the real manifest URL, with no app logic
  changes.
- Stand up a managed backend (Supabase), which suits this app's relational,
  friends-scoped data: hosted auth, database, and row-level authorisation, so user
  A cannot read or write user B's data unless they are accepted friends, and even
  then only the `VisitSummary` projection. The Phase-1 `Profile.userId` is the seed
  for the Phase-2 account, so Phase 2 can adopt silent anonymous authentication and
  later optional account linking.
- Bind entitlements to the user's server account so they restore across devices via
  the account as well as the store. Purchases move from `DevPurchaseService` to
  validated in-app purchases (§5.3).
- Sync user data: offline-first, last-write-wins is adequate for this model
  (single-user-owned records; no shared editing).
- Add profiles, friend codes, friend requests, likes, and the friends' activity
  feed, all over the `VisitSummary` boundary defined in §4.7.

The Phase-1 abstractions (the repository boundary, the visit/summary split, opaque
stable IDs, privacy by default, server-validated entitlements, and the permanent
local user id) are exactly what make Phase 2 additive rather than a rewrite.

---

## 9. Settled design decisions

- Reference data and user data are kept strictly separate, behind a single
  `ReferenceDataRepository` for reference data (§1).
- Species use opaque permanent ids with a readable `slug` as a non-identity
  attribute; aliases resolve old ids and slugs forward; zoos keep readable frozen
  ids (§2).
- Reference data loads tolerantly: unknown species ids are skipped and logged, bad
  entries are skipped, and a bad dataset falls back to the last good copy (§3.1).
- The species catalogue is UTF-8, carries `iucn_status` and `taxonomy`, and does
  not carry `zone`; zone lives on the inventory item (§3.2, §3.5).
- Subspecies and breeds use a two-level `rank` + `parent_id` model that rolls up to
  the parent species (§3.3).
- Descriptions are layered: a short `description`, an optional species-level
  `long_description`, and an optional per-zoo description on the inventory item
  (§3.2, §3.5).
- A visit is one zoo per calendar day, with no manual start/end (§4.1).
- Per-species private notes are kept, self-only, with edit and delete (§4.2).
- Manual logging against a chosen zoo is allowed and stays unverified (§6.1).
- `VisitSummary` shows the seen count only; no-show stays a private personal stat
  (§4.7).
- Display names are filtered free text with a profanity and contact filter plus a
  report path (§7).
- The free three are picked as-you-go, locked at three, and stated at signup
  (§5.1).
- Locked zoos are shown with an unlock call-to-action (§5.2).
- Multi-country access is only via Unlimited; premium stays single home-country
  (§5.1).
- The Phase-2 backend is managed (Supabase), for built-in auth and row-level
  security suited to the friends-only model and the gentlest path for a solo
  developer (§8).
- The local `Profile.userId` is minted once as the seed for a future anonymous or
  linked backend account (§4.4, §8).

---

## 10. Data integrity backlog (not blockers)

- Backfill the empty species `description` blurbs.
- Normalise the `group` vocabulary where it mixes broad and narrow buckets (for
  example "Birds" alongside "Owls" and "Parrots").
- Produce the range-map images that the `RangeMap` plumbing already supports
  (§6.3).
