# Glyphrift Roadmap

## Backlog

(items below are unordered — prioritize before starting work)

### Double Down (the fun parts)

- **Puzzle variety** — 3 puzzle types rotate quickly; add 2-3 more (riddle/trivia about species lore, tile-sliding, affinity-matching minigame)
- **Echo encounters as mini-stories** — echoes are compelling 1v1 duels; give them flavor text, unique movesets, or "memory fragment" lore drops that build a side narrative
- **Mastery objective depth** — stubbed objectives (brace_then_survive, burn_then_kill) should work and feel satisfying; add species-specific challenges that teach you the glyph's playstyle
- **Crawler upgrades feel good** — lean into chassis identity; more meaningful chassis-specific abilities or passives beyond stat bonuses
- **Boss phase 2 variety** — each boss should feel mechanically distinct in phase 2 (new moves, terrain effects, summon adds, not just stat bumps)

### Art & Visual Pass

_What exists: 15 glyph portraits + 15 silhouettes in `assets/sprites/glyphs/`. GlyphArt system loads PNGs and falls back to colored-square-with-letter placeholder. Everything else is procedural._

**Glyph art (have portraits, used everywhere):**
- Portraits load via GlyphArt in: battle panels, cards, formation, squad overlay, codex, capture popup, detail popup, echo/quiz puzzles
- Silhouettes load in: codex (undiscovered), quiz puzzle
- Current fallback if PNG missing: affinity-colored square + species initial letter with black outline

**No assets exist — placeholder only:**
- **NPC portraits** (Kael/Lira/Maro) — 80x80 in dialogue modal, 48x48 on bastion hub cards; currently colored squares with K/L/M letters; no loading system for NPC art
- **Status effect icons** — 22x22 colored letter badges (B=burn, S=stun, L=slow, W=weaken, C=corrode, H=shield); functional but not visually distinct at a glance
- **Room type icons** — unicode symbols on 64x56 tiles (S=start, !=enemy, ?=puzzle, etc.); readable but generic
- **Crawler ability icons** — text-only buttons ("Scan 🔋5", "Reinforce 🔋8"); no sprite icons
- **Item icons** — items displayed as text lists only; no visual representation
- **Technique range icons** — emoji (👊 melee, 🏹 ranged, 💥 aoe, 🎯 piercing)
- **Bastion nav buttons** — plain text ("Rift Gate", "Barracks", "Fusion Chamber", etc.)
- **Title screen** — procedural text ("GLYPHRIFT" in gold, subtitle below)
- **Background art** — all screens use solid-color backgrounds; no environment art, no dungeon tileset, no bastion interior

**Stretch / low priority:**
- UI chrome (panels, borders) — StyleBoxFlat everywhere, functional
- HP/energy bars — ProgressBar with color thresholds, fine as-is
- Affinity symbols — emoji (⚡💧🪨) used inline, consistent

### Polish & Fix

- **Sound & music** — zero audio currently; ambient dungeon tracks, combat music, UI clicks, capture jingle, fusion fanfare
- **Battle pacing** — animation timing may need tuning for feel; currently all tween-based but no player feedback on whether it feels snappy or sluggish
- **Status effect clarity** — 6 status types with single-letter icons; tooltip on hover works but in-battle readability could improve (color-coded borders, persistent effect descriptions)
- **Capture screen flow** — recruit bonus display verified working but the recruit→capture connection isn't obvious to players; add "Recruited!" callout in breakdown or tutorial hint
- **Tutorial completeness** — GDD 12.1 specifies guided overlays; verify all tutorial elements are present and well-timed
- **Formation UX** — formation matters for front/back row but the strategic impact isn't communicated well to new players
- **Text overflow** — various popups and labels may clip on different resolutions; ScrollContainer usage is inconsistent

### Content Production

_Data/writing/design work that uses existing systems — no new code required._

- **More species** — 15 is the GDD target but feels tight for a fusion game; even 5-10 more (T1-T2 especially) would dramatically increase team variety
- **More techniques** — 39 techniques across 15 species; some species share too many moves, reducing identity
- **More fusion pairs** — 33 pairs feels thin once you've seen them; cross-affinity mutations, secret fusions, branching paths would reward experimentation
- **More rifts** — 7 templates with limited variation; more distinct layouts, themes, or room compositions per rift would add replayability
- **More items** — only 5 consumables; new pickups, passive buffs, or rift-specific drops
- **NPC dialogue expansion** — 3 NPCs with ~3 lines each feels sparse; more dialogue per phase, reactions to player progress, fusion hints
- **Lore objects** — GDD 7.8 mentions murals, data fragments, broken pods in rift rooms; no environmental storytelling currently
- **Hidden room rewards** — hidden rooms exist but need more interesting/unique content
- **Boss phase 2 movesets** — write distinct phase 2 technique sets and stat profiles for each boss
- **Echo flavor text** — give echo encounters memory fragments or species lore snippets

### Systems & Features

- **Crawler upgrade: Rift Transmitter** — when bench is full during a capture, allow sending the caught glyph directly to bastion reserves instead of forcing a bench swap or abandon. This would be a crawler upgrade (milestone reward or chassis perk), not available by default — keeps early-game resource tension intact while giving late-game players a quality-of-life option.

- **NPC side quests** — GDD mentions Lira's "bring me a Water T2" quest type; not implemented yet
- **Difficulty curve validation** — play through full 7-rift arc (4-6 hrs) and verify pacing, resource pressure, enemy scaling
- **Balance pass** — technique power levels, status effect durations, capture rates, crawler energy economy
- **Rift re-entry variation** — GDD says boss reshuffles content; verify templates feel different on repeat runs
- **Save slot management** — currently single save; multiple slots or at least a "are you sure?" on new game
- **Settings screen** — no options menu (text speed, animation speed, controls)
- **Accessibility** — no colorblind mode, font size options, or input remapping
- **Turn queue clarity** — show upcoming turns clearly enough that interrupt decisions feel strategic, not guesswork
- **Endgame / post-apex** — what happens after clearing all 7 rifts? Credits? Codex completion reward? Harder variants?

### Future / Longshot

- **AI-powered arbitrary fusion** — use generative AI to enable any-species-to-any-species fusion, creating novel hybrid glyphs on the fly (name, stats, art, techniques); would make the fusion system feel nearly endless
- **Procedural roguelike dungeons** — a separate mode from story rifts, Slay the Spire-style; each run is a complete dungeon with a final boss, but ascension levels add stacking difficulty modifiers (e.g. A1: enemies +10% HP, A5: no caches, A10: burn-immune bosses); gives each run a clear ending while still providing infinite replayability
