# Catalogue data conventions and known issues

This document records the data conventions the catalogue follows and the issues that remain open. The catalogue currently holds about 791 entries.

## Conventions

Every species has an opaque id and a readable slug. The id is stable; the slug is for authoring and display.

Merges and renames are handled through `aliases.json`. When an entry is merged or renamed, its old id and old slug alias forward to the canonical id, so inventory references and stored sightings keep resolving without edits to the data that points at them.

Genus-level entries, which carry a blank species epithet, are acceptable for invertebrates that zoos cannot identify to species (corals, some snails, some fish). They are not acceptable for vertebrates: a vertebrate entry should identify to a real species.

## Resolved

The two known duplicate species have been merged:

- Java Sparrow: `Lonchura oryzivora` was merged into the canonical `Padda oryzivora`, common name "Java Sparrow".
- Mindanao Bleeding-Heart Dove: `Gallicolumba criniger` was merged into `Gallicolumba crinigera`.

In both cases the removed slugs and ids alias forward to the canonical entry.

A number of items from the original catalogue review have also been addressed: encoding problems, missing inventory references, reptile taxonomy gaps (order names sitting in the `class` field), and redundant nominate duplicates.

## Known issue to resolve

Six vertebrate entries currently identify only to genus and should be replaced with real species:

- Flamingo / Phoenicopterus
- Bristlenose Catfish / Ancistrus
- Tetra / Hyphessobrycon
- Tetra / Moenkhausia
- Hillstream Loach / Physoschistura
- Torpedo Cichlid / Rhamphochromis

They are listed in `tools/reports/vertebrate_genus_only.md`.

## Remaining backlog

- Most species descriptions are still empty. This is a content task, not a bug.
- The fine-grained "group" vocabulary mixes broad and narrow buckets and could be normalised.
- Some IUCN statuses were entered from general knowledge and should be confirmed against the current Red List, particularly for the parent species added during the subspecies work.
