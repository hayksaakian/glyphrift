# Glyphrift Roadmap

## Tier 1 — Fix What's Broken

These items address systems that exist but don't fully work. Highest priority.

- [x] **Boss phase 2 variety** — bosses are the climax of each rift but feel samey. Design principle: bosses should showcase their species' full potential, not apply arbitrary stat modifiers. _(All 7 non-tutorial bosses now have distinct 2-3 member squads with themed compositions: Ironbark=double tank wall, Vortail=debuff duo, Thunderclaw=melee aggro, Stormfang=stun-lock trio, Terradon=sustain wall+healer, Riftmaw=void debuff trio, Nullweaver=full water squad. Phase 2 stat bonuses vary per boss identity: DEF for tanks, SPD for fast attackers, ATK for nukers, DEF+RES for walls. Engine extended to support def/res phase 2 bonuses.)_

- [x] **Turn queue clarity** — show upcoming turns clearly enough that interrupt/speed decisions feel strategic, not guesswork. UI-only change on the existing turn_queue system. _(SPD badges, stun skip indicator, active turn arrow, round separators)_

## Tier 2 — Make It Feel Like a Game

These make the biggest difference in player experience.

- [ ] **Sound & music** — zero audio currently. Even placeholder SFX (UI clicks, hit sounds, capture jingle, combat music) would massively improve feel. Godot's audio system is straightforward.

- [x] **Puzzle variety** — 3 puzzle types rotate fast. Add 2-3 more (riddle/trivia about species lore, tile-sliding, affinity-matching minigame) to keep dungeon rooms fresh. _(4 puzzle types: sequence, conduit, echo, quiz)_

- [ ] **Echo encounters as mini-stories** — echoes are compelling 1v1 duels; give them flavor text, unique movesets, or "memory fragment" lore drops that build a side narrative.

- [x] **Crawler upgrades feel good** — lean into chassis identity; more meaningful chassis-specific abilities or passives beyond stat bonuses. _(Milestones, chassis selection, upgrade notifications, status panel — all done)_ Future direction: **3 equipment slots** on each crawler, equipped before entering a rift:

  **Crawler Bay UI layout:** `[Chassis] [Computer] [Accessory] [Crawler Stats]`

  - **Chassis** — (already implemented) defines base identity, stat profile, passive bonus
  - **Computer** — the crawler's onboard intelligence (scanning, energy management, filtering). Examples:
    - Scan Amplifier — Scan reveals full room contents (not just type)
    - Energy Recycler — Refund 2 Energy when an ability finds nothing useful
    - Affinity Filter — Bias wild encounters toward a chosen affinity
    - Capacitor Cell — +10 Energy
  - **Accessory** — bolted-on external hardware (durability, cargo, utility). Examples:
    - Hull Plating — +15 Hull HP
    - Cargo Rack — +1 Bench slot
    - Repair Drone — Auto-heal 5 Hull HP per floor transition
    - Trophy Mount — +10% capture chance
  - Parts found as rare cache drops or milestone rewards. Chassis identity could come from bonuses to certain part types (e.g. Ironclad: +50% from Accessories, Scout: +50% from Computers) or unique part unlocks per chassis. This gives pre-rift loadout decisions without adding combat complexity.

- [ ] **Status effect clarity** — 6 status types with single-letter icons; tooltip on hover works but in-battle readability could improve (color-coded borders, persistent effect descriptions).

## Tier 3 — Content Expansion

Broken into phases. Each phase builds on the last.

### Short term: Neutral affinity
- [ ] Add **Neutral type** with 2 species lines (1 T1 + 1 T2, or 2 T1 → 1 T2 fusion). Neutral has no SE advantage/disadvantage — a safe generalist pick that rounds out team composition.
- [ ] Define Neutral's role: jack-of-all-trades stats? Unique utility techniques? Resistant to nothing, weak to nothing?
- [ ] Portraits, techniques, fusion pairs for the new species.

### Medium term: Type system redesign
- [ ] **Plan a deeper type chart** — reference games with strong type systems (Pokémon, Fire Emblem, Temtem) for depth/breadth. Current 3-type triangle (Electric > Water > Ground > Electric) is simple but shallow.
- **Design principles**:
  - Type effectiveness should lean on intuition — avoid requiring players to memorize unintuitive matchups
  - Every type should have at least one clear strength and one clear weakness
  - Cross-type fusions should create interesting defensive/offensive niches
- [ ] **Rarity system** — define which glyphs appear in which dungeons and how often. Enforce intentional design: common T1s everywhere, rare T1s in specific rifts, T2+ only in later rifts or as echo encounters. Prevents "saw everything in rift 2" feeling.

### Medium term: More content (uses existing systems, no new code)
- [ ] **More species** — 15 feels tight for a fusion game; 5-10 more (especially T1-T2) would dramatically increase team variety. When adding species, define new mastery objectives that teach each glyph's playstyle (2 fixed + 1 random per species)
- [ ] **More techniques** — 39 techniques across 15 species; some species share too many moves, reducing identity
- [ ] **More fusion pairs** — 33 pairs feels thin; cross-affinity mutations, secret fusions, branching paths would reward experimentation
- [ ] **More rifts** — 7 templates with limited variation; more distinct layouts, themes, or room compositions per rift
- [ ] **More items** — only 5 consumables; new pickups, passive buffs, or rift-specific drops

