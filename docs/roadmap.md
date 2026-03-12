# Glyphrift Roadmap

## Tier 1 — Fix What's Broken

These items address systems that exist but don't fully work. Highest priority.

- [x] **Boss phase 2 variety** — bosses are the climax of each rift but feel samey. Design principle: bosses should showcase their species' full potential, not apply arbitrary stat modifiers. _(All 7 non-tutorial bosses now have distinct 2-3 member squads with themed compositions: Ironbark=double tank wall, Vortail=debuff duo, Thunderclaw=melee aggro, Stormfang=stun-lock trio, Terradon=sustain wall+healer, Riftmaw=void debuff trio, Nullweaver=full water squad. Phase 2 stat bonuses vary per boss identity: DEF for tanks, SPD for fast attackers, ATK for nukers, DEF+RES for walls. Engine extended to support def/res phase 2 bonuses.)_

- [x] **Turn queue clarity** — show upcoming turns clearly enough that interrupt/speed decisions feel strategic, not guesswork. UI-only change on the existing turn_queue system. _(SPD badges, stun skip indicator, active turn arrow, round separators)_

## Tier 2 — Make It Feel Like a Game

These make the biggest difference in player experience.

- [ ] **Sound & music** — zero audio currently. Even placeholder SFX (UI clicks, hit sounds, capture jingle, combat music) would massively improve feel. Godot's audio system is straightforward. _(Punted — requires sourcing/licensing audio assets, not a code task.)_

- [x] **Puzzle variety** — 3 puzzle types rotate fast. Add 2-3 more (riddle/trivia about species lore, tile-sliding, affinity-matching minigame) to keep dungeon rooms fresh. _(4 puzzle types: sequence, conduit, echo, quiz)_

- [x] **Echo encounters as mini-stories** — echoes are compelling 1v1 duels; give them flavor text, unique movesets, or "memory fragment" lore drops that build a side narrative. _(All 15 species have unique encounter flavor text and memory fragment lore. Encounter text replaces generic "A ghostly echo..." with species-specific atmospheric descriptions. Memory fragments appear on the capture result screen as blue lore text. 100% captures now show result screen instead of auto-dismissing.)_

- [x] **Crawler upgrades feel good** — lean into chassis identity; more meaningful chassis-specific abilities or passives beyond stat bonuses. _(Milestones, chassis selection, upgrade notifications, status panel — all done)_

- [ ] **Crawler equipment slots** — 3 equipment slots on each crawler, equipped before entering a rift. Gives pre-rift loadout decisions without adding combat complexity.

  **Crawler Bay UI layout:** `[Chassis] [Computer] [Accessory] [Crawler Stats]`

  - **Chassis** — (already implemented) defines base identity, stat profile, passive bonus
  - **Computer** — the crawler's onboard intelligence (scanning, energy management, filtering). Examples:
    - Scan Amplifier — Scan range +1
    - Energy Recycler — Regenerate 25% of energy per floor
    - Affinity Filter — Bias wild encounters toward a chosen affinity
    - Capacitor Cell — +40 Max Energy
  - **Accessory** — bolted-on external hardware (durability, cargo, utility). Examples:
    - Hull Plating — +25 Hull HP
    - Cargo Rack — +1 Bench slot
    - Repair Drone — Auto-heal 20% of Hull HP per floor transition
    - Trophy Mount — +20% capture chance
  - Parts found as rare cache drops or milestone rewards. Chassis identity could come from more or less slots of a given type.

- [x] **Status effect clarity** — 6 status types with single-letter icons; tooltip on hover works but in-battle readability could improve. _(Status badges now show letter+turns remaining (e.g. "B3", "S1"), rich tooltips with effect description and duration, red/cyan border for debuff/buff distinction)_

## Tier 3 — Content Expansion

Broken into phases. Each phase builds on the last.

