# Bug Tracker

Hayk reports bugs verbally during playtesting. Claude triages, writes them up here, and fixes them.

**Workflow:** Hayk describes bug → Claude adds entry here → Claude fixes it → moves to Fixed
**Priority:** P0 (crash/blocker) · P1 (gameplay broken) · P2 (visual/UX) · P3 (minor/cosmetic)
**Status:** 🔴 Open · 🟡 In Progress · 🟢 Fixed

---

## Open Bugs

_None currently._

---

## Fixed Bugs

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
