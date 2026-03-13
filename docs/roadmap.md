# Glyphrift Roadmap

_Completed items have been moved to `docs/changelog.md`._

## Open Bugs

- [ ] **BUG-032** (P2): Interrupt/Guard techniques poorly communicated — see `docs/bugs.md`

## Gameplay

- [ ] **Sound & music** — zero audio currently. Even placeholder SFX (UI clicks, hit sounds, capture jingle, combat music) would massively improve feel. _(Punted — requires sourcing/licensing audio assets, not a code task.)_
- [ ] **Accessibility** — no colorblind mode, font size options, or input remapping

## Content Expansion

### Type system
- [x] **Plan a deeper type chart** — DESIGNED. See `docs/type-system.md`.
  - 8 combat types + Neutral: Fire, Ice, Electric, Water, Ground, Void, Bio, Light
  - Decoupled offense/defense charts (20 matchups, all pass the "one sentence" intuition test)
  - Single + dual-type Glyphs, single-type techniques
  - Void <> Light mutual SE with no resistance (pure "who strikes first")
- [ ] **Implement type system v2** — update affinity.gd, damage_calculator.gd, data files, species roster
- [ ] **Rarity system** — define which glyphs appear in which dungeons and how often. Common T1s everywhere, rare T1s in specific rifts, T2+ only in later rifts or as echo encounters.

### More content (uses existing systems, no new code)
- [ ] **More species** — 18 current species across 3 affinities; type system v2 expands to 8 types, targeting ~40 species (5 per type). Define new mastery objectives per species.
- [ ] **More techniques** — 39 techniques across 18 species; type system v2 targets ~80 techniques (10 per type)
- [ ] **More fusion pairs** — 33 pairs feels thin; cross-affinity mutations, secret fusions, branching paths
- [ ] **More rifts** — 9 templates with limited variation; more distinct layouts, themes, or room compositions

## Animation

### Glyph sprite sheet animations
_Currently all glyphs are static portraits (single PNG). Animating them would bring the game to life._

- [ ] **Define animation states needed** — inventory what contexts display glyphs and what animations each needs:
  - Battle: idle (breathing/bobbing), attack (lunge/flash), hurt (flinch/shake), KO (collapse/fade), guard (brace pose), status applied (flash), technique-specific?
  - Dungeon: capture popup (wiggle/glow on success), echo encounter (phase-in shimmer)
  - Bastion: cards (subtle idle), detail popup (idle), fusion (dissolve parents → form child)
  - Turn queue: small portraits, probably stay static
- [ ] **Sprite sheet generation pipeline** — extend existing Gemini-based pipeline to produce animated sprite sheets from static portraits:
  1. Define a standard sheet format (e.g., 128x128 frames, 4-8 frames per animation, horizontal strip or grid)
  2. Generation script: takes species ID + existing portrait as reference, prompts Gemini for each animation state, assembles into sprite sheet PNG
  3. Processing: standardize frame sizes, timing metadata (JSON or .tres sidecar), validate frame count
  4. Fallback: if sprite sheet is missing, current static portrait still works — animation is progressive enhancement
- [ ] **Godot sprite sheet consumer** — code to load and play sprite sheet animations:
  1. `GlyphArt` extension or new `GlyphAnimator` class: loads sprite sheets, creates `SpriteFrames` resources, manages animation state
  2. Replace `TextureRect` with `AnimatedSprite2D` (or `AnimatedTextureRect` wrapper) in display contexts
  3. Animation triggers: `play("attack")`, `play("hurt")`, etc. — called from BattleScene signal handlers, replacing current tween-based flash/shake
  4. `instant_mode` support: skip to final frame in headless tests
- [ ] **Integrate into battle flow** — wire AnimationQueue events to sprite animations instead of (or alongside) current tween effects (damage flash, KO grey-out, phase overlay)

### Dungeon map animations
_Crawler token is currently a diamond-shaped `Polygon2D` that tweens between rooms. Replace with the actual crawler visual (same as bastion — chassis + equipment appearance) and expand map animations._

- [ ] **Crawler on the map** — replace the diamond `CrawlerToken` with the crawler sprite (matching current chassis + equipment). This is the same visual from Crawler Bay, scaled for the map. When the player changes chassis between rifts, the map crawler changes too. Depends on "Crawler visual in bastion" being done first.
- [ ] **Room enter/exit effects** — visual feedback when entering rooms: screen transition, room "opening" animation, threat indicator pulse for enemy rooms
- [ ] **Scan ripple enhancement** — current scan plays a cyan ring; could animate room nodes revealing (flip/fade from `???` to type icon)
- [ ] **Floor transition** — animate descending to next floor (current: instant rebuild). Fade out → rebuild → fade in, or vertical scroll effect
- [ ] **Hazard damage** — enhance current screen shake + red flash with crawler-specific damage animation
- [ ] **Fog of war** — animate fog rolling back as rooms become visible, rather than instant pop-in

### Crawler visual in bastion
_Crawler Bay is currently all text/stats. A visual crawler that changes appearance with chassis and equipment would make upgrades feel tangible._

- [ ] **Base crawler art** — design the default crawler appearance (top-down or 3/4 view, ~128x128). This is the single source of truth for how the crawler looks — used in both the Crawler Bay center panel and on the dungeon map (scaled down). One visual, two contexts.
- [ ] **Chassis variants** — each chassis (Standard, Ironclad, Scout, Hauler) should look visibly different:
  - Standard: basic frame
  - Ironclad: heavier plating, bulkier
  - Scout: sleek, antenna/sensor dish
  - Hauler: wider frame, cargo racks
  - Could be separate full sprites or a paper-doll overlay system (base + chassis layer)
- [ ] **Equipment visualization** — Computer and Accessory slots shown as attachments on the crawler:
  - Paper-doll approach: equipment sprites overlaid on chassis sprite at defined anchor points
  - Or: pre-rendered combinations if the count is manageable (4 chassis × 8 equipment = 32 combos — probably too many for pre-rendered)
  - Simpler option: small equipment icons displayed near the crawler art, not physically attached
- [ ] **Equip/unequip animation** — visual feedback in Crawler Bay when swapping equipment: old piece detaches, new piece attaches
- [ ] **Shared `CrawlerVisual` component** — a reusable node that renders the crawler (base + chassis layer + equipment overlays). Used by both `CrawlerBay` (large, ~128px) and `CrawlerToken` on the dungeon map (small, ~28-32px). Swapping chassis or equipment updates both contexts automatically.

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
