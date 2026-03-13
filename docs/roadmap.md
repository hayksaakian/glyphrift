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
- [ ] **More species** — 18 current species across 3 affinities; type system v2 expands to 8 types + dual typing, targeting 100 species total. See `docs/type-system.md` for tier breakdown.
- [ ] **More techniques** — 39 techniques across 18 species; type system v2 targets ~80-100 techniques (10+ per type)
- [ ] **More fusion pairs** — 33 pairs feels thin; cross-affinity mutations, secret fusions, branching paths
- [ ] **More rifts** — 9 templates with limited variation; more distinct layouts, themes, or room compositions

## Animation

_Art direction in `docs/art-direction.md`. Per-species animation briefs in `data/glyph_animations.json`._

### Glyph sprite sheet animations
_Currently all glyphs are static portraits (single PNG). Animating them would bring the game to life._

- [x] **Define animation states needed** — 4 drawn states (Idle, Attack, Hurt, KO) + tween-only for Guard, Status, Capture, Victory/Defeat. See `docs/art-direction.md` → Glyph Animations.
- [x] **Per-species animation briefs** — all 18 species have idle/attack/hurt/ko descriptions in `data/glyph_animations.json`, sourced from creature design and signature techniques.
- [ ] **Sprite sheet generation pipeline** — extend existing Gemini-based pipeline to produce animated sprite sheets from static portraits:
  1. Standard sheet format: 128x128 frames, 4 rows x 4 cols = 512x512 per species (see `sprite-asset-spec.md` §5)
  2. Generation script: reads `data/glyph_animations.json` for per-species briefs + existing portrait as style reference, prompts AI for each animation state, assembles into sprite sheet PNG
  3. Processing: remove magenta backgrounds, standardize to 128x128 frames, validate frame count per row
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
_Crawler Bay is currently all text/stats. A visual crawler that changes appearance with chassis and equipment would make upgrades feel tangible. Full design in `docs/art-direction.md` → Crawler Visual Design._

- [x] **Crawler visual design** — 4 chassis variants fully designed: Standard (grey, balanced), Ironclad (blue-steel, heavy armor), Scout (green, radar dish), Hauler (amber, cargo racks). 512x512 source, 3/4 view, same flat art style. See `docs/art-direction.md` → Crawler Visual Design for full briefs and generation prompts.
- [ ] **Generate crawler art** — produce 4 chassis PNGs via AI generation pipeline using the design briefs
- [ ] **Equipment visualization** — equipment icons displayed in UI slots adjacent to crawler sprite (not drawn onto the sprite). Chassis alone is shown on dungeon map (equipment invisible at 28-32px).
- [ ] **Equip/unequip animation** — visual feedback in Crawler Bay when swapping equipment: old piece detaches, new piece attaches
- [ ] **Shared `CrawlerVisual` component** — a reusable node that renders the crawler chassis sprite. Used by both `CrawlerBay` (large, ~128px) and `CrawlerToken` on the dungeon map (small, ~28-32px). Swapping chassis updates both contexts automatically.

## Art & Visual Pass

_Glyph portraits (18 species) + silhouettes are done. Everything else is placeholder. All art direction in `docs/art-direction.md`._

- [ ] **NPC portraits** (Kael/Lira/Maro) — 80x80 in dialogue modal, 48x48 on bastion hub cards
- [ ] **Status effect icons** — 22x22 colored letter badges; functional but not visually distinct
- [ ] **Room type icons** — unicode symbols on 64x56 tiles; readable but generic
- [ ] **Crawler ability icons** — text-only buttons ("Scan 🔋5", "Reinforce 🔋8")
- [ ] **Technique range icons** — emoji (melee, ranged, aoe, piercing)
- [ ] **Bastion nav buttons** — plain text
- [ ] **Title screen** — dark void + vertical rift portal + crawler silhouette + gold fractured title text + affinity accent framing
- [ ] **Battle backgrounds** — 4 variants (1 per rift tier): minor (navy/teal), standard (indigo/purple), major (crimson/red), apex (void/prismatic). Crystal formations + ground plane layers.
- [ ] **Dungeon map background** — dark charcoal void with subtle hex grid and vignette. 1 background.
- [ ] **Bastion backgrounds** — 6 variants (hub, barracks, fusion chamber, rift gate, codex, crawler bay). Warm industrial/workshop aesthetic.
- [ ] **Fusion discovery animation** — tween-based sequence: parents converge → energy merge → flash → silhouette reveal → color fill → name reveal

## Future / Longshot

- [ ] **AI-powered arbitrary fusion** — generative AI for any-species-to-any-species fusion (name, stats, art, techniques on the fly)
- [ ] **Procedural roguelike dungeons** — Slay the Spire-style separate mode with ascension levels
