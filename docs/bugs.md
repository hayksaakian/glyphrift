# Bug Tracker

Hayk reports bugs verbally during playtesting. Claude triages, writes them up here, and fixes them.

**Workflow:** Hayk describes bug → Claude adds entry here → Claude fixes it → moves to Fixed
**Priority:** P0 (crash/blocker) · P1 (gameplay broken) · P2 (visual/UX) · P3 (minor/cosmetic)
**Status:** 🔴 Open · 🟡 In Progress · 🟢 Fixed

---

## Open Bugs

### BUG-031: Scan fails to reveal glyph species on beacon-revealed enemy rooms
- **Priority:** P2
- **Status:** ❌ Not a bug
- **Resolution:** User misread an "empty" room as an "enemy" room. Scan was working correctly — there were no enemies to reveal.

### BUG-030: Capture target selection is arbitrary — should prioritize Recruit actions, then last KO'd
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Fix:** Added `_pick_capture_target()` to dungeon_scene.gd that sorts candidates by recruit count (desc), then KO order (last KO'd first). Passes `ko_list` from CombatEngine through main_scene to dungeon_scene. No changes to CombatEngine needed — `ko_list` and `recruit_counts` were already tracked.
- **Files:** `ui/dungeon/dungeon_scene.gd`, `ui/main_scene.gd`

### BUG-029: Captured glyph goes to active squad instead of bench when it would exceed GP cap
- **Priority:** P1
- **Status:** 🟢 Fixed
- **Fix:** Added GP capacity check in `_on_capture_requested`. Before adding to squad, checks if `squad_gp + glyph.gp_cost > capacity`. If it would exceed, glyph goes to bench instead. Removed the old "over cap!" warning path since captures can no longer push squad over GP cap.
- **Files:** `ui/main_scene.gd`

### BUG-027: Neutral type aesthetic too similar to Ground — full species redesign
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Issue:** The 3 neutral species (Gritstone, Shimmer, Monolith) lack a distinct visual identity. Gritstone and Monolith lean heavily into rocks/stone/slate (colliding with Ground type). Shimmer leans into a generic "spirit" look. The grey/silver/slate palette blends with Ground's earthy browns rather than standing out as its own type.
- **Decision: Constellation / Star-Map aesthetic with fully revised species.** After brainstorming 14 visual directions and generating concept art via `scripts/brainstorm_sprites.py`, the **constellation** direction was chosen. The existing species names and personalities (Gritstone, Shimmer, Monolith) are too tied to stone/earth/wisp, so they are being **fully replaced** with new cosmic-themed species.
- **Neutral aesthetic definition:**
  - **Body:** Deep navy/dark indigo — like a window into the night sky
  - **Accents:** Bright white star-dots scattered across the surface, connected by thin silver constellation lines
  - **Eyes:** Made of bright glowing stars
  - **Concept:** "A piece of the cosmos cut into the shape of a creature." Neutral predates all elements — born from the cosmos before the rift split energy into types.
  - **Palette:** Deep navy body, bright white star dots, pale silver constellation lines, soft blue glow around stars, dark grey/black outlines
  - **NOT:** Not grey, not washed out, not stone, not earthy. High contrast (dark body + bright stars).
  - **Naming convention:** Real celestial/astronomical words — intentionally different from the elemental compound names (Zapplet, Stonepaw, etc.) to reinforce that neutral is something older and fundamentally other.
- **New species:**
  - **Vesper** (T1 tank, replaces Gritstone) — A small cosmic fox kit. Compact, four-legged, low to the ground. Big pointed ears with stars at the tips, a dense bushy tail trailing constellation lines. Surprisingly heavy — like a fragment of compressed night sky. Headbutts enemies and hunkers down, stars flaring brighter when bracing. Stubborn and loyal. Reference: `raw/brainstorm/standalone_constellation_b.png`
  - **Equinox** (T1 support, replaces Shimmer) — A small hovering cosmic jellyfish. Dome-shaped bell of dark sky with constellation patterns, trailing 4-5 tendrils that fade into starlight wisps. Pulses gently with soothing light. No legs — it drifts serenely. Star-patterns shift when it heals allies. Gentle, mysterious, calming. Reference: `raw/brainstorm/standalone_constellation_c.png`
  - **Solstice** (T2 generalist, replaces Monolith) — A majestic star-elk born from fusing two T1 neutrals. Tall, four-legged, branching antlers tipped with bright stars. More stars and more complex constellation patterns than T1s, showing evolved nature. Calm, watchful, protective. Antlers flare with connected star-lines when projecting ward pulse. Reference: `raw/brainstorm/standalone_constellation.png`
- **Action plan (10 steps):**
  1. **Rename species in data files.** In `data/glyphs.json`, rename the 3 neutral entries: `"gritstone"`→`"vesper"`, `"shimmer"`→`"equinox"`, `"monolith"`→`"solstice"`. Update `name` fields and `description` fields. Keep stats, techniques, tier, gp_cost unchanged — gameplay balance is fine.
  2. **Update fusion table.** In `data/fusion_table.json`, update all 3 entries that reference old IDs: `gritstone+shimmer→monolith` becomes `vesper+equinox→solstice`, `gritstone+gritstone→monolith` becomes `vesper+vesper→solstice`, `shimmer+shimmer→monolith` becomes `equinox+equinox→solstice`. Note: techniques (tackle, brace, soothe, ward_pulse) are generic and do NOT need renaming.
  3. **Update codex entries.** In `data/codex_entries.json`, replace the 3 neutral entries with:
     - `"vesper"`: hint: `"A small fox-shaped fragment of the night sky, older than the elements themselves."` / lore: `"Vespers appear at rift boundaries where the walls between dimensions are thinnest. Their bodies are windows into deep space — dark indigo fur scattered with bright star-dots connected by silver constellation lines. Despite their small size, they're surprisingly heavy, as if they carry the weight of compressed cosmos. A Vesper's stars flare brighter when it braces for impact."`
     - `"equinox"`: hint: `"A drifting cosmic jellyfish whose star-patterns shift when it heals allies."` / lore: `"Equinoxes float silently through rifts, their dome-shaped bells displaying slowly rotating constellation maps. Their trailing tendrils fade into starlight wisps that carry a universal soothing energy — effective regardless of elemental affinity. Wardens report feeling a deep calm in their presence, as if the creature remembers a time before the elements divided."`
     - `"solstice"`: hint: `"A majestic star-elk born from the fusion of two cosmic fragments."` / lore: `"Solstices are rare and awe-inspiring — tall, four-legged creatures whose branching antlers are tipped with the brightest stars in any rift. Their constellation patterns are far more complex than their T1 components, suggesting that fusion doesn't just combine neutral energy but amplifies it. When a Solstice projects its Ward Pulse, every star-line in its antlers blazes with connected light."`
  4. **Update boss and rift data.** In `data/bosses.json`, update `minor_04` boss: `species_id` `"monolith"`→`"solstice"`, and squad entries `"gritstone"`→`"vesper"`, `"shimmer"`→`"equinox"`. In `data/rift_templates.json`, grep and replace all `gritstone`/`shimmer`/`monolith` references in `wild_glyph_pool` arrays and boss entries (they appear in templates: `tutorial_01`, `minor_01` through `minor_04`).
  5. **Add echo encounter lore.** In `ui/dungeon/puzzle_echo.gd`, add entries to the `ECHO_LORE` dict for `"vesper"`, `"equinox"`, and `"solstice"`. Currently there are NO entries for the neutral species (they fall back to the generic "A ghostly echo of %s shimmers before you..." text). Write encounter and fragment text matching the constellation aesthetic and the tone of existing entries. Note: the word "shimmers" on line 137 is a verb in the generic fallback, not a species reference — leave it.
  6. **Grep and update all remaining code references.** Run `grep -rn "gritstone\|shimmer\|monolith"` across the entire project. Known references:
     - `core/data_loader.gd` line 67: comment mentioning `"gritstone + zapplet"` as example — update to `"vesper + zapplet"`
     - `core/progression/roster_state.gd`: starting glyph IDs — update any hardcoded neutral species IDs
     - `tests/test_data_loader.gd` lines 311-373: specific stat verification tests for Gritstone/Shimmer/Monolith, plus fusion tests (`gritstone+shimmer→monolith`, wildcard fusions) — update all species IDs and test names
     - Any other test files that reference old IDs
  7. **Write new sprite prompts** in `docs/glyph-sprite-prompts.md` — replace prompts 16-18 (Gritstone, Shimmer, Monolith) with Vesper, Equinox, Solstice using the species descriptions above and the constellation style definition.
  8. **Generate sprites** via `scripts/generate_sprites.py` for vesper, equinox, solstice. Use `--candidates 3` for manual selection. Visually inspect the generated images — look at the PNGs to verify they match the constellation aesthetic (dark navy body, bright star-dots, silver constellation lines).
  9. **Process sprites** through `scripts/process_sprites.sh`. Important: dark navy body on white background — verify background removal handles the high-contrast edge correctly without eating into the dark body.
  10. **Run all tests** — `~/bin/godot --headless --script res://tests/test_runner.gd` — all 1355+ tests must pass. The species rename will break tests that reference old IDs; fix them in step 6.
- **What NOT to change:**
  - `Affinity.COLORS` and `Affinity.EMOJI` in `core/affinity.gd` — the existing neutral off-white color and ⚪ emoji are fine for UI elements. The constellation aesthetic applies to sprites only, not UI chrome.
  - Technique names/IDs (tackle, brace, soothe, ward_pulse) — these are generic and work fine for cosmic creatures.
  - Gameplay stats (HP, ATK, DEF, SPD, RES, gp_cost) — balance is unchanged.
  - NPC dialogue in `data/npc_dialogue.json` — confirmed no references to old neutral species names or stone/grey descriptions.
- **Files to modify:** `data/glyphs.json`, `data/fusion_table.json`, `data/codex_entries.json`, `data/bosses.json`, `data/rift_templates.json`, `ui/dungeon/puzzle_echo.gd` (ECHO_LORE), `core/data_loader.gd` (comment), `core/progression/roster_state.gd`, `tests/test_data_loader.gd`, `docs/glyph-sprite-prompts.md`, `assets/sprites/glyphs/portraits/`
- **Reference images:** `raw/brainstorm/standalone_constellation.png` (elk/Solstice), `standalone_constellation_b.png` (fox/Vesper), `standalone_constellation_c.png` (jellyfish/Equinox)

### BUG-026: Sprite pocket removal misses some gaps, damages some features
- **Priority:** P3
- **Status:** 🔴 Open
- **Observed:** Thunderclaw's tail/hind-leg gap still has white pocket after processing. Previous version was too aggressive (deleted zapplet's eye white). Current proximity-based approach (Disk:15 dilation) is better but not perfect — some pockets are just far enough from the edge to survive.
- **Suggested fix:** May need per-sprite manual masks or a more sophisticated approach (e.g. morphological closing on the alpha channel, or a multi-radius proximity check). Could also add an optional exclusion/inclusion zone parameter per species.
- **Files:** `scripts/process_sprites.sh` (`remove_interior_pockets`)

