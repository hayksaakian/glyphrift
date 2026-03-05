# Session 10 — Polish Punchlist

## End-to-End Playthrough
- [ ] Full playthrough: title → new game → bastion → all 7 rifts → Apex Rift boss
- [ ] Verify phase progression unlocks correct rifts (2@1, 3@3, 4@5, 5@6)
- [x] Save/load works for bastion-boundary saves (auto-save on rift entry/completion)
- [ ] Mid-rift save/load: save dungeon state (current floor, room, crawler, HP) so quitting mid-rift doesn't lose progress
- [ ] Verify "New Game" / "Continue" / "Load Game" flows from title screen

## Crawler Upgrades (content gap)
- [x] Milestone checking: game logic to detect when upgrade milestones are met
  - "Clear a rift without taking Crawler damage" → +10 Hull HP
  - "Discover hidden room (1st/3rd/5th)" → unlock Ironclad/Scout/Hauler chassis
  - "Capture a Glyph of each affinity in one run" → +5 Energy
  - "Fuse 10 unique species" → +1 Cargo slot
  - "Seal a Major Rift" → +2 Capacity
- [x] Award upgrades: call `crawler_state.apply_upgrade()` when milestones trigger
- [x] Chassis selection UI in bastion (switch between unlocked chassis before a rift)
- [x] Upgrade notification: toast/popup when a milestone is achieved
- [x] Persist unlocked upgrades + active chassis in save/load
- [x] Crawler status panel showing unlocked upgrades and milestone progress

## Balance Pass
- [ ] Difficulty curve: T1 rifts beatable with starter squad, Apex requires fused T3+
- [ ] Capture rates feel fair (not too easy/hard)
- [ ] Hazard damage scaling across rift tiers
- [ ] Boss stat modifiers feel challenging but not unfair
- [ ] Energy economy: can you scan + use abilities without running dry?
- [ ] Mastery objectives achievable in normal play (not too grindy)

## Bug Fixing
- [x] Boss Phase 2 one-shot bug: skip phase transition if boss HP <= 0.
- [x] Squad wipe during rift → forced extraction works cleanly (verified)
- [x] Cargo swap flow when cargo is full during capture — fixed: now shows "CAPTURED! Swapped with X." result with Continue button
- [x] Puzzle rewards when inventory is full (swap picker) — verified working
- [x] Echo puzzle → combat → capture → return to dungeon flow — verified working
- [x] NPC dialogue advances with phase (capped at 3) — verified working
- [x] Codex discovery percentage tracks correctly — verified working
- [x] Healing shows "+0" floating damage number — fixed: emit actual heal amount through technique_used signal
- [x] Victory result screen soft-lock — fixed: Continue button pinned at bottom, mastery content in scroll area
- [x] Echo lure capture bonus — fixed: added item_bonus param to CaptureCalculator, dungeon_scene tracks active capture bonus from items, passes real combat stats (turns, enemy count, KOs) instead of hardcoded values. 3 unit tests added.
- [x] Capture popup shows breakdown of modifiers (Base 40% | Speed +10% | Lure +25%). Removed "No KO" bonus — redundant with turn bonus.
- [x] Boss capture on re-run: defeating a boss on a previously-cleared rift offers capture before showing result

## Active Effects HUD
- [x] Active effects strip on CrawlerHUD — green tags with tooltips (e.g. "Echo Lure +25%" / "Ward Charm")
- [x] Show what each effect does on hover (tooltip with description)
- [x] Clear effect when consumed (capture bonus cleared after capture, ward charm cleared after combat)
- [x] Ward charm now actually applies status immunity to first squad glyph (was consumed but never tracked)

## Dungeon Click-to-Navigate
Currently movement is one room at a time — click adjacent, wait, click next. Should work like an RTS: click any revealed room and auto-pathfind there, triggering each room's event (enemy, hazard, puzzle, etc.) along the way. Stops early if a room triggers combat or a blocking event.
- [x] BFS/shortest-path from current room to target (using room adjacency graph already in DungeonState)
- [x] Sequential `move_to_room()` calls along path, processing each room's event
- [x] Stop pathing early when a room triggers combat, capture, puzzle, or exit popup
- [x] Visual feedback: cyan path preview on hover, crawler token animates between rooms
- [x] Allow clicking non-adjacent revealed rooms (currently only adjacent clicks work)

## Combat UI Rework
The current layout reads like a spreadsheet, not a battle. Needs a full spatial redesign:

**Layout & spatial feel:**
- [ ] Two-sided battlefield: enemies top-center, player bottom-center facing each other
- [ ] Front/back rows conveyed spatially (front closer/larger, back further/smaller) not just text labels
- [ ] Compact panels — remove full-width row stretching, size to content
- [ ] KO'd glyphs visually minimized (shrunk or collapsed), not full-size greyed panels

