# Changelog

Completed features, fixes, and milestones. Will be versioned once the game ships.

---

## Pre-release

### Features

- **Data layer** — 6 Resource classes, 10 JSON data files, DataLoader autoload. 18 species, 39 techniques, 33 fusion pairs, 9 rift templates, 9 bosses, 8 items.
- **Combat engine** — SPD-based turn queue, 6 status effects, AI controller, damage calculator (GDD 8.8), interrupts, boss phase 2.
- **Mastery & fusion** — MasteryTracker (18+ objective types, 2 fixed + 1 random per species), FusionEngine (stat/technique inheritance), CodexState, RosterState.
- **Dungeon system** — CrawlerState (hull/energy/items, chassis bonuses), CaptureCalculator, RiftGenerator, DungeonState (floor/room navigation, fog of war, hazard damage).
- **GameState** — Phase advancement (2@1, 3@3, 4@5, 5@6), rift availability, start_new_game/start_rift/complete_rift.
- **Battle UI** — Spatial battlefield, AnimationQueue, GlyphPanel, TechniqueButton, BattleLog, FormationSetup, TargetSelector, DamageNumbers, PhaseOverlay, ResultScreen. 19 signal handlers, auto-battle.
- **Dungeon UI** — RoomNode (4 states), FloorMap (grid + connections), CrawlerHUD (hull/energy bars, 5 ability buttons), RoomPopup, CapturePopup, SquadOverlay, click-to-navigate pathfinding.
- **Bastion UI** — GlyphCard, Barracks (squad/reserve management, GP enforcement), FusionChamber (preview, technique selection, discovery overlay), RiftGate, BastionScene hub, CodexBrowser (3 tabs), NpcPanel (3 NPCs, 5 phases).
- **Puzzles** — Sequence (memorize+repeat), Conduit (affinity cycle), Echo (1v1 duel + 100% capture), Quiz (species lore trivia).
- **Save/load** — SaveManager (JSON, 5 slots + autosave), mid-rift save/load, auto-save on rift entry/completion.
- **Mastery UX** — GlyphDetailPopup (full stats, techniques, mastery checklist), mastery stars (0-3) on panels/cards/overlay, per-glyph progress on victory screen.
- **NPC system** — 3 NPCs with 5-phase dialogue (30 lines), 3 side quests with progress tracking, "all cleared" dialogue.
- **Lore & narrative** — Echo encounter flavor text + memory fragments (all 18 species), lore objects in empty rooms (rift-themed), hidden room bonus rewards.
- **Crawler upgrades** — Milestones, chassis selection, equipment slots (Computer + Accessory, 8 pieces), Crawler Bay UI, Rift Transmitter (post-apex).
- **Items** — Revival Core, Rift Beacon, Affinity Prism, Hull Shield, Ward Charm + original items. Full effect handling, save/load.
- **Boss phase 2 variety** — 7 non-tutorial bosses with distinct squad compositions and stat bonus profiles (DEF/SPD/ATK/RES per boss identity).
- **Turn queue clarity** — SPD badges, stun skip indicator, active turn arrow, round separators.
- **Puzzle variety** — 4 puzzle types: sequence, conduit, echo, quiz.
- **Echo encounters as mini-stories** — Species-specific atmospheric text, memory fragment lore drops on capture.
- **Status effect clarity** — Letter+turns badges (B3, S1), rich tooltips, debuff/buff border colors.
- **Neutral affinity** — 3 species (Vesper T1 tank, Equinox T1 support, Solstice T2 generalist) with constellation/star-map aesthetic. Wildcard fusion rule.
- **Sprite generation pipeline** — `generate_sprites.py` (Gemini API), `process_sprites.sh` (background removal, trim, resize, silhouette), `cleanup_sprites.py` (AI pocket removal), `brainstorm_sprites.py` (concept exploration). All 18 species generated.
- **T4/Apex mastery** — T4 species have 2 fixed + 1 random mastery objectives. Pool of 7 T4-appropriate challenges. +2 all-stats bonus on completion.
- **Battle loss penalty** — Forced repair picker (spend energy to heal KO'd glyphs). Emergency warp if insufficient energy.
- **Battle pacing** — Settings: Normal/Fast(2x)/Instant battle speed.
- **Capture screen flow** — Floating "Recruited! +15%" callout during combat. Breakdown on capture screen.
- **Tutorial hints** — Guided overlay system for new players.
- **Formation UX** — Skip mandatory formation, Fight+Formation buttons on combat popup.
- **Rift info button** — (i) button in dungeon header with tier/floors/hazard/boss/pool size.
- **Text overflow** — clip_text + text_overrun on RiftGate, RoomPopup, CodexBrowser labels.
- **Save slot management** — 5 manual slots + autosave, rename, auto-generated names.
- **Settings screen** — Battle speed (Normal/Fast/Instant), persisted to settings.json.
- **Endgame** — "ALL RIFTS CONQUERED!" message + codex percentage. Re-entry for captures/completion.
- **More items** — Revival Core, Rift Beacon, Affinity Prism, Hull Shield with full effect handling.
- **NPC dialogue expansion** — 5 phases, 2 lines each = 30 total lines, randomly picked per phase.
- **NPC side quests** — Lira (discover 8 species), Kael (clear 3 rifts), Maro (find 3 hidden rooms).
- **Lore objects** — Murals, data terminals, researcher notes, warning beacons in empty rooms.
- **Hidden room rewards** — Item + 15 hull HP restore bonus.
- **Difficulty/balance pass** — Full 7-rift arc verified. Technique power, status durations, capture rates, energy economy tuned.
- **Rift re-entry variation** — Pool-based random resolution, species uniqueness bias, puzzle round-robin.

### Art & Visual Pass

- Glyph portraits (18 species) + silhouettes via GlyphArt system
- Affinity-colored placeholder fallback for missing PNGs
- AI-informed transparency cleanup (BUG-026)
- Item icons with effect-type colors
- Magenta background prompts for clean background removal

### Bug Fixes

- **BUG-001** (P2): Boss portrait missing from rift guardian popup — added placeholder fallback
- **BUG-002** (P1): No way to re-engage current room after backing out — added `_re_engage_current_room()`
- **BUG-003** (P2): Enemy back row overlaps turn queue bar — increased bar height + field offset
- **BUG-004** (P2): Item popup overflows screen — capped ScrollContainer height
- **BUG-005** (P3): Inconsistent item row heights — fixed min height + text clamping
- **BUG-006** (P2): Save slot UI rework — 5 slots + autosave, rename, 2-line display
- **BUG-007** (P1): Capture bypasses GP capacity — mid-rift overflow with warning, barracks blocks exit
- **BUG-008** (P2): Invalid `custom_maximum_size` — replaced with `clip_contents` + anchor sizing
- **BUG-009** (P1): Lore Fragment Continue triggers phantom combat — clear room_data before display
- **BUG-010** (P2): Invalid `max_lines` property — replaced with `max_lines_visible`
- **BUG-011** (P3): Texture/RID leaks on exit — `GlyphArt.clear_cache()` on close
- **BUG-012** (P2): AoE overlaps next turn — turn boundary markers (0.3s delay)
- **BUG-013** (P1): Benched glyphs lost on manual save — added bench_provider Callable
- **BUG-014** (P1): Hull Shield has no effect — added save/load + fixed swap-use path
- **BUG-015** (P2): Heal Glyph auto-closes after one use — rebuild picker if targets remain
- **BUG-016** (P2): Codex descriptions overflow — max_lines_visible + ellipsis
- **BUG-017** (P2): NPC Phase 5 dialogue wrong — added "all_cleared" key, removed phase cap
- **BUG-018** (P2): NPC quest skips introduction — detect first visit via npc_read_quest
- **BUG-019** (P2): Conduit puzzle no reward when all discovered — fall back to random item
- **BUG-020** (P0): Ward Charm crash — wired _squad_overlay to DungeonScene
- **BUG-021** (P3): Fusion technique list no tooltips — added _build_technique_tooltip()
- **BUG-022** (P1): Heal Glyph ignores bench — added rift_pool iteration with separator
- **BUG-023** (P1): KO'd attacker's move resolves after interrupt — added is_knocked_out check
- **BUG-024** (P3): Terradon solo mastery too easy — requires T2+ enemies
- **BUG-025** (P3): Save slots popup too narrow — widened to 810px
- **BUG-026** (P3): Sprite pocket removal — AI-informed classification via Gemini vision
- **BUG-027** (P2): Neutral type aesthetic — full species redesign with constellation theme
- **BUG-028** (P2): Enemy room reverts after loss — store scan data on first combat entry
- **BUG-029** (P1): Capture goes to squad over GP cap — route to bench instead
- **BUG-030** (P2): Capture target arbitrary — prioritize recruit count, then KO order
- **BUG-031** (P2): Not a bug — scan was working correctly