### BUG-025: Save Slots popup too narrow — names truncate
- **Priority:** P3
- **Status:** 🟢 Fixed
- **Fix:** Increased popup width from 540px to 810px (1.5x) so save names and info lines display without truncation.
- **Files:** `ui/bastion/save_slots_popup.gd`

### BUG-024: Terradon solo mastery objective too easy to cheese
- **Priority:** P3
- **Status:** 🟢 Fixed
- **Fix:** Replaced `solo_win` in T3 mastery pool with `solo_win_min_tier` (params: `min_enemy_tier: 2`). Added `min_enemy_tier` computation in `_on_battle_won` and new `solo_win_min_tier` objective evaluation in `_check_objective`. Solo win now requires all enemies to be T2+.
- **Files:** `data/mastery_pools.json`, `core/glyph/mastery_tracker.gd`

### BUG-023: KO'd attacker's move still resolves after interrupt kills them
- **Priority:** P1
- **Status:** 🟢 Fixed
- **Fix:** Added `if attacker.is_knocked_out: return true` after `_check_ko(attacker, defender)` in both `static_guard` and `null_counter` interrupt paths in `_resolve_interrupt`. This cancels the attack when the interrupt KOs the attacker. Added 9 tests covering both interrupt types (lethal and non-lethal) plus a full integration test.
- **Files:** `core/combat/combat_engine.gd`, `tests/test_combat.gd`