### Short term: Neutral affinity
- [ ] Add **Neutral type** with 2 species lines (1 T1 + 1 T2, or 2 T1 → 1 T2 fusion). Neutral has no SE advantage/disadvantage — a safe generalist pick that rounds out team composition. Fusions with a neutral + non-neutral will always lean on the non-neutral's type for calculating a fusion outcome. 
- [ ] Define Neutral's role: jack-of-all-trades stats? Unique utility techniques? Resistant to nothing, weak to nothing?
- [ ] Portraits, techniques, fusion pairs for the new species.

### Short term: Streamline sprite generation pipeline
- [ ] **Automated sprite generation via Gemini API** — the first 15 glyph portraits were hand-generated using Google Gemini's image model (Imagen 3 / Nano Banana 2). Goal: build a script that Claude Code can run to generate new species sprites end-to-end:
  1. **Prompt template + examples** — prompt guidelines and all 15 original prompts stored in `docs/glyph-sprite-prompts.md`.
  2. **Generation script** (`scripts/generate_sprites.py` or `.sh`) — takes a species ID + description, calls Gemini API to generate the raw image, saves to `raw/`. Should support batch generation for multiple species.
  3. **Processing pipeline** — pipe raw output through existing `scripts/process_sprites.sh` (background removal, trim, resize, silhouette generation).
  4. **2nd-pass transparency fix** — enhance `process_sprites.sh` with connected-component analysis to remove interior white pockets (see Art & Visual Pass section).
  5. **End-to-end flow:** `generate_sprites.py sparkfin "A shimmering electric fish..."` → raw PNG → `process_sprites.sh` → portrait + silhouette in `assets/sprites/glyphs/` → ready for Godot import.
- [ ] **Gemini API key management** — store key in env var or `.env` file (gitignored). Script should fail gracefully with clear message if key is missing.
- [ ] **Quality validation** — after generation, optionally display/open the image for human review before committing. Not every generation will be usable; may need retry logic or multiple candidates.

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
- [x] **More items** — added 4 new items (Revival Core, Rift Beacon, Affinity Prism, Hull Shield) with full effect handling: revive KO'd glyphs, reveal entire floor, +50% ATK boost for next battle, block next hazard damage

### Longer term: Narrative & lore
- [x] **NPC dialogue expansion** — 3 NPCs with ~3 lines each feels sparse. _(Expanded to 5 phases with 2 lines each = 30 total lines (was 9). All 3 NPCs now have dialogue for phases 1-5. Randomly picks from available lines per phase for variety. Phase cap removed — phases 4-5 have unique content about Apex preparation and post-completion.)_
- [x] **NPC side quests** — GDD mentions Lira's "bring me a Water T2" quest type; not implemented _(3 quests: Lira=discover 8 species→codex reveal, Kael=clear 3 rifts→+3 capacity, Maro=find 3 hidden rooms→+15 hull HP. Quest status in NPC panel with progress bar. Saved/loaded.)_
- [x] **Lore objects** — GDD 7.8 mentions murals, data fragments, broken pods in rift rooms; no environmental storytelling currently _(Empty rooms now show lore fragments 50% of the time — murals, data terminals, researcher notes, warning beacons. 3-5 unique entries per rift tied to boss theme. Generic fallback pool for unlisted rifts.)_
- [x] **Echo flavor text** — give echo encounters memory fragments or species lore snippets _(Done in Tier 2 echo encounters as mini-stories)_
- [x] **Hidden room rewards** — hidden rooms exist but need more interesting/unique content _(Hidden rooms now give item + 15 hull HP restore bonus, differentiated from regular caches)_

## Tier 4 — Polish & QoL

Important but not urgent. Do these as the game stabilizes.

