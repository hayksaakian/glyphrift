# Playtest Conclusions — March 7, 2026

Based on user testing of the Initiation Rift (tutorial_01) with T1 starter squad.

---

## 1. Button Naming Fix (Bug)

**Issue:** Fight and Challenge buttons on `room_popup.gd` don't have `.name` set, so `press_button` helper can't find them.

**Conclusion:** Set `.name = "FightButton"` and `.name = "ChallengeButton"` on the respective buttons. Additionally, record a CLAUDE.md or memory note: prefer `grb_click` over `press_button` in tests as it's more resilient to naming gaps.

**Priority:** Quick fix.

---

## 2. Boss Balance: Thunderclaw Unbeatable with T1 Squad

**Issue:** Thunderclaw (T2, 24 HP effective, ATK 26+) consistently survives with ~4 HP remaining. T1 starters (HP 10-15, ATK 10-13) can deal ~20 damage before being wiped. Arc Fang does 100+ damage (massive overkill). Creates an unwinnable death loop since boss resets to full HP but squad accumulates penalty HP.

**Current numbers:**
- Thunderclaw: 24 HP, 26 ATK, 18 DEF (base 20/22/15 * 1.2x boss modifier)
- T1 starters: 10-15 HP, 10-13 ATK, 8-13 DEF
- Phase 2 adds +10% ATK, +10% SPD

**Design questions resolved:**

- **Should the player clear the first boss with T1s only?** Yes — the Initiation Rift is the tutorial. It should be clearable with the starter squad without requiring fusion. The first boss should teach the player how boss fights work, not gatekeep progression behind fusion (which the player may not have learned yet).

- **Should the Initiation Rift boss be T1 instead of T2?** Yes. The tutorial boss should be T1 to match the player's squad tier. Later rift bosses can be T2+ to encourage fusion.

- **Should the boss stat modifier be reduced for tutorial?** Yes. Proposed change: reduce Thunderclaw to T1 stats or introduce a weaker T1 tutorial boss species. The 1.2x boss modifier can stay but applied to lower base stats.

**Proposed balance changes for Initiation Boss:**
- Downgrade boss to T1 (or create a T1 boss variant)
- Target boss HP: ~16-18 (clearable in 3-4 rounds by full T1 squad)
- Target boss ATK: ~12-14 (dangerous but not one-shotting T1 glyphs)
- Arc Fang damage needs to be proportional — should hit for roughly 60-70% of a T1's HP, not 100%+
- Phase 2 bonus can remain as a tension mechanic

**Tier scaling curve concern:** The T1-to-T2 stat jump may be too steep overall. Review whether the stat ranges in GDD Section 5.2 create a smooth power curve or a cliff. Current ranges:
- T1: HP 10-16, ATK 8-14
- T2: HP 18-26, ATK 16-24 (nearly double)

Consider compressing the T2 range slightly (e.g., HP 16-22, ATK 14-20) so fusion feels rewarding but T2 enemies aren't insurmountable walls.

---

## 3. Boss HP Persistence Between Attempts

**Issue:** Boss resets to full HP each retry while squad keeps penalty HP (-15 hull, revive at 30% max HP). Feels unfair on repeated attempts.

**Conclusion:** Boss HP should NOT persist between attempts. This is the standard pattern in monster-collecting games (Pokemon gym leaders, Temtem dojo leaders, Coromon titans all reset). The unfairness feeling comes from the death loop problem in #2 — if the boss is properly balanced for the player's tier, a single clean attempt should be winnable. The real fix is boss balance, not HP persistence.

However, the boss retry loop needs an escape valve — see #5.

---

## 4. Puzzle Variety and Design

**Issue:** Got 3 conduit puzzles and 1 echo encounter. No sequence puzzles appeared. Random selection leads to repetitive experiences.

**Conclusions:**

### Remove Sequence Lock (Simon) puzzle
The Simon-style memorize-and-repeat puzzle doesn't feel connected to the game's world or monsters. It exists for its own sake. Remove it.

### Make puzzle assignment map-driven, not random
Each puzzle room in the rift template should specify which puzzle type to use. This ensures:
- Good pacing (no repeats in a single run)
- Intentional dungeon design
- Tutorial rifts can introduce one puzzle type at a time

### Keep Conduit Bridge and Echo Encounter
Both feel thematically connected:
- **Conduit Bridge** — tests player's knowledge of the affinity cycle (Electric > Water > Ground > Electric). Directly rewards game system mastery.
- **Echo Encounter** — optional combat with guaranteed capture. Rewards skilled play with collection.

### New puzzle type: Glyph Silhouette Quiz
**"Who's That Glyph?"** — A multiple-choice identification puzzle:
- Show a darkened/distorted silhouette of a glyph species
- Present 4 answer choices (species names)
- Correct answer grants a reward (cache item, mastery hint, or energy)
- Wrong answer: no penalty, but puzzle completes (one shot)
- Thematically fits: it's a field knowledge test, like a pokedex challenge
- Implementation: reuse existing glyph sprite assets with a shader/modulate to create silhouettes
- Difficulty scaling: T1 glyphs the player has seen (easy) vs. T3+ glyphs they haven't (hard)