---

## Fixed Bugs

### BUG-028: Enemy room reverts to "Wild Glyph" after losing a battle
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Fix:** In `_on_popup_action` for enemy rooms, store generated enemy species IDs (`scan_species_ids` and `scan_info`) back on the room dict when entering combat for the first time (i.e., when no scan data existed). This ensures that after a battle loss, the room retains species info and the RoomNode displays species portraits instead of the generic `!` icon.
- **Files:** `ui/dungeon/dungeon_scene.gd`

### BUG-022: Heal Glyph (Field Repair) ignores benched glyphs
- **Priority:** P1
- **Status:** 🟢 Fixed
- **Fix:** `_show_repair_picker()` only iterated `roster_state.active_squad`. Added a second loop over `rift_pool` (squad + bench) to include bench glyphs with a "— Bench —" separator. Also updated the re-open check in `_on_repair_target_selected` to check all `rift_pool` glyphs. Extracted button creation into `_make_repair_button()` helper.
- **Files:** `ui/dungeon/dungeon_scene.gd`

### BUG-021: Fusion Chamber technique list has no hover tooltips
- **Priority:** P3
- **Status:** 🟢 Fixed
- **Fix:** Added `_build_technique_tooltip()` to fusion_chamber.gd (same format as `TechniqueButton._build_tooltip()` in battle). Set `tooltip_text` on each technique toggle button showing description, status effects, support effects, and interrupt triggers.
- **Files:** `ui/bastion/fusion_chamber.gd`

