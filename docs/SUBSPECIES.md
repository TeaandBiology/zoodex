# Handling subspecies

## The problem

The catalogue currently mixes two approaches with no rule:

- Some animals are split into **subspecies entries** — `panthera_tigris_sumatrae`
  (Sumatran Tiger), `panthera_leo_persica` (Asiatic Lion), several zebras and
  giraffes — each a separate top-level "species" in the Dex.
- Others are single **binomial species** — `panthera_pardus` (Leopard).
- Until this pass there were also **redundant nominate duplicates** (e.g.
  `notamacropus_rufogriseus` *and* `notamacropus_rufogriseus_rufogriseus`),
  now removed.

So today a user who sees a Sumatran Tiger and a Siberian Tiger gets two unrelated
Dex rows and no "Tiger" concept; totals are fragmented; and the split is
inconsistent across the catalogue. We need one model.

## Options

**A. Full split (status quo-ish).** Every subspecies is its own Dex entry.
Simplest data model, but the Species tab fills with near-duplicates, there's no
roll-up ("how many tigers have I seen?"), and it only works where someone
bothered to split.

**B. Species only.** Collapse everything to the binomial. One "Tiger" row.
Clean, but throws away the exact thing zoo-goers care about — *which* tiger —
and the per-subspecies range/þreat differences.

**C. Two-level: parent species + child subspecies (your proposal).** The Dex
shows the parent ("Tiger"). Its page has a subspecies selector ("All",
"Sumatran", "Siberian"…) with per-subspecies description, range map, IUCN, and
the zoos where each was seen, plus an aggregate total. Zoo inventories reference
the **subspecies** (the actual viewable animal — "Sumatran Tiger at London").
Richest and matches how zoos label enclosures, but needs schema + UI work.

**D. Hybrid (C, made migration-friendly).** Keep entries flat, but give a
subspecies an optional `parent_id` pointing at a parent species entry. Where
`parent_id` is set, the Dex groups children under the parent; where it isn't,
the entry shows as-is. This is option C with a gentle, non-breaking rollout —
you can convert one genus at a time.

## Recommendation: D → C

Adopt the two-level model, rolled out via an optional `parent_id` link so
nothing breaks on day one. Concretely:

### Schema (additive, backwards-compatible)

Add two optional fields to a catalogue entry; the loader defaults them, so old
data keeps working:

```jsonc
{
  "id": "sp_…", "slug": "panthera_tigris_sumatrae",
  "common_name": "Sumatran Tiger",
  "scientific_name": "Panthera tigris sumatrae",
  "rank": "subspecies",          // NEW: "species" (default) | "subspecies"
  "parent_id": "sp_<tiger>",     // NEW: set on subspecies -> parent species id
  …
}
```

The parent ("Tiger", `Panthera tigris`, `rank: "species"`) is a normal entry.
Identity stays opaque-id based; `aliases.json` keeps resolving old refs. A zoo
inventory keeps referencing whatever it displays — usually the subspecies.

### Dex aggregation

`buildDex()` groups sightings by `parent_id ?? speciesId`. A `DexEntry` for a
parent gains a per-subspecies breakdown (which children, how many, where). A
sighting always stores the **most specific** id the zoo offered (the subspecies);
the roll-up is derived, so no data is lost and "unspecified Tiger" is just a
sighting whose id is the parent itself.

### UX

- **Species tab:** one row per parent ("Tiger"); subspecies never appear as
  their own rows. Animals with no subspecies are unchanged.
- **Species page:** if children exist, a selector at the top — `All ·
  Sumatran · Siberian · …` — switches the description / range map / IUCN /
  "seen at" list. `All` shows the aggregate and which subspecies you've logged.
- **Logging:** at a zoo you log the subspecies on display. If a zoo only says
  "Tiger", you log the parent (an "unspecified" child).

## Migration plan

1. **Schema groundwork (non-breaking):** add `rank` + `parent_id` to the
   `Species` model + loader, defaulted. No UI change yet. *(I can do this now.)*
2. **Data:** pick the genera zoos track at subspecies level (tigers, lions,
   giraffes, zebras, leopards, gorillas, orangutans…). Ensure each has a parent
   species entry and set `parent_id` on the children. Decide parent common-name
   conventions.
3. **Dex roll-up:** group by `parent_id ?? id`; extend `DexEntry`.
4. **UI:** subspecies selector on the species page; Species tab shows parents.
5. **Range maps / per-subspecies images:** new asset type; ties into
   `IMAGES_ONDEMAND.md`. Defer until after the above.

## Decisions needed from you

- **Scope:** model *every* animal that has multiple subspecies, or only those
  where zoos actually differ (lighter)?
- **Parent naming:** "Tiger" vs "Tiger (Panthera tigris)" in the Species tab.
- **Parent seeability:** confirm the parent is a grouping you reach *through* a
  subspecies (recommended), with a generic "unspecified" child for zoos that
  don't specify.
- **Range maps:** in scope now, or a later pass?

Say the word and I'll start with step 1 (the schema groundwork), which is safe
and unlocks the rest incrementally.