**Active turn focus:**
- [ ] Highlight the acting glyph (glow/scale/border pulse) so it's instantly obvious whose turn it is
- [ ] Techniques appear as a contextual panel near the active glyph, not a disconnected sidebar
- [ ] Guard + Move Row grouped with techniques as a unified action menu

**Turn order strip:**
- [x] Compact horizontal strip (smaller portraits, ~32px) — shrunk from 64px to 32px
- [x] Clear current-turn marker (arrow or ring), dim upcoming, remove KO'd from queue
- [ ] Position as thin bar, not a major screen element

**HP bars:**
- [x] Larger, more readable HP bars — increased to 20px height
- [x] Color-coded thresholds: green (>50%) → yellow (25-50%) → red (<25%)
- [x] Show numeric HP overlaid on bar (not beside it)

**Battle log:**
- [x] Shrink to 2-3 most recent lines, not a scrolling 30% of screen
- [ ] Make expandable/collapsible for players who want detail
- [ ] Or overlay as a toast/feed that fades

**Boss Phase 2 communication:**
- [x] Phase 2 overlay should show what actually changed (e.g. "ATK +20%, SPD +15%, new techniques unlocked")
- [x] Brief stat-change callout or toast so the player understands the escalation

**Front/back row discoverability:**
- [ ] Visual cues for row tactical difference (back row takes 0.7x melee/ranged damage)
- [x] Show damage reduction indicator on back-row glyphs (e.g. shield icon, "−30%" badge)
- [x] Tooltip or first-time hint explaining row mechanics
- [x] Damage numbers could flash a "REDUCED" tag when back-row reduction applies

**Information cleanup:**
- [x] Remove redundant affinity text — emoji + colored border is enough
- [ ] Drop "FRONT" / "BACK" text labels if spatial layout already conveys row position

## Animations
Almost everything is instant/static right now. Key areas where motion would bring the game to life:

**Combat (highest impact):**
- [x] Attack: attacker lunges toward target, snaps back (tween position)
- [x] Damage received: target shakes + flashes white, then settles (already have floating damage numbers)
- [x] KO: defeated glyph shrinks/fades out rather than just greying
- [x] Status applied: icon pops in with a small scale bounce
- [x] Active turn: acting glyph pulses or breathes (subtle scale oscillation)
- [x] Guard: brief shield shimmer or flash on the guarding glyph
- [x] Victory/defeat: squad celebrates (bounce) or slumps (droop)

**Dungeon (high impact):**
- [x] Room movement: crawler token (cyan diamond) slides between rooms with tween
- [x] Fog reveal: rooms fade/dissolve in when discovered (not instant appear)
- [ ] Scan: ripple or wave effect emanating outward from current position
- [x] Hazard damage: screen shake + red vignette flash
- [ ] Floor transition: already has fade — could add a "descending" slide

**Capture (high impact):**
- [x] Capture attempt: glyph shakes/struggles for a beat (tension moment)
- [x] Success: particle burst + glyph slides into "captured" state
- [x] Failure: glyph breaks free with a quick dash off-screen

**Bastion (medium impact):**
- [ ] Fusion: parent cards slide together, bright flash, result card materializes
- [ ] Mastery complete: golden star burst / shimmer on the glyph
- [x] Card hover: subtle lift (scale up ~5%) with shadow
- [x] Screen transitions: sub-screens slide in/out rather than instant show/hide

**Micro-interactions (medium impact):**
- [x] Popups: scale up from center or slide in (not instant visible=true)
- [ ] Notifications/toasts: slide in from edge, auto-fade after delay
- [ ] Button press: subtle scale-down on click, bounce back on release

General approach: all tween-based (Godot Tween class), keep durations snappy (0.1-0.3s), respect `instant_mode` for testing. No skeletal/sprite-sheet animation needed — motion comes from position, scale, rotation, modulate tweens on existing nodes.

## UI Polish (general)
- [x] Rift Gate overflow: 5+ rift cards clip against edge — wrap in ScrollContainer, reduce card width
- [ ] Button hover/focus states consistent across all screens
- [x] Popup dismiss: click-outside-to-close on modal overlays (exit, repair, swap)
- [ ] Long text doesn't overflow (species names, technique lists, mastery descriptions)
- [ ] Screen transitions feel smooth (no flicker or state leaks)
- [x] Floor transition overlay shows rift name + floor number
- [x] Result screen (RIFT COMPLETE / EXTRACTED / RIFT FAILED) messaging

## Test Infrastructure
- [x] Create `test_runner.gd` to aggregate all test suites in one run
- [x] Verify all test suites pass: 1255/1255 across 11 suites

## Tutorial (low priority)
- [ ] Script tutorial_01 rift with guided intro (explain rooms, combat, capture)
- [ ] First-time hints for bastion features (barracks, fusion, codex)
- [ ] Tooltip or help text for crawler abilities