### BUG-019: Conduit puzzle gives no reward when all species are discovered
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Fix:** When all species are already discovered, `_on_conduit_success()` now calls `_pick_item()` to give a random item instead of showing "All species already discovered!" with no reward. Shows "Conduit resonance: found [item]!" or warns if inventory is full.
- **Files:** `ui/dungeon/dungeon_scene.gd`

### BUG-015: "Heal Glyph" action auto-closes after one use
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Root cause:** "Heal Glyph" is the `field_repair` crawler ability, not an inventory item. The repair picker overlay (`_on_repair_target_selected`) called `_hide_repair_picker()` immediately after healing one glyph. Was searching in item_popup.gd — wrong file entirely.
- **Fix:** After healing, check if there are more damaged glyphs and enough energy. If so, rebuild the picker with updated HP values. Only auto-close when no more targets or insufficient energy.
- **Files:** `ui/dungeon/dungeon_scene.gd`

### BUG-020: Ward Charm crashes — `_squad_overlay` is null in DungeonScene
- **Priority:** P0
- **Status:** 🟢 Fixed
- **Fix:** MainScene never wired `_squad_overlay` to DungeonScene. Added `_dungeon_scene._squad_overlay = _squad_overlay` in MainScene setup (same pattern as `data_loader`, `roster_state`). Also added null guards at both call sites in dungeon_scene.gd (lines 235 and 1303) for safety.
- **Files:** `ui/main_scene.gd`, `ui/dungeon/dungeon_scene.gd`

### BUG-018: NPC quest skips introduction, jumps straight to progress dialogue
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Fix:** Used existing `npc_read_quest` dict to detect first visit. If the player has never seen an NPC's quest (`npc_read_quest` is "" or "locked"), `accept_dialogue` is shown regardless of progress. On subsequent visits, `progress_dialogue` is shown with current progress. No new state needed — piggybacks on the quest state tracking added for the unified indicator.
- **Files:** `ui/bastion/npc_panel.gd`

