# Catalogue data review

Run against the build with London, Chester, and the new Welsh Mountain Zoo.
Result: every inventory reference now resolves, taxonomy has no non-intentional
gaps, and every species has a valid IUCN code. Catalogue size: **754 species**.

## Fixed automatically

**22 species were referenced by Welsh Mountain Zoo but missing from the
catalogue.** 21 were added with full taxonomy + IUCN; 1 (`ailurus_fulgens`) was
aliased to the existing nominate entry instead of duplicated (see below).

Added: Yellow-banded Poison Dart Frog, Przewalski's Horse, Fallow Deer,
California Sea Lion, Red Squirrel, Brown Bear, European Pine Marten, Laughing
Kookaburra, Yellow-crowned Amazon, Galah, Kalij Pheasant, White-tailed Eagle,
Andean Condor, Chilean Flamingo, Red-faced Spider Monkey, Margay, Madagascar
Tree Boa, Madagascar Iguana, Spider Tortoise, Plain Tiger, Turkey Vulture.

**Taxonomy corrected (16 reptiles):** the order name (Squamata / Testudines /
Crocodylia) was sitting in the `class` field with `order` left blank. Set
`class` → `Reptilia` and `order` → the original value. Affected e.g.
`ophiophagus_hannah`, `macrochelys_temminckii`, `crocodylus_mindorensis`,
`pantherophis_guttatus`.

**Other taxonomy filled:** `cerithium` order → Caenogastropoda; `diadema` had a
fully blank taxonomy → filled (Echinodermata / Echinoidea / Diadematoida /
Diadematidae / Diadema).

**IUCN fixed:** `pan_troglodytes` had an invalid `EN/CR` → set to `EN`.

## ⚠ Verify these IUCN statuses against the current Red List

Statuses for the new species were filled from general knowledge; IUCN categories
change, so double-check the non-LC ones before relying on them:
Przewalski's Horse (EN), Red Panda alias (EN), Andean Condor (VU), Chilean
Flamingo (NT), Red-faced Spider Monkey (VU), Margay (NT), Spider Tortoise (CR).
Plain Tiger butterfly was set LC but invertebrate assessments are sparse — it may
be better recorded as NE.

## ⚠ Redundant entries to review (left as-is — your call)

These weren't changed because merging affects inventory references and any user
data; decide which to keep.

**Same species under two names (synonyms):**
- `lonchura_oryzivora` ↔ `padda_oryzivora` — both are the Java Sparrow. Keep one.

**Nominate subspecies that duplicates its own binomial species entry:**
- `argusianus_argus_argus` / `argusianus_argus`
- `geokichla_citrina_melli` / `geokichla_citrina`
- `gracula_religiosa_religiosa` / `gracula_religiosa`
- `helogale_parvula_undulatus` / `helogale_parvula`
- `lophotibis_cristata_urschi` / `lophotibis_cristata`
- `notamacropus_rufogriseus_rufogriseus` / `notamacropus_rufogriseus`
- `shinisaurus_crocodilurus_crocodilurus` / `shinisaurus_crocodilurus`
- `giraffa_camelopardalis_camelopardalis` / `giraffa_camelopardalis` (plus the
  distinct `giraffa_camelopardalis_reticulata`)

For each, keep either the binomial *or* the nominate trinomial, and point the
other at it via `aliases.json` (the same trick used for `ailurus_fulgens`).

**Generic genus-level entries overlapping specific species** (lower priority —
fine if you deliberately label a display "Montipora sp."): `montipora` (6 species
also present), `phoenicopterus` (3 flamingos present), `pavona`, `melanotaenia_sp`,
`hyphessobrycon`, `caulastrea`, `platygyra`, `porites`, `moenkhausia`,
`echinophyllia`, `ophiomastix`, `babyrousa_sp`.

## Intentional (not problems)

- **31 genus-level entries** carry a blank species epithet on purpose (corals and
  a few fish/inverts identified only to genus, e.g. `favia`, `montipora`,
  `ancistrus`). These are valid; the empty `species` field is expected.
- **~50 subspecies entries** with no binomial sibling (e.g. `panthera_leo_persica`
  Asiatic Lion, `panthera_tigris_sumatrae` Sumatran Tiger) are legitimate —
  zoos track these deliberately. Left untouched.

## Subspecies rollup — Tiger (first group)

`panthera_tigris` (Tiger) was added as a parent species, and the existing
`panthera_tigris_sumatrae` was converted into a child via `parent_id` +
`rank: "subspecies"`. Right now Sumatran is the *only* tiger subspecies in the
catalogue, so the Tiger page shows just the one subspecies chip.

Chips are derived from the catalogue at load: adding another tiger subspecies
entry with `parent_id: panthera_tigris` makes its chip appear automatically (and
it shows greyed until you've logged it) — no code change needed. A species with
no subspecies entries just shows the normal species page.

## Automatic subspecies grouping (by naming convention)

Subspecies now group under their species automatically at load: any entry with a
three-word (trinomial) scientific name is linked to the entry whose two-word
(binomial) name matches — no `parent_id` needed. Adding a species like
`Giraffe` (Giraffa camelopardalis) instantly groups every `Giraffa camelopardalis
<x>` under it.

Grouped today: Giraffe (Nubian, Reticulated), Plains Zebra (Burchell's,
Chapman's), Forsten's Lorikeet (Scarlet-Breasted, Mitchell's), Tiger (Sumatran),
Great Argus, Domestic Goat. `Plains Zebra` (NT) and `Forsten's Lorikeet` parents
were added — verify the lorikeet's species-level IUCN.

**Deliberately NOT auto-created:** ~46 single-subspecies entries (e.g. Asiatic
Lion, Western Lowland Gorilla, Red Panda) have no binomial parent in the
catalogue, so they stay standalone. We don't invent a generic parent because the
derived name is usually wrong or absurd ("Red Panda" → "Panda", "Black-Headed
Spider Monkey" → "Monkey"). To group any of these, add the parent species entry
(e.g. `Lion` / Panthera leo) and the subspecies link themselves.
