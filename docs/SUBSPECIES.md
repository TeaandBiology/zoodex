# Subspecies and breeds

ZooDex uses a two-level model for animals that zoos track below the species level. This document describes how that model works, how the loader builds it, and how to add new subspecies or breeds.

## The two-level model

A parent species is a normal catalogue entry of rank `species`. Below it sit child entries of rank `subspecies` or `breed`. A child carries a `parent_id` pointing at its parent species. The `parent_id` is authored as a slug and resolved to an opaque id when the catalogue loads, so authors work with readable names while the runtime works with stable ids.

```jsonc
{
  "slug": "panthera_tigris_sumatrae",
  "common_name": "Sumatran Tiger",
  "scientific_name": "Panthera tigris sumatrae",
  "rank": "subspecies",
  "parent_id": "panthera_tigris"
}
```

The parent ("Tiger", `Panthera tigris`, rank `species`) is an ordinary entry. Identity stays opaque-id based, and `aliases.json` keeps resolving old references.

## Rollup

The Species tab shows one card per parent species; children never appear as their own cards. An entry with no children renders as a normal species card.

The species page for a parent shows a chip selector of its children: an "All" chip plus one chip per subspecies or breed. Each chip carries its own seen state, so a child shows greyed until it has been logged. Selecting a chip switches the description, range map, IUCN status, and "seen at" list to that child; "All" shows the aggregate.

A sighting always stores the most specific id the zoo offered (the subspecies or breed). The rollup to the parent is derived, so no data is lost. A zoo that lists only "Tiger" produces a sighting against the parent id itself.

## Two grouping mechanisms in the loader

Grouping is built in `lib/data/reference_data.dart` by two mechanisms:

1. **Explicit `parent_id`.** A child names its parent species by slug. This is the authoritative link and works regardless of naming.

2. **Automatic linking by naming convention.** Any entry whose scientific name is a trinomial (three words) is linked under the entry whose binomial (two words) matches, provided that binomial species exists in the catalogue. No `parent_id` is needed when the binomial parent exists. For example, adding `Giraffe` (Giraffa camelopardalis) automatically groups every `Giraffa camelopardalis <x>` entry under it.

The two mechanisms coexist: use auto-linking where a binomial parent is present, and explicit `parent_id` everywhere else.

## Breeds and domestic animals

Domestic species carry `domestic: true` and rank `species`. Their breeds carry rank `breed`, `domestic: true`, and a `parent_id` pointing at the domestic species.

Implemented:

- Alpaca (Vicugna pacos), with the Huacaya and Suri breeds.
- Domestic Pig (Sus domesticus), with the Mangalitsa breed.
- Domestic Goat (Capra hircus), with the West African Pygmy Goat breed.
- Ferret, a standalone domestic species with no breeds.

The species page heading reads "Breeds" when all children are breeds, and "Subspecies" otherwise.

## Catalogue changes made for this model

About 40 parent species were added so that single standalone subspecies roll up to a species. Examples:

- Asiatic Lion under Lion.
- Western Lowland Gorilla under Western Gorilla.
- Eastern Black Rhinoceros under Black Rhinoceros.

A few genus names were updated to current taxonomy while their parents were added:

- Elaphe taeniura to Orthriophis taeniurus.
- Garrulax ocellatus to Ianthocincla ocellata.
- Rucervus eldii to Panolia eldii.

The Scottish Wildcat was folded into a single Felis silvestris (European Wildcat) entry. The contested Laudakia/Stellagama genus move was left as Laudakia.

## Adding a new subspecies or breed

There are two ways to attach a child to a parent:

- Set `parent_id` (the slug of the parent species) and the appropriate `rank` (`subspecies` or `breed`). This is required for breeds and for any subspecies whose binomial parent is not in the catalogue.
- For a subspecies, rely on trinomial-to-binomial auto-linking when the binomial parent already exists. No `parent_id` is needed.

A typo in a scientific name silently breaks auto-linking, because the trinomial no longer matches any binomial. Explicit `parent_id` is therefore more robust, and is preferred where correctness matters.

## Range maps

Range maps follow the same parent fallback as the rest of the model: a subspecies with no range map of its own falls back to the parent species range. See docs/RANGE_MAPS.md for details.
