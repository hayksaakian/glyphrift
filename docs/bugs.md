# Bug Tracker

Hayk reports bugs verbally during playtesting. Claude triages, writes them up here, and fixes them.

**Workflow:** Hayk describes bug → Claude adds entry here → Claude fixes it → moves to `docs/changelog.md`
**Priority:** P0 (crash/blocker) · P1 (gameplay broken) · P2 (visual/UX) · P3 (minor/cosmetic)
**Status:** 🔴 Open · 🟡 In Progress · 🟢 Fixed

_Fixed bugs (BUG-001 through BUG-031) have been moved to `docs/changelog.md`._

---

## Open Bugs

### BUG-032: Interrupt/Guard techniques are poorly communicated compared to other moves
- **Priority:** P2
- **Status:** 🔴 Open
- **Observed:** Interrupt techniques (Stone Wall, Static Guard, Null Counter, Disrupt, Phase Shift, etc.) feel obscured relative to normal attack/support techniques. Two specific issues:
  1. **Detail popup:** Interrupt techniques show a `?` where power would be (e.g., `🪨 Stone Wall ? ⏳4`). This looks like missing data rather than intentional. The trigger condition (ON_MELEE, ON_RANGED, ON_AOE, ON_SUPPORT) and the interrupt effect (block, counter damage, cancel) aren't shown at all — the player has no way to understand what the technique actually does from this view.
  2. **Battle action menu:** Guard appears as a plain button (`Guard [Static Guard]`) below the technique list, visually separated from the other moves. It doesn't match the technique button format (no affinity icon, no power/cooldown info). This makes it feel like a secondary/lesser action rather than a core part of the glyph's kit.
- **Expected:** Interrupt techniques should be presented with the same level of detail as attacks and support moves. The detail popup should show what the interrupt triggers on and what it does. The battle Guard button should feel like a first-class technique, not an afterthought.
- **Suggested fix:**
  - Detail popup: Replace `?` with the trigger type (e.g., "vs Melee", "vs Ranged", "vs AoE", "vs Support") and add a brief effect description (e.g., "Blocks attack" or "Counters 12 dmg")
  - Battle UI: Style the Guard button like a technique button with affinity icon, interrupt info, and cooldown — or integrate it into the technique list with a visual distinction (e.g., shield icon, different border color)
- **Files:** `ui/shared/glyph_detail_popup.gd` (technique display), `ui/battle/technique_button.gd` (button format), `ui/battle/battle_scene.gd` (Guard button creation)