### Other puzzle ideas for future consideration:
- **Affinity Match** — given a glyph species, identify its type weakness (tests combat knowledge)
- **Fusion Preview** — show a fusion result silhouette, player guesses which two base glyphs combine to make it (tests fusion system knowledge)
- **Resonance Tuning** — a slider/dial puzzle where you match a frequency pattern (thematic: glyphs resonate at certain frequencies)

---

## 5. No Flee Option from Boss — Emergency Warp on Boss Loss

**Issue:** Once in a boss room, the only options are fight or keep fighting. Combined with the death loop, there's no escape.

**Conclusion:** Losing to a boss should trigger an automatic Emergency Warp (forced extraction). This is cleaner than adding a flee button mid-combat because:

1. It preserves the "bosses are mandatory" tension — you commit when you enter
2. It prevents the death loop — one failed attempt = extracted, keep your captures/mastery
3. It mirrors roguelike conventions where boss death = run over

**Implementation plan:**
- On boss battle loss: trigger Emergency Warp automatically (no energy cost)
- The room popup for boss rooms should add a warning line: "Warning: Defeat means emergency extraction!"
- This warning sets expectations before the player commits
- Hull damage on boss loss should be higher than normal (see #8) to make the extraction feel consequential
- Player retains all captures and mastery from the run (same as current Emergency Warp behavior)

---

## 6. Capture Chance — Recruit/Befriend Combat Action

**Issue:** 40% base capture chance with only speed-based modifiers feels punishing. Failed 2 of 3 attempts.

**Current formula:** 40% base + 10% per turn under par (max +30%) + item bonus (Echo Lure +25%), capped at 80%.

**Conclusion:** Add a **"Recruit"** combat action that improves capture odds. Two potential designs:

### Option A: Recruit as capture-chance booster (Recommended)
- New combat action available on any turn: **"Recruit"**
- Each use of Recruit on a target adds +15% to post-battle capture chance for that species
- Costs the glyph's turn (opportunity cost: not attacking/healing)
- Stacks up to 3 times (+45% total)
- Combined with base 40%: a player who spends 3 turns recruiting gets 85% (capped at 80%)
- This means: casual play = 40% base, dedicated effort = near-guaranteed capture
- Thematically: your glyph is befriending/persuading the wild glyph

### Option B: In-combat capture attempt
- Use Recruit to attempt capture mid-battle (like throwing a Pokeball)
- Success = instant capture, battle ends
- Failure = turn wasted, enemy gets free hit
- Chance based on target's remaining HP% (lower HP = higher chance)
- Risk/reward: try early (low chance, save HP) or weaken first (high chance, risk KO)

**Recommendation:** Option A is simpler and fits Glyphrift's post-battle capture flow better. Option B is more dramatic but requires significant combat flow changes.

---

## 7. Speed Bonus

**Issue:** +10% capture chance for fast wins is a nice touch.

**Conclusion:** Keep as-is. Already well-implemented via the turn-under-par system.

---

## 8. Field Repair Display

**Issue:** Field Repair heals 50% of max HP for 10 energy. The healing amount is shown but not obvious/predictable.

**Current behavior:** Shows the raw HP amount but not the percentage.

**Conclusion:** Update the Field Repair popup/tooltip to show both the amount and the percentage. Example: "Heal Stonepaw for 7 HP (50% of max)" — this helps the player understand the system and predict outcomes for different glyphs.

---

## 9. Hull Damage on Boss Loss

**Issue:** -15 hull per battle loss ramps up quickly across repeated boss fails.

**Conclusion:** With the Emergency Warp on boss loss fix (#5), the boss hull damage becomes a one-time extraction penalty rather than a repeating drain. Increase boss-specific hull damage to **-50** to make boss loss feel consequential and justify the "warning" message on the boss room popup.

This means:
- Normal battle loss: -15 hull (unchanged, manageable)
- Boss battle loss: -50 hull + emergency extraction (significant, run-ending for damaged crawlers)
- This creates a natural decision point: "Is my squad healthy enough to challenge the boss, or should I warp out voluntarily first?"

---

## Summary of Changes to Implement

| # | Change | Priority | Scope |
|---|--------|----------|-------|
| 1 | Name Fight/Challenge buttons | Quick fix | room_popup.gd |
| 2 | Rebalance Initiation boss to T1 | High | rift_templates.json, glyphs.json, bosses.json |
| 3 | No change (boss HP reset is correct) | — | — |
| 4a | Remove Sequence Lock puzzle | Medium | dungeon_scene.gd, puzzle_sequence.gd |
| 4b | Make puzzle assignment map-driven | Medium | rift_templates.json, dungeon_scene.gd |
| 4c | Add Glyph Silhouette Quiz puzzle | Medium | New scene + script |
| 5 | Auto Emergency Warp on boss loss | High | dungeon_scene.gd, battle_scene.gd |
| 6 | Add Recruit combat action | Medium | combat_engine.gd, battle_scene.gd, capture_calculator.gd |
| 7 | No change needed | — | — |
| 8 | Show HP + % in Field Repair popup | Low | dungeon_scene.gd or field_repair UI |
| 9 | Boss hull damage = -50 | Medium | dungeon_scene.gd |

### CLAUDE.md / Memory notes to add:
- Prefer `grb_click` over `press_button` in tests
- Boss balance principle: boss tier should match expected player squad tier for that rift
- Puzzle rooms should be map-specified, not randomly selected
