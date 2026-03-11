# Bug Tracker

Hayk reports bugs verbally during playtesting. Claude triages, writes them up here, and fixes them.

**Workflow:** Hayk describes bug → Claude adds entry here → Claude fixes it → moves to Fixed
**Priority:** P0 (crash/blocker) · P1 (gameplay broken) · P2 (visual/UX) · P3 (minor/cosmetic)
**Status:** 🔴 Open · 🟡 In Progress · 🟢 Fixed

---

## Open Bugs

---

## Fixed Bugs

### BUG-015: "Heal Glyph" action auto-closes after one use
- **Priority:** P2
- **Status:** 🟢 Fixed
- **Root cause:** "Heal Glyph" is the `field_repair` crawler ability, not an inventory item. The repair picker overlay (`_on_repair_target_selected`) called `_hide_repair_picker()` immediately after healing one glyph. Was searching in item_popup.gd — wrong file entirely.
- **Fix:** After healing, check if there are more damaged glyphs and enough energy. If so, rebuild the picker with updated HP values. Only auto-close when no more targets or insufficient energy.
- **Files:** `ui/dungeon/dungeon_scene.gd`

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