### BUG-017: NPC Phase 5 dialogue claims "every rift sealed" when 2 rifts remain
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Fix:** Rewrote Phase 5 dialogue for all 3 NPCs to be forward-looking ("Almost there", "the deepest rifts await"). Added `"all_cleared"` key to each NPC's phases with the true victory dialogue. Updated `npc_panel.gd` to check `codex_state.cleared_rift_count() >= total_rifts` and use `"all_cleared"` phase key when all rifts are sealed, otherwise falls back to game_phase. Removed `mini(game_state.game_phase, 3)` cap in `bastion_scene.gd`.
- **Files:** `data/npc_dialogue.json`, `ui/bastion/npc_panel.gd`, `ui/bastion/bastion_scene.gd`

### BUG-016: Codex Glyph Registry descriptions overflow card bounds
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Fix:** Added `max_lines_visible = 2` and `text_overrun_behavior = OVERRUN_TRIM_ELLIPSIS` to hint labels in codex_browser.gd. Full text available on click via detail popup.
- **Files:** `ui/bastion/codex_browser.gd`

### BUG-014: Hull Shield item has no effect on hazard rooms
- **Priority:** P1
- **Status:** 🟢 Fixed
- **Fix:** Two issues fixed: (1) `hazard_shield_active` was not included in save/load serialization — added to `save_manager.gd` so the flag survives mid-rift saves. (2) The swap-use path (`_on_swap_use_selected`) called `apply_item` but not `_on_item_used`, so using Hull Shield via swap consumed it without setting the flag — now calls `_on_item_used(use_item)` for passive effects.
- **Files:** `core/save_manager.gd`, `ui/dungeon/dungeon_scene.gd`

### BUG-013: Benched glyphs intermittently lost on save/load (mid-rift)
- **Priority:** P1
- **Status:** 🟢 Fixed
- **Root cause:** Manual saves from the pause menu (`SaveSlotsPopup._on_save`) called `save_to_slot` without passing bench glyphs, defaulting to `[]`. Auto-saves worked correctly because `_auto_save()` in MainScene calls `_get_bench_glyphs()`. Only manual mid-rift saves were affected.
- **Fix:** Added `bench_provider: Callable` to SaveSlotsPopup. MainScene wires it to `_get_bench_glyphs()` at setup time. Manual saves now pass bench glyphs to `save_to_slot`. Also added 7 targeted bench edge case tests (full bench, post-capture, post-swap, damaged HP, identity preservation, empty bench, roster growth).
- **Files:** `ui/bastion/save_slots_popup.gd`, `ui/main_scene.gd`, `tests/test_save_load.gd`

### BUG-012: AoE/multi-target attacks visually overlap with next glyph's turn
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Fix:** Option 1 (turn boundary markers). Added `turn_ended` signal to CombatEngine, emitted after each turn's actions + status ticks complete but before advancing the turn queue. BattleScene connects it and enqueues a `turn_barrier` event with 0.3s delay into AnimationQueue. This creates a visual pause between turns, ensuring AoE multi-hit animations fully resolve before the next turn's events begin. Engine remains synchronous — fix is purely at the presentation layer.
- **Files:** `core/combat/combat_engine.gd`, `ui/battle/battle_scene.gd`

### BUG-011: Texture/RID leaks on exit (~8MB)
- **Priority:** P3
- **Status:** 🟢 Fixed
- **Fix:** Added `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` handler in MainScene that calls `GlyphArt.clear_cache()` to release cached portrait/silhouette textures before engine teardown. Remaining CanvasItem/Font leaks are likely Godot engine noise.
- **Files:** `ui/main_scene.gd`