### Longer term: Narrative & lore
- [ ] **NPC dialogue expansion** — 3 NPCs with ~3 lines each feels sparse; more dialogue per phase, reactions to player progress, fusion hints
- [ ] **NPC side quests** — GDD mentions Lira's "bring me a Water T2" quest type; not implemented
- [ ] **Lore objects** — GDD 7.8 mentions murals, data fragments, broken pods in rift rooms; no environmental storytelling currently
- [ ] **Echo flavor text** — give echo encounters memory fragments or species lore snippets
- [ ] **Hidden room rewards** — hidden rooms exist but need more interesting/unique content

## Tier 4 — Polish & QoL

Important but not urgent. Do these as the game stabilizes.

- [ ] **Battle pacing** — animation timing may need tuning; currently tween-based but no player feedback on snappy vs sluggish
- [ ] **Capture screen flow** — recruit→capture connection isn't obvious to players; add "Recruited!" callout
- [x] **Tutorial completeness** — GDD 12.1 specifies guided overlays; verify all tutorial elements present _(tutorial hints system implemented)_
- [x] **Formation UX** — strategic impact of front/back row isn't communicated well to new players _(skip mandatory formation, Fight+Formation buttons on combat popup)_
- [x] **Rift info button in dungeon** — add an (i) button next to the rift name in the dungeon HUD that opens a summary popup with the same info shown on the rift selection screen (boss name/species, rift tier, floor count, hazard type, etc.). Players forget what they're up against mid-rift. _(implemented: (i) button in dungeon header, popup shows tier/floors/hazard/boss/pool size)_
- [ ] **Text overflow** — various popups and labels may clip on different resolutions
- [x] **Difficulty curve validation** — play through full 7-rift arc and verify pacing, resource pressure, enemy scaling _(balance pass done in session 10)_
- [x] **Balance pass** — technique power, status durations, capture rates, energy economy _(verified in session 10)_
- [ ] **Rift re-entry variation** — GDD says boss reshuffles content; verify it feels different on repeat
- [x] **Save slot management** — currently single save; multiple slots or "are you sure?" on new game _(3 save slots + autosave implemented)_
- [ ] **Settings screen** — no options menu (text speed, animation speed, controls)
- [ ] **Accessibility** — no colorblind mode, font size options, or input remapping
- [ ] **Endgame / post-apex** — what happens after clearing all 7 rifts? Credits? Codex completion reward?
- [ ] **Crawler upgrade: Rift Transmitter** — when bench is full during capture, allow sending caught glyph directly to bastion reserves. Crawler upgrade (not default) — keeps early-game tension, gives late-game QoL.

## Art & Visual Pass

_What exists: 15 glyph portraits + 15 silhouettes in `assets/sprites/glyphs/`. GlyphArt system loads PNGs and falls back to colored-square-with-letter placeholder. Everything else is procedural._

**Glyph art (have portraits, used everywhere):**
- [x] Portraits load via GlyphArt in: battle panels, cards, formation, squad overlay, codex, capture popup, detail popup, echo/quiz puzzles
- [x] Silhouettes load in: codex (undiscovered), quiz puzzle
- [x] Current fallback if PNG missing: affinity-colored square + species initial letter with black outline

**No assets exist — placeholder only:**
- [ ] **NPC portraits** (Kael/Lira/Maro) — 80x80 in dialogue modal, 48x48 on bastion hub cards; colored squares with K/L/M letters
- [ ] **Status effect icons** — 22x22 colored letter badges; functional but not visually distinct at a glance
- [ ] **Room type icons** — unicode symbols on 64x56 tiles; readable but generic
- [ ] **Crawler ability icons** — text-only buttons ("Scan 🔋5", "Reinforce 🔋8")
- [x] **Item icons** — colored placeholder icons with effect-type colors and first letter _(implemented in session 11)_
- [ ] **Technique range icons** — emoji (melee, ranged, aoe, piercing)
- [ ] **Bastion nav buttons** — plain text
- [ ] **Title screen** — procedural text ("GLYPHRIFT" in gold)
- [ ] **Background art** — solid-color backgrounds everywhere; no environment art

**Stretch / low priority:**
- UI chrome (panels, borders) — StyleBoxFlat everywhere, functional
- HP/energy bars — ProgressBar with color thresholds, fine as-is
- Affinity symbols — emoji used inline, consistent

## Future / Longshot

- [ ] **AI-powered arbitrary fusion** — use generative AI to enable any-species-to-any-species fusion, creating novel hybrid glyphs on the fly (name, stats, art, techniques); would make the fusion system feel nearly endless
- [ ] **Procedural roguelike dungeons** — a separate mode from story rifts, Slay the Spire-style; each run is a complete dungeon with a final boss, but ascension levels add stacking difficulty modifiers (e.g. A1: enemies +10% HP, A5: no caches, A10: burn-immune bosses); gives each run a clear ending while still providing infinite replayability
