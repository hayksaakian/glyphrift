# Bug Tracker

Hayk reports bugs verbally during playtesting. Claude triages, writes them up here, and fixes them.

**Workflow:** Hayk describes bug → Claude adds entry here → Claude fixes it → moves to Fixed
**Priority:** P0 (crash/blocker) · P1 (gameplay broken) · P2 (visual/UX) · P3 (minor/cosmetic)
**Status:** 🔴 Open · 🟡 In Progress · 🟢 Fixed

---

## Open Bugs

*No open bugs.*

---

## Fixed Bugs

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
