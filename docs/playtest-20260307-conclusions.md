# Playtest Conclusions — March 7, 2026

Based on user testing of the Initiation Rift (tutorial_01) with T1 starter squad.

---

## A. Boss Encounter Design

*Combines: boss balance (#2), boss HP persistence (#3), boss flee/death loop (#5), boss hull damage (#9)*

### The core problem

Four separate playtest issues all stem from one root cause: **a failed boss attempt has no clean exit, and the numbers don't support recovery.** Thunderclaw (T2) is too strong for T1 starters, KO'd glyphs revive at 30% HP, the boss resets to full, hull takes -15 per loss, and the player can't leave. This creates a death spiral, not a difficulty challenge.

### Design principles

1. **Boss tier should match the expected player squad tier for that rift.** The Initiation Rift is a tutorial — the player has T1 starters and may not have learned fusion yet. The boss must be beatable with T1s.

2. **Boss loss ends the run.** Losing to a boss triggers automatic Emergency Warp (no energy cost). The player keeps all captures and mastery from the run, but the rift is not cleared. This mirrors the roguelike convention (Hades, Dead Cells, Slay the Spire) where boss death = run over. It eliminates the death loop entirely — there is no "retry" within a single run.

3. **Boss HP resets because there are no retries to persist across.** With auto-extraction on loss, the question of HP persistence is moot. For the record, full boss reset is also the universal standard in the genre (Pokemon, Temtem, Coromon, SMT, Nexomon). Only Pokemon GO retains boss damage, and only for passive multiplayer gyms.

4. **Boss loss hull damage should be steep (-50) to make the commitment feel real.** Combined with the warning before entry, this creates a meaningful decision: "Is my squad healthy enough to attempt the boss, or should I extract voluntarily and try a fresh run?" Normal battle losses remain at -15.

### Proposed boss room flow

```
Enter boss room → Room popup with warning:
  "Warning: Defeat means emergency extraction! (-50 hull)"
  [Challenge Boss] [Back Out]

If player challenges:
  Boss battle plays out normally (phases, etc.)

  WIN → Rift cleared, normal rewards
  LOSE → Auto Emergency Warp, -50 hull, keep captures/mastery
```

### Initiation Rift boss rebalance

**Current (broken):** Thunderclaw T2 — 24 HP, 26 ATK, 18 DEF (base 20/22/15 × 1.2x boss modifier)

**Proposed:** Downgrade to T1 stats with boss modifier:
- Target HP: ~16-18 (clearable in 3-4 rounds by full T1 squad)
- Target ATK: ~12-14 (dangerous but not one-shotting T1 glyphs)
- Target DEF: ~8-10 (ensures T1 attackers at ATK 10-13 deal meaningful damage per hit — roughly 2-5 per attack, 6-15 per round with 3 attackers)
- Arc Fang: should hit for ~60-70% of a T1's HP, not 100%+
- Phase 2 bonus (+10% ATK/SPD) remains as a tension mechanic

### Progression beats across rifts

| Stage | Boss Tier | Player Expected Squad | What it teaches |
|-------|-----------|----------------------|-----------------|
| Rift 1 (Tutorial) | T1 | 3 T1 starters + captured T1s | Combat basics, boss phases |
| Rift 2 (Early) | T2 | T1s + first T2 fusions | "You need to fuse to progress" |
| Rift 3+ (Mid/Late) | T2-T3 | Mixed T2/T3 squad | Strategic fusion, team composition |

### Tier scaling curve concern

The T1→T2 stat jump may be too steep:
- T1: HP 10-16, ATK 8-14
- T2: HP 18-26, ATK 16-24 (nearly double)

Consider compressing T2 slightly (HP 16-22, ATK 14-20) so fusion feels rewarding without creating an insurmountable wall. This needs playtesting once the Initiation boss is rebalanced.

### Edge case: low hull + low energy at boss room

If a player arrives at the boss room with low hull and insufficient energy for voluntary Emergency Warp (25 energy), they face a forced choice: attempt the boss (risking -50 hull → possible hull destruction) or be stuck. Two options:
- **Accept it as roguelike tension** — the player made risky choices getting here, and the run may be lost regardless.
- **Guarantee the player can always voluntarily warp before the boss** — e.g., place a cache room before every boss room (already the case in the tutorial template per GDD).

The pre-boss cache room likely resolves this naturally. No code change needed, but rift templates should always include a supply room before the boss.

---

## B. Capture System

*Combines: capture chance (#6), speed bonus (#7)*

### The core problem

40% base capture chance with speed bonus as the only modifier feels punishing and uncontrollable. The speed system rewards fast play (+10% per turn under par, max +30%), but gives the player no way to invest effort toward a specific capture.

### Proposal: Recruit combat action

Add a **"Recruit"** action in combat that boosts post-battle capture chance for the target species.

- Each use: +15% capture chance for that species
- Costs the glyph's turn (can't attack that turn)
- Stacks up to 3 times (+45% total)
- Thematically: your glyph is befriending/persuading the wild glyph

### Recruit and speed bonus are deliberately opposed

Recruiting costs turns, which works *against* the speed bonus. This is a feature, not a bug — it creates two distinct capture strategies:

| Strategy | Turns | Speed bonus | Recruit bonus | Effective capture % |
|----------|-------|-------------|---------------|-------------------|
| Blitz (kill fast) | Under par | Up to +30% | +0% | 40-70% |
| Befriend (recruit heavily) | Over par | +0% | Up to +45% | 40-80% (capped) |
| Balanced (1 recruit) | Near par | ~+10% | +15% | ~65% |

The player chooses: speed (decent odds, save HP) vs. dedication (near-guaranteed, costs turns and HP). Most captures will use the balanced approach — one Recruit turn, then finish the fight.

### Full capture formula (revised)

```
capture_chance = clamp(
    BASE (40%)
    + speed_bonus (0-30%)
    + recruit_bonus (0-45%)
    + item_bonus (Echo Lure: +25%)
, 0%, 80%)
```

### Scope note

The Recruit action applies only to wild encounters. Echo Encounters (puzzle rooms) already grant guaranteed captures and bypass this system entirely. With map-driven puzzle placement (see Section C), designers can place echo encounters to guarantee at least 1 capture per run regardless of RNG.

---

## C. Puzzle Design

*Combines: puzzle variety (#4)*

### Problem

Random puzzle selection led to 3 conduit puzzles and 1 echo encounter in a single run. No variety.

### Changes

**Remove Sequence Lock (Simon) puzzle.** It's a generic memory game with no connection to the game's world, glyphs, or combat systems. It exists for its own sake.

**Make puzzle assignment map-driven, not random.** Each puzzle room in the rift template specifies its puzzle type. This ensures:
- No repeats in a single run
- Intentional pacing and difficulty progression
- Tutorial rifts introduce one puzzle type at a time

**Keep Conduit Bridge and Echo Encounter:**
- **Conduit Bridge** — tests knowledge of the affinity cycle. Rewards system mastery.
- **Echo Encounter** — 1v1 duel with guaranteed capture on win. Rewards collection and tactical play.

### New puzzle type: Glyph Silhouette Quiz

**"Who's That Glyph?"** — multiple-choice identification:
- Show a darkened/distorted silhouette of a glyph species
- Present 4 species name choices
- Correct: reward (cache item, energy, or mastery hint)
- Wrong: no penalty, puzzle completes (one shot)
- Implementation: reuse glyph sprites with a silhouette shader/modulate
- Scaling: show T1 species the player has seen (easy) vs. unseen T3+ species (hard)
- Thematically fits: it's a field knowledge test — the Codex come to life

### Future puzzle ideas
- **Affinity Match** — identify a species' type weakness (tests combat knowledge)
- **Fusion Preview** — guess which two base glyphs produce a shown fusion result
- **Resonance Tuning** — match a frequency pattern with a slider/dial (thematic: glyphs resonate at certain frequencies)

---

## D. Crawler UI and Information

*Combines: Field Repair display (#8), button naming (#1)*

### Field Repair display

Field Repair heals exactly 50% of max HP (hardcoded in `dungeon_scene.gd:1276` as `maxi(1, int(float(target.max_hp) * 0.5))`). The current picker shows the raw heal amount but not the percentage:

**Current:** `"Stonepaw  8/15 HP  (+7 HP)"`
**Proposed:** `"Stonepaw  8/15 HP  (+7 HP, 50%)"`

This helps the player understand the system is percentage-based and predict heals for different glyphs without mental math.

### Button naming

Set `.name = "FightButton"` and `.name = "ChallengeButton"` on the combat popup buttons in `room_popup.gd` so automated test helpers can find them.

**Testing note:** Prefer `grb_click` over `press_button` in tests — it's more resilient to missing `.name` properties. Record this in CLAUDE.md.

---

## Summary of Changes

| # | Change | Priority | Scope |
|---|--------|----------|-------|
| A1 | Auto Emergency Warp on boss loss (-50 hull) | High | dungeon_scene.gd, battle_scene.gd |
| A2 | Add boss room warning popup | High | room_popup.gd |
| A3 | Rebalance Initiation boss to T1 (incl. DEF target) | High | rift_templates.json, glyphs.json, bosses.json |
| A4 | Ensure pre-boss cache room in all rift templates | Medium | rift_templates.json |
| B1 | Add Recruit combat action (+15%/use, max 3) | Medium | combat_engine.gd, battle_scene.gd, capture_calculator.gd |
| C1 | Remove Sequence Lock puzzle | Medium | dungeon_scene.gd, puzzle_sequence.gd |
| C2 | Make puzzle assignment map-driven | Medium | rift_templates.json, dungeon_scene.gd |
| C3 | Add Glyph Silhouette Quiz puzzle | Medium | New scene + script |
| D1 | Show HP + % in Field Repair picker | Low | dungeon_scene.gd |
| D2 | Name Fight/Challenge buttons | Quick fix | room_popup.gd |

### Design principles to record (CLAUDE.md / Memory):
- Boss tier must match expected player squad tier for that rift
- Boss loss = auto-extraction (no retry within a run)
- Recruit and speed bonus are opposing capture strategies (by design)
- Puzzle rooms are map-specified, not randomly selected
- Prefer `grb_click` over `press_button` in tests
