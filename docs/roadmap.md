# Glyphrift Roadmap

_Completed items have been moved to `docs/changelog.md`._

## Open Bugs

- [ ] **BUG-032** (P2): Interrupt/Guard techniques poorly communicated — see `docs/bugs.md`

## Gameplay

- [ ] **Sound & music** — zero audio currently. Even placeholder SFX (UI clicks, hit sounds, capture jingle, combat music) would massively improve feel. _(Punted — requires sourcing/licensing audio assets, not a code task.)_
- [ ] **Accessibility** — no colorblind mode, font size options, or input remapping

## Content Expansion

### Type system
- [ ] **Plan a deeper type chart** — reference games with strong type systems (Pokémon, Fire Emblem, Temtem) for depth/breadth. Current 3-type triangle (Electric > Water > Ground > Electric) is simple but shallow.
  - Type effectiveness should lean on intuition — avoid unintuitive matchups
  - Every type should have at least one clear strength and one clear weakness
  - Cross-type fusions should create interesting defensive/offensive niches
- [ ] **Rarity system** — define which glyphs appear in which dungeons and how often. Common T1s everywhere, rare T1s in specific rifts, T2+ only in later rifts or as echo encounters.

### More content (uses existing systems, no new code)
- [ ] **More species** — 18 feels tight for a fusion game; 5-10 more (especially T1-T2) would dramatically increase team variety. Define new mastery objectives per species.
- [ ] **More techniques** — 39 techniques across 18 species; some share too many moves, reducing identity
- [ ] **More fusion pairs** — 33 pairs feels thin; cross-affinity mutations, secret fusions, branching paths
- [ ] **More rifts** — 9 templates with limited variation; more distinct layouts, themes, or room compositions

## Art & Visual Pass

_Glyph portraits (18 species) + silhouettes are done. Everything else is placeholder._

- [ ] **NPC portraits** (Kael/Lira/Maro) — 80x80 in dialogue modal, 48x48 on bastion hub cards
- [ ] **Status effect icons** — 22x22 colored letter badges; functional but not visually distinct
- [ ] **Room type icons** — unicode symbols on 64x56 tiles; readable but generic
- [ ] **Crawler ability icons** — text-only buttons ("Scan 🔋5", "Reinforce 🔋8")
- [ ] **Technique range icons** — emoji (melee, ranged, aoe, piercing)
- [ ] **Bastion nav buttons** — plain text
- [ ] **Title screen** — procedural text ("GLYPHRIFT" in gold)
- [ ] **Background art** — solid-color backgrounds everywhere; no environment art

## Future / Longshot

- [ ] **AI-powered arbitrary fusion** — generative AI for any-species-to-any-species fusion (name, stats, art, techniques on the fly)
- [ ] **Procedural roguelike dungeons** — Slay the Spire-style separate mode with ascension levels