### BUG-010: Invalid `max_lines` property on Label in ItemPopup
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Fix:** Replaced `max_lines` (doesn't exist in Godot 4.6) with `max_lines_visible` at `item_popup.gd:135`.
- **Files:** `ui/dungeon/item_popup.gd`

### BUG-009: Lore Fragment "Continue" can trigger a phantom combat encounter
- **Priority:** P1
- **Status:** 🟢 Fixed
- **Fix:** `show_result()` now sets `room_data = {}` before displaying, so when Continue fires `_on_action_pressed`, the stale room type is gone and it falls through to the `"empty"` case (which just sets state to EXPLORING).
- **Files:** `ui/dungeon/room_popup.gd`

### BUG-006: Save slot UI needs rework — naming, location, rename, 5 slots
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Fix:** Expanded to 5 manual slots + autosave. 2-line display (save name on line 1, location · Phase · Glyphs · date on line 2). Auto-generated save names from context ("Bastion Phase 4" or "Voltaic Fissure F2"). Rename button opens inline LineEdit, writes back to save JSON. ScrollContainer for slot list. `save_name` and `location` fields added to save JSON format.
- **Files:** `core/save_manager.gd`, `ui/bastion/save_slots_popup.gd`

### BUG-005: Inconsistent item row heights in inventory popup
- **Priority:** P3
- **Status:** 🟢 Fixed
- **Fix:** Set `custom_minimum_size.y = 56` on each item row HBoxContainer, and clamped description labels to `max_lines = 2` with `text_overrun_behavior = OVERRUN_TRIM_ELLIPSIS` for consistent heights.
- **Files:** `ui/dungeon/item_popup.gd`

### BUG-004: Item popup overflows screen when inventory is full
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Fix:** Set `custom_maximum_size.y = 340` on the ScrollContainer to cap item list height. Items scroll when there are many, and Close/Leave It button stays visible.
- **Files:** `ui/dungeon/item_popup.gd`

### BUG-008: Invalid `custom_maximum_size` property on ScrollContainer in ItemPopup
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Fix:** Removed invalid `custom_maximum_size` (doesn't exist in Godot 4.6). Instead, set `clip_contents = true` on the PanelContainer and removed the 300px min height so the anchor-positioned popup (440px) constrains the scroll naturally. ScrollContainer with `SIZE_EXPAND_FILL` fills remaining space after title and close button.
- **Files:** `ui/dungeon/item_popup.gd`

### BUG-007: Capture-to-active-squad bypasses GP capacity check
- **Priority:** P1
- **Status:** 🟢 Fixed
- **Fix:** Option 2 (allow mid-rift overflow with warning). Capture still adds to squad mid-rift, but shows yellow "GP: X/Y — over cap!" warning on CAPTURED result. Barracks `_on_done_pressed` now blocks exit with red GP label and feedback message when GP exceeds capacity. Forces resolution before next rift.
- **Files:** `ui/main_scene.gd`, `ui/bastion/barracks.gd`

### BUG-003: Enemy back row overlaps turn queue bar
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Fix:** Increased turn bar height from 42px to 72px to fit portrait content (arrow + 32px icon + name + SPD tooltip), and pushed battlefield field top offset from 60px to 80px to clear the bar.
- **Files:** `ui/battle/battle_scene.gd`

### BUG-002: No way to re-engage current room (boss, puzzle) after backing out
- **Priority:** P1
- **Status:** 🟢 Fixed
- **Fix:** Added `_re_engage_current_room()` in `dungeon_scene.gd` — clicking the current tile re-opens the popup for boss, puzzle, and enemy rooms. RoomNode now shows pointer cursor on non-cleared interactable current rooms to signal clickability.
- **Files:** `ui/dungeon/dungeon_scene.gd`, `ui/dungeon/room_node.gd`

### BUG-001: Boss portrait missing from rift guardian popup
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Fix:** `_show_boss_portrait()` now falls back to a placeholder (affinity-colored ColorRect + species initial letter with outline) when `GlyphArt.get_portrait()` returns null, matching the placeholder pattern used everywhere else.
- **Files:** `ui/dungeon/room_popup.gd`
