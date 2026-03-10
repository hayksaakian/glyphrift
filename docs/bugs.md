# Bug Tracker

Hayk reports bugs verbally during playtesting. Claude triages, writes them up here, and fixes them.

**Workflow:** Hayk describes bug → Claude adds entry here → Claude fixes it → moves to Fixed
**Priority:** P0 (crash/blocker) · P1 (gameplay broken) · P2 (visual/UX) · P3 (minor/cosmetic)
**Status:** 🔴 Open · 🟡 In Progress · 🟢 Fixed

---

## Open Bugs

### BUG-006: Save slot UI needs rework — naming, location, rename, 5 slots
- **Priority:** P2
- **Status:** 🔴 Open
- **Steps:** Open save slots from bastion menu
- **Expected:** Richer save slot info, renamable, 5 slots
- **Actual:** Current UI shows "Phase 4 — 36 Glyphs — 2026-03-10" which truncates and lacks location context
- **Changes needed (this is a feature enhancement, not just a bug):**
  1. **5 slots** instead of 3 (+ autosave)
  2. **Richer save summary** — 2-line format: Line 1: save name (auto-generated or custom). Line 2: location (e.g. "Bastion", "Mid-rift: Voltaic Fissure F2"), phase, glyph count, date. Current single-line "Phase 4 — 36 Glyphs — 2026-03-10" is too condensed and truncates.
  3. **Auto-generated save names** — Generate a default name on save based on context (e.g. "Bastion Phase 4", "Voltaic Fissure F2"). Store the name in the save JSON alongside slot data.
  4. **Rename saves** — Add a "Rename" button per slot that opens an inline LineEdit or dialog to edit the save name. Store custom name in save JSON, overriding the auto-generated one.
  5. **Save JSON changes** — Add `save_name: String` and `location: String` fields to the save data dict. `location` should capture current game state (bastion vs mid-rift + rift name + floor).
- **Files likely involved:** `core/save_manager.gd` (save format + name/location fields), save slot UI (wherever the save slots panel is built), `ui/main_scene.gd` or `ui/bastion/bastion_scene.gd` (location context at save time)
- **Verify:** Open save slots, confirm 5 slots, 2-line summaries with location, rename works, name persists on reload.

---

## Fixed Bugs

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