- [x] **Revisit mid-rift battle loss penalty** — _(Reworked: no more free 30% revives. Battle loss triggers forced repair picker — player must spend energy to heal KO'd glyphs. If insufficient energy, emergency warp extracts from rift. Makes losses meaningful without being run-ending.)_

- [x] **Battle pacing** — animation timing may need tuning; currently tween-based but no player feedback on snappy vs sluggish _(Settings screen battle speed: Normal/Fast(2x)/Instant. Scales AnimationQueue inter-event delays. Individual tweens kept at normal speed for readability.)_
- [x] **Capture screen flow** — recruit→capture connection isn't obvious to players. _(Added floating "Recruited! +15%" callout above enemy panel during combat when recruit succeeds. Shows exact capture bonus per recruit use. Breakdown on capture screen already shows Recruit +X%.)_
- [x] **Tutorial completeness** — GDD 12.1 specifies guided overlays; verify all tutorial elements present _(tutorial hints system implemented)_
- [x] **Formation UX** — strategic impact of front/back row isn't communicated well to new players _(skip mandatory formation, Fight+Formation buttons on combat popup)_
- [x] **Rift info button in dungeon** — add an (i) button next to the rift name in the dungeon HUD that opens a summary popup with the same info shown on the rift selection screen (boss name/species, rift tier, floor count, hazard type, etc.). Players forget what they're up against mid-rift. _(implemented: (i) button in dungeon header, popup shows tier/floors/hazard/boss/pool size)_
- [x] **Text overflow** — various popups and labels may clip on different resolutions _(Added clip_text + text_overrun_behavior to: RiftGate rift/boss name labels, RoomPopup enemy preview names, CodexBrowser rift atlas names)_
- [x] **Difficulty curve validation** — play through full 7-rift arc and verify pacing, resource pressure, enemy scaling _(balance pass done in session 10)_
- [x] **Balance pass** — technique power, status durations, capture rates, energy economy _(verified in session 10)_
- [x] **Rift re-entry variation** — GDD says boss reshuffles content; verify it feels different on repeat _(Verified: pool-based rooms use weighted random resolution on each generate(), enemy species are randomly picked with uniqueness bias, puzzle types cycle round-robin. Each re-entry produces different room types and encounters.)_
- [x] **Save slot management** — currently single save; multiple slots or "are you sure?" on new game _(3 save slots + autosave implemented)_
- [x] **Settings screen** — no options menu (text speed, animation speed, controls) _(Battle speed setting: Normal/Fast/Instant via pause menu Settings button. GameSettings persists to user://settings.json. Scales AnimationQueue delays.)_
- [ ] **Accessibility** — no colorblind mode, font size options, or input remapping
- [ ] **T4/Apex glyph masteries** — T4 glyphs (Nullweaver, Voltarion, Lithosurge) currently have no reason to complete mastery since they can't fuse further. But the +2 all-stats mastery bonus is still valuable for endgame teams. Ensure T4 species have interesting mastery objectives worth pursuing as a post-apex goal.
- [x] **Endgame / post-apex** — what happens after clearing all 7 rifts? _(Shows "ALL RIFTS CONQUERED!" message with codex discovery percentage when last rift is cleared. Player returns to bastion and can re-enter rifts for captures/completion.)_
- [x] **Crawler upgrade: Rift Transmitter** — when bench is full during capture, allow sending caught glyph directly to bastion reserves. Crawler upgrade (not default) — keeps early-game tension, gives late-game QoL. _(Milestone: "Seal the Apex Rift" → unlocks Rift Transmitter. "Send to Reserves" button on bench-full swap screen. Glyph goes directly to roster reserves, not rift pool. Saved/loaded via has_rift_transmitter flag.)_

## Art & Visual Pass

_What exists: 15 glyph portraits + 15 silhouettes in `assets/sprites/glyphs/`. GlyphArt system loads PNGs and falls back to colored-square-with-letter placeholder. Everything else is procedural._

**Glyph art (have portraits, used everywhere):**
- [x] Portraits load via GlyphArt in: battle panels, cards, formation, squad overlay, codex, capture popup, detail popup, echo/quiz puzzles
- [x] Silhouettes load in: codex (undiscovered), quiz puzzle
- [x] Current fallback if PNG missing: affinity-colored square + species initial letter with black outline

**Art cleanup needed:**
- [x] **Transparency 2nd pass** — _(AI-informed cleanup via `scripts/cleanup_sprites.py`: ImageMagick finds interior white/magenta CCs, Gemini vision classifies each as pocket vs feature, only pockets get flood-filled. Also updated sprite prompts to use magenta backgrounds. All 18 species verified clean. See BUG-026.)_

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
