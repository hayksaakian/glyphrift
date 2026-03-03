# GLYPHRIFT — Game Design Document

**Version:** 0.3 (Prototype Spec — All Systems Defined)
**Genre:** Dungeon-Crawling Monster-Fusion RPG
**Platform:** PC (prototype), expandable to console
**Target Session Length:** 20–40 minutes per dungeon run
**Perspective:** Top-down 2D (prototype), upgradeable to isometric

---

## 1. Elevator Pitch

You are a Rift Warden — a specialist who pilots an armored crawler into unstable dimensional rifts to capture, bond with, and fuse creatures called **Glyphs**. Each rift is a procedurally-shuffled dungeon filled with hazards, wild Glyph squads, and environmental puzzles. Progression is driven by **fusing Glyphs together** to discover new species, unlock deeper rifts, and build a squad powerful enough to seal the source of the dimensional collapse threatening the world.

The fusion system is the heart of the game. There is no level-grinding. Glyphs grow through **mastery** (completing combat and exploration objectives), and fusing two mastered Glyphs produces a new, stronger creature whose species depends on the combination. Discovery — not repetition — drives the loop.

---

## 2. Design Pillars

### 2.1 — Every Decision Matters
No filler encounters. No passive navigation. Every room entered, every battle fought, and every fusion attempted should involve a meaningful choice with tradeoffs.

### 2.2 — Discovery Over Repetition
Players progress by experimenting, exploring, and mastering — not by repeating the same action hundreds of times. Curiosity is the primary motivator.

### 2.3 — Respect the Player's Time
Short, dense dungeon runs. Clear feedback loops. No progression gates that require grinding. A player who plays skillfully should always be able to move forward.

### 2.4 — Depth Through Composition
Strategic depth comes from how Glyphs are composed (fusion choices, team construction, positioning) rather than from raw stat inflation.

### 2.5 — Intuitive First, Deep Second
Every system should be understandable within one encounter of using it. Depth emerges from system interactions, not from complexity within any single system.

---

## 3. Core Gameplay Loop

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   BASE (Prepare) ──► RIFT (Explore + Fight + Capture)       │
│        ▲                          │                         │
│        │                          ▼                         │
│        │                  MASTERY (Grow Glyphs)             │
│        │                          │                         │
│        │                          ▼                         │
│        │                  FUSION (Combine Glyphs)           │
│        │                          │                         │
│        │                          ▼                         │
│        └──────── PROGRESSION (Stronger team, new rifts)     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**One full cycle should take 30–60 minutes.** Players should feel measurable forward progress every session.

---

## 4. The Crawler

The player navigates rifts inside a **Crawler** — a modular armored vehicle that serves as both transport and strategic resource.

### 4.1 — Crawler Stats

| Stat | Description | Prototype Default |
|---|---|---|
| **Hull HP** | Damage the Crawler can take from traps/hazards before forced extraction | 100 |
| **Energy** | Spent on active abilities (scanning, clearing obstacles, mid-run healing). Does NOT regenerate during a run. | 50 |
| **Capacity (CP)** | Maximum combined Glyph Power you can carry in your active squad. Stronger Glyphs cost more CP. | 12 |
| **Slots** | Number of Glyphs in your active battle squad. | 3 |
| **Cargo** | Number of additional Glyphs you can capture/carry home beyond your active squad. | 2 |

### 4.2 — Crawler Abilities (Energy Costs)

| Ability | Energy Cost | Effect |
|---|---|---|
| **Scan** | 5 | Reveals the contents of all rooms adjacent to the Crawler's current position |
| **Reinforce** | 8 | Prevents the next instance of trap damage to the Crawler |
| **Field Repair** | 10 | Restores 50% HP to one Glyph between battles |
| **Purge** | 15 | Clears an environmental hazard blocking a path |
| **Emergency Warp** | 25 | Immediately exit the rift. All captures, mastery progress, and items are retained. |

### 4.3 — Crawler Movement

- The Crawler moves **one room per step** along connected paths (see Section 9.3 for room connectivity).
- **Movement is free** and does not cost Energy.
- **Backtracking is allowed.** The player can revisit any previously explored room on the current floor. Cleared enemy rooms remain empty. Cleared hazard rooms remain safe.
- Moving to the EXIT room of a floor advances the player to the next floor. **Floors cannot be revisited** once the player descends.
- The Crawler's position is shown on the floor map at all times.

### 4.4 — Hull Damage and Forced Extraction

When **Hull HP reaches 0**, the Crawler is critically damaged and triggers an automatic Emergency Warp. On forced extraction:
- All **mastery progress** earned during the run is **retained**.
- All **captured Glyphs** in cargo are **retained**.
- The rift is **not marked as cleared**. The player must re-enter to attempt the boss again.
- The rift **reshuffles** on re-entry (new template selection, new room content distribution), but the boss encounter remains the same.

This means forced extraction is a setback but not a devastating loss. The player keeps their progress and can re-attempt with a better strategy.

### 4.5 — Crawler Upgrades

Upgrades are unlocked through **exploration milestones**, not currency.

| Milestone | Reward |
|---|---|
| Clear a rift without taking Crawler damage | +10 Hull HP (permanent) |
| Discover a hidden room | New Crawler chassis option (see below) |
| Capture a Glyph of each affinity in one run | +5 Energy capacity |
| Fuse 10 unique Glyph species | +1 Cargo slot |
| Seal a Major Rift | +2 Capacity (CP) |

**Crawler Chassis Options:**
Chassis are swappable between runs at the Crawler Bay. Each provides a passive bonus.

| Chassis | Bonus | Unlock |
|---|---|---|
| **Standard** | No bonus. Starting chassis. | Default |
| **Ironclad** | +25 Hull HP, −5 Energy | Discover 1st hidden room |
| **Scout** | Scan costs 3 Energy (instead of 5) | Discover 3rd hidden room |
| **Hauler** | +1 Cargo slot, −10 Hull HP | Discover 5th hidden room |

---

## 5. Glyphs (Creatures)

### 5.1 — Overview

Glyphs are creatures native to the rift dimensions. They are the player's combat units, fusion ingredients, and primary progression vector.

Each Glyph has:

- **Species** — Determines base stats, techniques, and affinity.
- **Tier** — The power level of the species (T1 through T4). Higher-tier Glyphs cost more CP to field.
- **Affinity** — One of three types in a rock-paper-scissors triangle.
- **Techniques** — 2–4 abilities usable in combat (hard cap of 4).
- **Mastery Track** — A set of objectives that must be completed before the Glyph is eligible for fusion.
- **Glyph Power (GP)** — The CP cost to include this Glyph in your active squad. Ranges from 2 (T1) to 8 (T4).

### 5.2 — Affinities

| Affinity | Strong Against | Weak Against | Thematic Identity |
|---|---|---|---|
| **Electric** | Water | Ground | Energy, speed, disruption |
| **Ground** | Electric | Water | Defense, endurance, control |
| **Water** | Ground | Electric | Chaos, transformation, burst damage |

**Damage multipliers:**
- Advantage (attacker strong against defender): **1.5x**
- Disadvantage (attacker weak against defender): **0.65x**
- Neutral (same type, or neutral technique): **1.0x**

The affinity of the **technique** is what matters, not the affinity of the Glyph using it. An Electric Glyph using a Neutral technique deals 1.0x to everything. An Electric Glyph that inherited a Ground technique through fusion deals Ground-affinity damage with that technique.

### 5.3 — Tiers

| Tier | GP Cost | How Obtained |
|---|---|---|
| **T1 (Spark)** | 2 | Captured in rifts, starting Glyphs |
| **T2 (Surge)** | 4 | Fusion of two T1s, or T1+T2. Captured in mid-tier rifts. |
| **T3 (Prime)** | 6 | Fusion of two T2s, or T2+T3. Captured rarely in Major Rifts. |
| **T4 (Apex)** | 8 | Fusion of two T3s only. Never captured. |

### 5.4 — Stat Model

| Stat | Description |
|---|---|
| **HP** | Health points. Glyph is knocked out at 0. |
| **ATK** | Determines damage dealt by offensive techniques. |
| **DEF** | Reduces damage from incoming offensive techniques. |
| **SPD** | Determines turn order. Tiebreaker for interrupt priority. |
| **RES** | Resistance to status effects. Compared against the technique's status accuracy (see Section 8.7). |

**Base stat ranges by tier:**

| Tier | HP | ATK | DEF | SPD | RES |
|---|---|---|---|---|---|
| T1 | 10–16 | 8–14 | 8–14 | 8–14 | 8–12 |
| T2 | 18–28 | 16–24 | 14–22 | 14–24 | 14–20 |
| T3 | 28–42 | 24–38 | 22–36 | 22–36 | 20–32 |
| T4 | 40–60 | 36–55 | 34–50 | 32–50 | 30–45 |

Fused Glyphs will exceed these base ranges due to inherited stat bonuses (see Section 7).

---

## 6. Mastery System

**Mastery replaces leveling.** Glyphs do not have XP or levels. Instead, each Glyph has a **Mastery Track** — a short list of objectives.

### 6.1 — Mastery Track Structure

Each Glyph has **3 mastery objectives.** Objectives are assigned at creation/capture and persist until completed.

**Objective assignment:** Each species has **2 fixed objectives** unique to that species (tied to its techniques and identity) and **1 objective drawn randomly** from a shared pool for its tier. This ensures every copy of the same species feels mostly consistent while adding a small element of variety.

### 6.2 — Objective Scoping Rules

These rules apply to all mastery objectives to prevent ambiguity:

- **"Win a battle"** = the player's squad wins the encounter. The Glyph must have **taken at least one turn** in that battle. It does **not** need to be alive at the end. (Rationale: this prevents a KO'd Glyph from being stuck with an uncompletable objective in a fight it mostly contributed to.)
- **"Use [technique] X times"** = cumulative across all battles and all rift runs. Progress is never lost. (Rationale: avoid punishing the player for retreating or being extracted.)
- **Multiple objectives can complete in the same battle.** If a single fight satisfies two or three objectives at once, all of them trigger. (Rationale: reward skilled play, don't artificially extend.)
- **Mastery progress is persistent.** It is retained across rift runs, including on forced extraction.

### 6.3 — Objective Pools

**Species-Fixed Objectives (2 per species):**
These are handcrafted per species and relate to the Glyph's specific techniques and role. See Appendix A for all 15 species' fixed objectives.

**Tier-Shared Random Pool (1 drawn per Glyph):**

**T1 Pool (introductory — teaches core mechanics):**
1. Win a battle using affinity advantage.
2. Win a battle with this Glyph in the front row.
3. Win a battle with this Glyph in the back row.
4. Win a battle without this Glyph being knocked out.
5. Capture a Glyph after a battle this Glyph participated in.

**T2 Pool (tactical — requires system mastery):**
1. Win a battle where this Glyph is at affinity disadvantage.
2. Win a battle against a squad of 3 enemies.
3. Successfully trigger an interrupt technique (if this Glyph has one; otherwise reroll).
4. Win a battle in 4 turns or fewer.
5. Win a battle where this Glyph dealt the finishing blow to 2+ enemies.

**T3 Pool (demanding — proves expertise):**
1. Win a battle using only this Glyph (solo; other squad members may be present but must not take a turn — i.e., they are KO'd or the fight ends before their turn).
2. Complete a rift floor without any Glyph being knocked out.
3. Win a battle against an enemy Glyph of a higher tier.
4. Win a battle in 3 turns or fewer.
5. Win a boss encounter with this Glyph in the active squad.

**T4 Glyphs do not have mastery tracks.** They are endgame units and cannot be fused further.

### 6.4 — Mastery Completion

When all 3 objectives are complete:
- The Glyph is flagged as **Mastered** (visible icon in UI — a glowing border around the Glyph's portrait).
- The Glyph gains a **permanent +2 to all stats** as a mastery bonus.
- The Glyph becomes eligible for **fusion**.
- The player is **not forced to fuse.** A mastered Glyph can continue to be used in combat indefinitely.

---

## 7. Fusion System

Fusion is the primary progression mechanic. Two Glyphs are consumed to create one new, stronger Glyph.

### 7.1 — Fusion Rules

1. Both parent Glyphs must be **Mastered**.
2. **Only adjacent tiers can fuse.** Valid combinations:
   - T1 + T1 → T2
   - T1 + T2 → T2 (with higher inherited stats than T1+T1)
   - T2 + T2 → T3
   - T2 + T3 → T3 (with higher inherited stats than T2+T2)
   - T3 + T3 → T4
   - **Invalid combinations (blocked in UI):** T1+T3, T1+T4, T2+T4, T4+anything. The Fusion Chamber greys out incompatible pairings.
3. **Same-species fusion is allowed** for any valid tier combination. Two copies of the same species can always fuse.
4. The resulting Glyph's **species** is determined by the Fusion Table (Section 7.5).
5. **Every valid tier combination of two Glyphs produces a result.** There are no "incompatible" pairs within the tier rules. If a specific pair isn't in the handcrafted table, it falls through to a **default rule** (see Section 7.6).
6. The resulting Glyph starts with **no mastery progress** — it has a fresh mastery track for its new species.
7. The parent Glyphs are **consumed** (removed from the roster).

### 7.2 — Stat Inheritance

The resulting Glyph's stats are calculated as:

```
ResultStat = BaseSpeciesStat + InheritanceBonus

InheritanceBonus (per stat) = floor((ParentA_Stat + ParentB_Stat) * 0.15)
```

So the bonus is **15% of the sum of both parents' stats in that category**, applied per-stat proportionally. This means parents with high ATK produce offspring with an ATK skew — the inheritance preserves the parents' statistical identity rather than flattening everything.

**Example:**
- Parent A (Zapplet): ATK 10, DEF 8
- Parent B (Sparkfin): ATK 12, DEF 9
- Result species (Thunderclaw) base: ATK 22, DEF 15
- ATK bonus: floor((10 + 12) × 0.15) = floor(3.3) = 3
- DEF bonus: floor((8 + 9) × 0.15) = floor(2.55) = 2
- Final Thunderclaw: ATK 25, DEF 17

**Inherited stats are baked in permanently.** They become part of that Glyph's stats and carry forward into future fusions as that Glyph's actual stats. This means multi-generational fusion chains produce increasingly powerful Glyphs — but each generation requires mastery, so the time investment scales naturally.

### 7.3 — Technique Inheritance

**Hard cap: 4 techniques per Glyph.**

The resulting Glyph always learns all of its **native techniques** (the techniques defined for its species). Then:

- If the species has **2 native techniques**, the player selects **1 technique from each parent** to inherit (total: 4).
- If the species has **3 native techniques**, the player selects **1 technique from either parent** to inherit (total: 4).
- If the species has **4 native techniques**, **no techniques are inherited** (already at cap).

**Inherited techniques retain their original affinity.** This is a key strategic lever — a Ground Glyph that inherits an Electric technique can hit Water enemies for super-effective damage, covering its weakness.

In the Fusion UI, inherited technique options are displayed with a preview of each technique's stats and affinity, so the player can make an informed choice.

### 7.4 — GP Overflow Rule

If the resulting Glyph's GP exceeds the player's current Crawler Capacity:
- **The fusion is allowed.** A warning message displays: "This Glyph's GP exceeds your current Capacity. It will be placed in reserve and cannot be added to your active squad until you upgrade your Crawler."
- The Glyph goes directly to **reserve** in the Barracks.
- The player can still view it, track its mastery (if applicable), and use it once they upgrade CP.
- This prevents the player from being locked out of a exciting fusion discovery due to a meta-progression gate. The reward still feels rewarding — they just need to progress slightly more before fielding it.

### 7.5 — Fusion Table (Complete for Prototype)

**T1 + T1 Fusions (all 15 unique pairs):**

| Parent A | Parent B | Result | Result Affinity |
|---|---|---|---|
| Zapplet | Sparkfin | Thunderclaw | Electric |
| Zapplet | Stonepaw | Vortail | Water |
| Zapplet | Mossling | Ironbark | Ground |
| Zapplet | Driftwisp | Thunderclaw | Electric |
| Zapplet | Glitchkit | Vortail | Water |
| Sparkfin | Stonepaw | Ironbark | Ground |
| Sparkfin | Mossling | Vortail | Water |
| Sparkfin | Driftwisp | Thunderclaw | Electric |
| Sparkfin | Glitchkit | Thunderclaw | Electric |
| Stonepaw | Mossling | Ironbark | Ground |
| Stonepaw | Driftwisp | Ironbark | Ground |
| Stonepaw | Glitchkit | Vortail | Water |
| Mossling | Driftwisp | Vortail | Water |
| Mossling | Glitchkit | Ironbark | Ground |
| Driftwisp | Glitchkit | Vortail | Water |

**Same-species T1 fusions:**

| Parent A | Parent B | Result |
|---|---|---|
| Zapplet | Zapplet | Thunderclaw |
| Sparkfin | Sparkfin | Thunderclaw |
| Stonepaw | Stonepaw | Ironbark |
| Mossling | Mossling | Ironbark |
| Driftwisp | Driftwisp | Vortail |
| Glitchkit | Glitchkit | Vortail |

**Design note:** At the T1→T2 level, cross-affinity fusions are common. This teaches the player early that mixing affinities produces unexpected (and useful) results, encouraging experimentation. The Codex hints reinforce this.

**T1 + T2 Fusions:**
When a T1 fuses with a T2, the result is always the **same T2 species as the T2 parent**, but with boosted inherited stats. This gives players a way to "power up" a favorite T2 by feeding it T1s without changing its species.

Exception: if the T1 and T2 are of **different affinities**, there is a 1-in-3 chance the result is a different T2 of the T1's affinity. This is flagged as a "Mutation" in the Codex and is logged as a separate discovery. (Implementation: use a seeded random based on the specific T1 species — so it's deterministic per species pair, not random per attempt. The player just doesn't know which pairs mutate until they try.)

**T2 + T2 Fusions (all 6 unique pairs + 3 same-species):**

| Parent A | Parent B | Result | Result Affinity |
|---|---|---|---|
| Thunderclaw | Ironbark | Riftmaw | Water |
| Thunderclaw | Vortail | Stormfang | Electric |
| Ironbark | Vortail | Terradon | Ground |
| Thunderclaw | Thunderclaw | Stormfang | Electric |
| Ironbark | Ironbark | Terradon | Ground |
| Vortail | Vortail | Riftmaw | Water |

**T2 + T3 Fusions:**
Same rule as T1+T2: result is the **same T3 species as the T3 parent**, with boosted inherited stats. Same cross-affinity mutation chance applies.

**T3 + T3 Fusions (all 6 unique pairs + 3 same-species):**

| Parent A | Parent B | Result | Result Affinity |
|---|---|---|---|
| Stormfang | Terradon | Nullweaver | Water |
| Stormfang | Riftmaw | Voltarion | Electric |
| Terradon | Riftmaw | Lithosurge | Ground |
| Stormfang | Stormfang | Voltarion | Electric |
| Terradon | Terradon | Lithosurge | Ground |
| Riftmaw | Riftmaw | Nullweaver | Water |

### 7.6 — Default Fusion Rule (Fallback)

If the prototype fusion table is ever expanded and a pair isn't explicitly defined:

```
Default result species = The T(n+1) species matching the affinity of whichever
parent has the higher total base stats. If tied, match Parent A's affinity.
```

This ensures the system never breaks if a designer adds new species but forgets to update every fusion pair.

### 7.7 — Fusion Discovery UX

1. Player enters Fusion Chamber.
2. Player selects **Parent A** from mastered Glyphs. Non-mastered Glyphs are visible but greyed out.
3. Player selects **Parent B** from remaining mastered Glyphs. Invalid tier pairings are greyed out.
4. UI displays:
   - Parent A and B sprites + current stats (including any prior inheritance bonuses).
   - **Result Tier:** Always shown (deterministic).
   - **Result Affinity:** Always shown (deterministic from table).
   - **Result Species:** Shows "???" for first-time combinations. Shows the species name and silhouette for previously discovered combinations.
   - **Inherited Stats Preview:** Shows the calculated bonus per stat so the player can see exactly what they're getting.
   - **Technique Inheritance:** Player selects which techniques to carry over (per rules in 7.3). Preview shows full technique details.
   - **GP Warning:** If result GP > current CP, a yellow warning displays (see 7.4).
5. Player confirms fusion.
6. **Discovery animation plays.** New Glyph revealed with species name, sprite, full stats, native techniques + inherited techniques.
7. Codex updates. If new species, a "NEW DISCOVERY" banner plays and the Codex entry unlocks with lore text.
8. If the species was previously only a silhouette in the Codex, it's now fully revealed.

### 7.8 — Hint System

To prevent pure guessing, the game provides fusion hints through three channels:

**NPC Hints (at The Bastion):**
NPCs rotate dialogue after each cleared rift. Some dialogue contains explicit fusion hints:
- "I once saw a Warden combine a Zapplet with a Stonepaw. The result was... not what anyone expected. Definitely not a Ground-type."
- "If you want to reach the Apex tier, you'll need two Primes of the same caliber. No shortcuts."
- "Mixing affinities is unpredictable, but it's where the real discoveries happen."

**Codex Silhouettes:**
Undiscovered species appear as silhouettes in the Codex with a single cryptic line:
- Thunderclaw: "Born from the convergence of two sparks."
- Vortail: "Where opposing forces collide, instability finds form."
- Nullweaver: "The apex of chaos — only those who have mastered the storm and the rift may summon it."

**Rift Environmental Clues:**
Certain rift rooms contain lore objects — murals, data fragments, broken Glyph containment pods — that provide thematic clues about fusion relationships. These are hand-authored and placed in specific room templates.

---

## 8. Combat System

### 8.1 — Overview

Battles are **3v3 turn-based** encounters. The player fields up to 3 Glyphs from their active squad against an enemy squad of 1–3 Glyphs.

### 8.2 — Formation & Positioning

Each side has two rows:

```
 FRONT ROW:  up to 2 Glyphs
 BACK ROW:   up to 1 Glyph
```

**Front Row:**
- Takes full incoming damage from all sources.
- Can use all technique ranges (Melee, Ranged, AoE, Piercing).
- Targeted first by enemy single-target attacks (attacker chooses which front-row target).

**Back Row:**
- Takes **70% damage** from single-target attacks (both Melee and Ranged).
- Takes **full damage** from AoE and Piercing techniques.
- **Cannot use Melee-range techniques.**
- Can only be directly targeted by the enemy if: (a) the front row is empty, or (b) the attacker uses a Piercing-range technique.

**Formation is chosen at battle start.** The player assigns each Glyph to a row before the first turn. If a front-row Glyph is knocked out, the player may **freely rearrange** surviving Glyphs at the start of their next turn (this does not cost a turn).

### 8.3 — Turn Order

Turn order is determined by **SPD**, highest first. All Glyphs from both sides are placed in a single queue.

**Tiebreaker:** If two Glyphs have identical SPD, ties are broken by a deterministic cascade:
1. **Higher Tier** acts first (evolved Glyphs are faster)
2. **Affinity cycle** — Electric > Water > Ground (electricity is fastest, water is fluid, ground is steady)
3. **Lower HP%** acts first (wounded Glyphs act out of desperation)
4. **Player side** wins over enemy (home-field advantage)
5. **Alphabetical species name** (final stable fallback)

**Turn Queue Display:** The UI shows the upcoming turn order as a horizontal bar of Glyph portraits at the top of the battle screen (similar to Final Fantasy X). The next 6 turns are visible. This is essential for interrupt decision-making — the player can see when an enemy is about to act and plan Guards accordingly.

### 8.4 — Turn Actions

Each turn, a Glyph performs **one** of the following:

1. **Attack** — Use a technique. The player selects the technique, then selects a target (if the technique is single-target). See targeting rules below.
2. **Guard** — The Glyph braces. Incoming damage is reduced by **50%** until this Glyph's next turn. If the Glyph has an **Interrupt technique** that is not on cooldown, it is **armed** while Guarding (see Section 8.6).
3. **Swap** — Switch positions with another allied Glyph (front ↔ back). This consumes the acting Glyph's turn. The swapped Glyph does not lose its place in the turn queue.

### 8.5 — Targeting Rules

Inspired by Pokemon's targeting clarity — the player always has full control over who they're attacking.

**Single-target techniques (Melee and Ranged):**
- The player selects which enemy to target from the **eligible pool**.
- Melee techniques can only target **front-row enemies** (unless front row is empty, in which case back row is targetable).
- Ranged techniques can target **any enemy** in either row.
- If a Ranged technique targets a back-row enemy while front-row enemies exist, the damage is **not reduced** (the 70% reduction only applies to incoming damage to your own back row, as a defensive benefit of positioning).

**Piercing techniques:**
- Can target any enemy regardless of row.
- Ignore the 70% back-row damage reduction on the defender's side.

**AoE techniques:**
- Hit **all enemies**.
- Back-row enemies take **70% damage** from AoE (their positional defense still applies).

**Support techniques:**
- Target selection follows the same row rules but applied to allies. A back-row Glyph using a Ranged support technique can buff/heal any ally.

### 8.6 — Interrupt System

Interrupt techniques are a special category. They **do not activate on the Glyph's normal turn.** Instead:

1. The Glyph must choose **Guard** on its turn.
2. While Guarding, if the Glyph has an Interrupt technique that is off cooldown, it becomes **armed**.
3. If an enemy subsequently performs an action that matches the Interrupt's **trigger condition**, the Interrupt fires **automatically**, immediately before the enemy's action resolves.
4. The Interrupt effect occurs (damage, debuff, cancellation, etc.) and then the enemy's action resolves with any modifications the Interrupt applied (e.g., damage reduced, attack cancelled entirely).
5. The Interrupt technique then goes on its stated cooldown.

**The Guard/Interrupt decision is made on the player's turn, before knowing exactly what the enemy will do.** This is intentional — it's a prediction/read system. The turn queue helps the player see which enemies are about to act, and over multiple encounters with the same enemy species, the player learns their patterns and can predict when to Guard.

**Interrupt Trigger Conditions (used across all Interrupt techniques):**
- `ON_MELEE` — Triggers when any enemy uses a Melee technique targeting this Glyph or an adjacent ally.
- `ON_RANGED` — Triggers when any enemy uses a Ranged technique targeting this Glyph.
- `ON_AOE` — Triggers when any enemy uses an AoE technique.
- `ON_SUPPORT` — Triggers when any enemy uses a Support technique (buff/heal).

If multiple Interrupt conditions could trigger simultaneously (rare), only one fires — the one belonging to the Glyph with the higher SPD.

### 8.7 — Status Effects

Status effects are applied by specific techniques that have a **status accuracy** value. When a status technique hits, the chance of applying the status is:

```
Apply Chance = StatusAccuracy - (Defender's RES / 2)
Minimum 10%, maximum 90%.
```

**Status Effect Definitions:**

| Status | Effect | Duration | Stackable? |
|---|---|---|---|
| **Burn** | Target loses 8% of max HP at the end of each of their turns. | 3 turns | No (reapplying refreshes duration) |
| **Stun** | Target skips their next turn. | 1 turn (instant) | No |
| **Slow** | Target's SPD is reduced by 30%. Affects turn order immediately. | 3 turns | No (refreshes) |
| **Weaken** | Target's ATK is reduced by 25%. | 3 turns | No (refreshes) |
| **Corrode** | Target's DEF is reduced by 25%. | 3 turns | No (refreshes) |
| **Shield** | Target takes 25% less damage from all sources. (Buff, not debuff.) | 2 turns | No (refreshes) |

**Immunity rule:** A Glyph that has just recovered from a status effect has **1 turn of immunity** to that same status. This prevents stunlock and creates windows of vulnerability.

**Status and Guarding:** Guarding does not prevent status application. However, the damage reduction from Guard does apply before Burn's percentage calculation (Burn uses max HP, not current, so Guard doesn't affect Burn specifically — but Guard does reduce the attack damage that applied the Burn).

### 8.8 — Damage Formula

```
RawDamage = (Technique.Power * (Attacker.ATK / Defender.DEF)) * AffinityMultiplier
FinalDamage = floor(RawDamage * RowModifier * StatusModifiers * GuardModifier * Variance)
```

Where:
- `AffinityMultiplier` = 1.5 (advantage), 1.0 (neutral), 0.65 (disadvantage)
- `RowModifier` = 0.7 if target is in back row and technique is not AoE/Piercing; 1.0 otherwise
- `StatusModifiers` = multiplied together: Weaken (0.75 to attacker's effective ATK), Corrode (0.75 to defender's effective DEF), Shield (0.75 to final damage)
- `GuardModifier` = 0.5 if defender is Guarding; 1.0 otherwise
- `Variance` = random float between 0.9 and 1.1 (±10% damage roll, like Pokemon)

**Minimum damage is always 1.** No attack ever deals 0.

### 8.9 — Techniques (Complete Prototype List)

All techniques used by the 16 prototype Glyph species:

**Offensive Techniques:**

| Name | Affinity | Range | Power | Cooldown | Special |
|---|---|---|---|---|---|
| Static Snap | Electric | Ranged | 8 | 0 | — |
| Jolt Rush | Electric | Melee | 14 | 2 | — |
| Arc Fang | Electric | Melee | 18 | 1 | — |
| Chain Bolt | Electric | Piercing | 12 | 2 | — |
| Thunder Cascade | Electric | AoE | 14 | 3 | — |
| Storm Lance | Electric | Ranged | 24 | 2 | — |
| Apocalt Strike | Electric | Melee | 32 | 3 | — |
| Rock Toss | Ground | Ranged | 8 | 0 | — |
| Vine Lash | Ground | Melee | 13 | 1 | — |
| Iron Ram | Ground | Melee | 18 | 2 | — |
| Quake Stomp | Ground | AoE | 13 | 3 | — |
| Spire Crush | Ground | Melee | 24 | 2 | — |
| Tectonic Slam | Ground | Piercing | 20 | 2 | — |
| Worldbreaker | Ground | AoE | 22 | 3 | — |
| Phase Dart | Water | Ranged | 8 | 0 | — |
| Glitch Spike | Water | Melee | 14 | 1 | — |
| Warp Claw | Water | Melee | 18 | 2 | — |
| Rift Pulse | Water | AoE | 14 | 3 | — |
| Null Beam | Water | Piercing | 22 | 2 | — |
| Void Collapse | Water | AoE | 26 | 3 | — |
| Tackle | Neutral | Melee | 10 | 0 | — |

**Status Techniques:**

| Name | Affinity | Range | Power | Cooldown | Status | Accuracy |
|---|---|---|---|---|---|---|
| Spark Shower | Electric | Ranged | 6 | 2 | Stun | 60% |
| Seismic Tremor | Ground | AoE | 5 | 3 | Slow | 70% |
| Erosion Wave | Ground | Ranged | 6 | 2 | Corrode | 65% |
| Entropic Touch | Water | Melee | 8 | 2 | Weaken | 65% |
| Destabilize | Water | Ranged | 4 | 2 | Burn | 70% |
| Scorch Bolt | Electric | Ranged | 7 | 2 | Burn | 60% |

**Support Techniques:**

| Name | Affinity | Range | Effect | Cooldown |
|---|---|---|---|---|
| Brace | Neutral | Self | +30% DEF for 2 turns (Shield status) | 3 |
| Root Hold | Ground | Ranged (ally) | Restores 20% of target's max HP | 3 |
| Energize | Electric | Ranged (ally) | +20% ATK for 2 turns | 3 |
| Flux Veil | Water | Ranged (ally) | Grants immunity to next status effect applied | 4 |
| Fortress | Ground | Self | Shield status (25% damage reduction, 2 turns) | 3 |
| Harmonic Pulse | Neutral | AoE (allies) | Restores 12% of max HP to all allies | 4 |

**Interrupt Techniques:**

| Name | Affinity | Trigger | Effect | Cooldown |
|---|---|---|---|---|
| Static Guard | Electric | ON_MELEE | Deals 10 Electric damage to attacker, reduces incoming hit by 50% | 3 |
| Stone Wall | Ground | ON_RANGED | Blocks the incoming attack entirely (0 damage). Does not deal damage back. | 4 |
| Phase Shift | Water | ON_AOE | This Glyph takes 0 damage from the AoE. Allies still take normal damage. | 3 |
| Null Counter | Water | ON_MELEE | Deals 14 Water damage to attacker. Does not reduce incoming damage. | 3 |
| Tremor Response | Ground | ON_MELEE | Applies Slow to the attacker (70% accuracy vs. RES). Does not reduce incoming damage. | 3 |
| Disrupt | Electric | ON_SUPPORT | Cancels the enemy's support technique entirely. No damage dealt. | 4 |

### 8.10 — Enemy Encounters (Dungeon)

**No random encounters.** Enemy squads are visible on the dungeon map as Glyph silhouette icons. Before engaging, the player can see:

- **Number of enemies** (1–3 icons).
- **Affinity of each enemy** (icon color: yellow=Electric, green=Ground, teal=Water).
- **Approximate tier** (icon size: small=T1, medium=T2, large=T3, glowing=T4).

The player can choose to **engage or avoid** most encounters. Mandatory encounters (blocking the path to the exit) are marked with a red border.

**Enemy AI Behavior:**
For the prototype, enemies use a simple priority system:
1. If able to KO a player Glyph this turn, target it.
2. If at affinity advantage against a player Glyph, prefer targeting it.
3. Otherwise, target the player Glyph with the lowest current HP.
4. Enemies use their strongest available technique (highest power, off cooldown).
5. Enemies never Guard (prototype simplification — boss enemies may Guard, see Section 9.5).

### 8.11 — Capture Mechanic

After winning a battle, **one enemy Glyph from the defeated squad** may drop as a capturable **Rift Fragment** (a glowing shard). The player is prompted to collect it or leave it.

**Which enemy drops:** The dropped Glyph is selected randomly from the defeated squad with equal probability for each member.

**Capture probability formula:**

```
BaseCaptureChance = 40%
TurnBonus = max(0, (ParTurns - ActualTurns)) * 10%    // +10% per turn under par
NoKOBonus = 15%   // applied if no player Glyph was KO'd during the battle
FinalChance = min(80%, BaseCaptureChance + TurnBonus + NoKOBonus)
```

**Par turns** by enemy count:
- 1 enemy: par = 3
- 2 enemies: par = 5
- 3 enemies: par = 6

**Maximum one capture attempt per battle.** Either a fragment drops or it doesn't.

**Cargo management:** If the player's Cargo is full when a fragment drops, they are prompted to either:
- **Swap** — Replace a cargo Glyph with the new capture (the old one is released permanently).
- **Leave** — Abandon the fragment. It cannot be recovered.

### 8.12 — KO and Recovery

- A Glyph knocked out (0 HP) during battle **cannot act for the rest of that battle.**
- After the battle ends (win or lose), all KO'd Glyphs are revived at **30% of max HP.**
- Non-KO'd Glyphs retain their **current HP** between encounters. HP does not regenerate between battles unless the player uses **Field Repair** (Crawler ability, costs 10 Energy, restores 50% max HP to one Glyph).
- **There is no permadeath.** Glyphs are never permanently lost from KOs.

### 8.13 — Losing a Battle

If all 3 of the player's Glyphs are KO'd in a single battle:
- The battle is **lost**. The player is pushed back to the **previous room** on the floor.
- All Glyphs are revived at **30% HP** as usual.
- The enemy squad in that room **resets to full HP** and can be re-attempted.
- No mastery progress is lost. No captures are lost.
- The Crawler takes **15 Hull damage** as a consequence (representing the emergency retreat).

This is punishing enough to matter (hull damage compounds over a run) but not so punishing that it feels unfair. The player can retreat, use Field Repair, and try again — or route around the encounter if it's optional.

---

## 9. Rift Dungeons

### 9.1 — Structure

Each rift is a **4–6 floor dungeon** with a boss encounter on the final floor.

### 9.2 — Room Types

| Room Type | Icon | Description |
|---|---|---|
| **Start** | ▶ | Entry point for the floor. Always safe. |
| **Empty** | ○ | Safe room. May contain a lore object (flavor text, no gameplay effect) or nothing. |
| **Enemy** | ☠ | Contains a visible enemy squad. Mandatory if it blocks the only path to EXIT. Optional otherwise. |
| **Hazard** | ⚠ | Environmental trap. Entering deals damage to the Crawler (see below). Can be cleared with Purge (15 Energy) before entering, or Reinforced against (8 Energy, negates next hit). |
| **Puzzle** | ✦ | Contains an environmental puzzle. Completing it grants a reward. Failing or skipping it has no penalty — the room becomes passable. (See Section 9.4.) |
| **Cache** | ◆ | Contains a reward: a consumable item, Crawler part, or fusion hint (see Section 9.6). |
| **Hidden** | (invisible) | Not visible on the map. Only revealed when the player uses **Scan** on an adjacent room. Contains rare rewards — unique Glyph encounters (chance to fight and capture a species not found elsewhere in this rift) or high-value items. |
| **Boss** | ★ | Final room of the last floor. Contains the rift boss. Must be defeated to clear the rift. |
| **Exit** | ↓ | Descends to the next floor. Always visible. |

### 9.3 — Room Connectivity

Rooms are laid out on a grid, but **not all adjacent rooms are connected.** Each template defines explicit connections (paths) between rooms. The floor map shows these paths as visible lines between room nodes.

This means the map is more like a **node graph** overlaid on a grid than a simple grid where all four neighbors are accessible. Dead ends, branching paths, and loops are possible and intentional.

**Implementation:** Each template is stored as a list of rooms with (x, y) positions on the grid and a list of connections (pairs of room IDs). The renderer draws connections as lines/corridors.

### 9.4 — Puzzle Rooms (Prototype Definitions)

Three puzzle types for the prototype:

**1. Sequence Lock**
The room contains 3–4 glyph-inscribed pillars, each displaying a symbol. An inscription on the wall shows the symbols in the correct activation order. The player activates the pillars in the matching sequence. Wrong order resets the puzzle (no penalty). The puzzle is a memory/attention check — the inscription disappears after 5 seconds of viewing.

**Reward:** Cache-tier item (consumable or Crawler part).

**2. Conduit Bridge**
The room has a broken energy conduit blocking the path. Three power nodes are scattered in the room, each color-coded to an affinity (Electric/Ground/Water). The player must connect the nodes in a way that forms a complete circuit. The correct answer is always: connect nodes so that the affinity triangle is completed (Electric→Water→Ground→Electric). The UI shows draggable energy lines between nodes.

**Reward:** Reveals one random silhouette species in the Codex (fusion hint).

**3. Echo Battle**
The room contains an echo — a ghostly projection of a Glyph. The player must defeat it in a **1v1 duel** using a single Glyph from their squad. The echo's affinity and tier are visible before accepting. If the player wins, they capture the echo as a bonus Glyph (goes to Cargo). If the player declines or loses, the room becomes passable with no penalty.

**Reward:** Free capture (bypasses normal capture probability).

### 9.5 — Boss Encounters

Bosses are **fixed species** per rift (not randomized). They are significantly stronger than standard enemies and have unique mechanics.

**Boss Behavior Differences from Normal Enemies:**
- Bosses **can Guard** and will do so strategically (when at low HP, or to bait the player into attacking before countering).
- Bosses have **2 phases.** At 50% HP, the boss transitions:
  - A brief animation plays.
  - The boss's stats change (typically +10% ATK and SPD).
  - The boss gains access to **one additional technique** not available in Phase 1.
  - Any active status effects on the boss are **cleared** on phase transition.
- Bosses always act last in the first turn of the battle (regardless of SPD) to give the player a chance to set up formation and strategy. After turn 1, normal SPD ordering applies.

**Prototype Boss Roster:**

| Rift | Boss Species | Tier | Affinity | Phase 2 Bonus Technique |
|---|---|---|---|---|
| Tutorial Rift | Thunderclaw (wild variant) | T2 | Electric | Chain Bolt (Piercing) |
| Minor Rift 1 | Ironbark (wild variant) | T2 | Ground | Quake Stomp (AoE) |
| Minor Rift 2 | Vortail (wild variant) | T2 | Water | Rift Pulse (AoE) |
| Standard Rift 1 | Stormfang | T3 | Electric | Thunder Cascade (AoE) |
| Standard Rift 2 | Terradon | T3 | Ground | Tectonic Slam (Piercing) |
| Major Rift | Riftmaw | T3 | Water | Null Beam (Piercing) + Destabilize (Burn) |
| Apex Rift | Nullweaver | T4 | Water | Void Collapse (AoE) + Phase Shift (Interrupt) |

**"Wild variant"** bosses have the same species as player-obtainable Glyphs but with +20% stats to represent their rift-empowered state. They cannot be captured.

### 9.6 — Items and Consumables

Items are found in Cache rooms and as Puzzle rewards. **Items are limited and intentionally scarce** — they're a bonus, not a required resource.

**Consumable Items (single-use, consumed on use):**

| Item | Effect | Where Found |
|---|---|---|
| **Repair Patch** | Restores 25 Crawler Hull HP. Usable during dungeon navigation (not in combat). | Cache rooms |
| **Surge Cell** | Restores 10 Crawler Energy. | Cache rooms |
| **Vital Shard** | Fully restores one Glyph's HP. Usable between battles. | Cache rooms (rare), Puzzle rewards |
| **Ward Charm** | Grants one Glyph immunity to the next status effect applied in the next battle. | Cache rooms |
| **Echo Lure** | Increases capture probability by +25% for the next battle. Consumed whether or not a capture occurs. | Puzzle rewards, Hidden rooms |

**Item Inventory Limit:** The player can carry **5 consumable items** at a time across a rift run. Items do not persist between runs — unused items are lost when returning to base. This prevents hoarding and keeps item decisions meaningful within a single run.

**Crawler Parts (permanent):**
Occasionally found in caches or as rewards. These unlock new chassis options or Crawler upgrades. They are automatically added to the Crawler Bay inventory at the end of a run.

### 9.7 — Hazard Damage Values

| Rift Tier | Hazard Damage (to Crawler Hull) |
|---|---|
| Minor Rift | 10 |
| Standard Rift | 15 |
| Major Rift | 20 |
| Apex Rift | 25 |

### 9.8 — Rift Re-Entry

**Cleared rifts can be re-entered.** On re-entry:
- The rift **reshuffles** (new template, new room contents).
- The boss is replaced by a slightly randomized **gauntlet encounter** (3 back-to-back squad battles) as the final-floor challenge. The original boss does not reappear.
- Wild Glyphs in re-entered rifts are drawn from the **full pool for that rift tier**, including T1s in higher-tier rifts. This ensures players always have access to fresh fusion material.
- Re-entered rifts do not grant milestone progress for clearing (you can't farm the "clear without Crawler damage" milestone by repeating easy rifts).

### 9.9 — Rift Tiers

| Rift Tier | Floors | Enemy Tiers | Boss Tier | Recommended Squad CP | Wild Glyph Pool |
|---|---|---|---|---|---|
| **Minor Rift** | 4 | T1 | T2 | 6–8 | T1 only |
| **Standard Rift** | 5 | T1–T2 | T3 | 10–14 | T1, T2 |
| **Major Rift** | 6 | T2–T3 | T3 | 14–18 | T1, T2, T3 (rare) |
| **Apex Rift** | 6 | T3–T4 | T4 | 18–24 | T1, T2, T3 |

### 9.10 — Fog of War

When the player enters a new floor:
- The **grid layout is visible** — the player can see that rooms exist and where paths connect them.
- **Room types are hidden** (shown as "?" icons) except for: Start (always revealed), Exit (always revealed), and Boss (always revealed on the final floor).
- Moving into a room reveals its type permanently.
- Using **Scan** reveals room types for all rooms connected to the Crawler's current room.

---

## 10. The Codex

A persistent database that records the player's discoveries.

### 10.1 — Sections

**Glyph Registry:**
- Each species has an entry.
- Undiscovered species appear as **silhouettes** with a one-line cryptic hint (see Section 7.8).
- Discovered species show: full sprite, all base stats, native techniques, lore text (2–3 sentences of flavor), known fusion paths (which combinations produce this species).

**Fusion Log:**
- Every fusion the player has performed, listed chronologically.
- Shows: Parent A species → Parent B species → Result species.
- Duplicate fusions are logged (so the player can see "I did this before and got the same result").

**Rift Atlas:**
- Records of completed rifts: rift name, clear time, whether any hidden rooms were found, boss defeated.
- Does not store maps (since rifts reshuffle, old maps have no value).

**Crawler Manifest:**
- Current chassis, stats, and available upgrade options.

### 10.2 — Completion Incentives

| Threshold | Reward |
|---|---|
| 25% of Glyph Registry discovered | Scan Energy cost reduced to 3 (from 5) |
| 50% of Glyph Registry discovered | +1 Cargo slot |
| 75% of Glyph Registry discovered | All Codex silhouette hints become more explicit |
| 100% of Glyph Registry discovered | Unlocks a hidden Apex Rift (endgame challenge) |

---

## 11. Base of Operations — The Bastion

### 11.1 — Facilities

- **Fusion Chamber** — Perform Glyph fusions with full preview UI (see Section 7.7).
- **Crawler Bay** — View Crawler stats, swap chassis, view available upgrades and milestone progress.
- **Barracks** — Manage Glyph roster. View mastery progress per Glyph. Assign active squad (up to Slots limit) and formation (front/back row pre-assignment, which carries into the next rift as the default formation). Reserve Glyphs are stored here.
- **Codex Terminal** — Browse the full Codex.
- **Rift Gate** — Select and enter available rifts. Shows rift tier, recommended CP, enemy affinity distribution (e.g., "primarily Electric"), and number of floors. Cleared rifts show a completion marker and can be re-entered.
- **Supply Cache** — View current consumable items. Items reset between runs so this is purely for reviewing what you have before entering a rift.

### 11.2 — NPCs

Three NPCs are present at The Bastion. Their dialogue updates after every rift completion.

**Kael (Veteran Warden):**
- Provides **combat tips** early game ("Don't forget — Guarding lets your interrupt techniques trigger automatically").
- Provides **fusion hints** mid-to-late game ("A colleague of mine combined two Surges of different affinities. The result didn't match either parent. Strange, right?").
- Provides **boss strategy hints** before major rifts ("The Riftmaw in the Major Rift switches to piercing attacks when it's cornered. Keep your back-row Glyph healthy.").

**Lira (Rift Researcher):**
- Provides **lore** about the world and rift ecology.
- Provides **Codex-linked hints** — her dialogue references specific silhouette entries. ("I've been studying the signature left by Glyph #009. It resonates with both storm and fracture energy. I wonder what would happen if you fused a Prime from each domain...")
- Unlocks **side objectives** after Standard Rifts: "Bring me a Water T2 and I'll calibrate your Codex scanner." (Reward: one silhouette is fully revealed.)

**Maro (Crawler Mechanic):**
- Provides **Crawler upgrade hints** ("If you can clear a rift without a scratch on the hull, I can reinforce the plating for you.").
- Sells nothing (no currency system). All upgrades come from milestones.
- Comments on the player's Crawler configuration ("Hauler chassis, huh? You planning to fill a zoo?").

---

## 12. Progression Arc (Prototype)

Target: **4–6 hours** of play.

| Phase | Content | Player State | Systems Introduced |
|---|---|---|---|
| **1 — Tutorial** | 1 scripted rift (3 floors). Guided experience. | 3 T1 Glyphs, base Crawler | Movement, combat basics, capture |
| **2 — Early Game** | 2 Minor Rifts (4 floors each). First boss fights. | Mixed T1s. First fusions → T2s. | Mastery, Fusion, Codex, Scan |
| **3 — Mid Game** | 2 Standard Rifts (5 floors each). Cross-affinity fusions. NPC hints active. | T2-focused squad. First T3 fusion. | Interrupts, Puzzles, Formation strategy |
| **4 — Late Game** | 1 Major Rift (6 floors). Demanding boss. | T2/T3 squad. | Status effects in enemy kits, Boss Phase 2, Crawler Energy pressure |
| **5 — Finale** | 1 Apex Rift (6 floors). T4 boss. | T3/T4 squad. Player should have 1+ T4 Glyph. | Full system mastery required |

### 12.1 — Tutorial Rift Script

**Floor 1 (2 rooms):**
- Start room: NPC hologram explains Crawler movement. Player moves to next room.
- Enemy room: Forced encounter vs. 1 T1 enemy. Tutorial overlays explain turn order, targeting, and affinity. Guaranteed capture on win.

**Floor 2 (3 rooms):**
- Enemy room: 2 T1 enemies. Tutorial explains formation (front/back row). Player must place at least one Glyph in back row.
- Cache room: Player finds a Repair Patch. Tutorial explains items.
- Exit room.

**Floor 3 (3 rooms):**
- Hazard room: Tutorial explains Crawler Hull HP and Purge/Reinforce decision.
- Enemy room: 2 T1 enemies, one at affinity advantage vs. the player's starter. Tutorial highlights affinity triangle.
- Boss room: T2 Thunderclaw. Tutorial explains boss phase transition at 50%. Designed to be beatable with the 3 starting T1s + any captured T1.

**After tutorial:**
- Return to Bastion. All facilities unlock.
- Kael explains mastery. Player sees that starting Glyphs likely have 1–2 mastery objectives already complete from tutorial battles.
- Lira explains the Codex.
- Maro explains Crawler Bay.
- Fusion Chamber unlocks. If any Glyphs are already mastered, player can fuse immediately. Otherwise, they enter a Minor Rift to finish mastery tracks.

---

## 13. Technical Specifications (Prototype)

### 13.1 — Data Architecture

All game content is **data-driven.** The following are defined in external JSON files (or YAML — team preference), not hard-coded:

| Data File | Contents |
|---|---|
| `glyphs.json` | All 15 species: name, tier, affinity, base stats, GP cost, native techniques (by ID), mastery fixed objectives |
| `techniques.json` | All techniques: name, type, affinity, range, power, cooldown, status effect (if any), status accuracy, trigger condition (if interrupt) |
| `fusion_table.json` | All valid fusion pairs: [speciesA_id, speciesB_id] → result_species_id. Order-independent (A+B = B+A). |
| `mastery_pools.json` | Tier-shared random objective pools with text descriptions and completion conditions (structured as enums/event types) |
| `rift_templates.json` | Per-rift: list of floor templates. Per-template: room positions, connections, fixed room types (START/EXIT/BOSS), room content pools with weights |
| `items.json` | All consumable items: name, effect type, effect value, description |
| `crawler_upgrades.json` | Milestone triggers (structured as event types) and corresponding stat modifications |
| `codex_entries.json` | Per-species: silhouette hint text, full lore text, related fusion hints |
| `npc_dialogue.json` | Per-NPC, per-game-phase: dialogue lines, conditions for display (rift cleared, species discovered, etc.) |
| `bosses.json` | Per-rift boss: species, stat overrides, Phase 1 and Phase 2 technique loadouts, Phase 2 stat modifiers |

### 13.2 — Core Systems (Implementation Priority)

Build in this order. Each layer depends on the ones above it.

| Priority | System | Description | Depends On |
|---|---|---|---|
| **1** | **Data Loader** | Parse all JSON data files into runtime objects. Everything else reads from this. | — |
| **2** | **Glyph Model** | Species, stats, techniques, mastery state, fusion eligibility check. | Data Loader |
| **3** | **Combat Engine** | Turn queue, targeting, damage calc, technique execution, status effects, interrupt system, formation, win/loss conditions. | Glyph Model |
| **4** | **Dungeon Navigation** | Grid/node room traversal, fog of war, Crawler energy management, hazard interaction, room entry triggers. | Data Loader |
| **5** | **Capture System** | Post-battle probability check, fragment drop selection, cargo management UI. | Combat Engine |
| **6** | **Mastery Tracker** | Per-Glyph objective tracking via combat event hooks. Listens to events emitted by the combat engine (e.g., "GLYPH_USED_TECHNIQUE", "BATTLE_WON_WITH_ADVANTAGE"). | Combat Engine, Glyph Model |
| **7** | **Fusion System** | Two-input lookup against fusion table, stat inheritance calc, technique inheritance selection UI, Codex update. | Glyph Model, Data Loader |
| **8** | **Base Hub (Bastion)** | Scene with Fusion Chamber, Barracks (squad/formation management), Crawler Bay, Rift Gate, Codex Terminal. Mostly UI/UX. | Fusion System, Glyph Model |
| **9** | **Rift Generation** | Template loading, room content randomization from weighted pools, floor sequencing. | Dungeon Navigation, Data Loader |
| **10** | **Boss AI** | Extended enemy AI with Guard usage, phase transition at 50% HP, technique rotation. | Combat Engine |
| **11** | **Puzzle Rooms** | Implement 3 puzzle types as mini-game interactions within dungeon rooms. | Dungeon Navigation |
| **12** | **Codex UI** | Browsable registry with silhouettes/reveals, fusion log, rift atlas. | Data Loader, Fusion System |
| **13** | **NPC System** | Dialogue display triggered by game-state conditions. | Data Loader |
| **14** | **Crawler Upgrades** | Milestone event detection, permanent stat modifications, chassis swap UI. | Dungeon Navigation, Combat Engine |
| **15** | **Items** | Inventory management (5-slot limit), item use during navigation, item pickup in cache/puzzle rooms. | Dungeon Navigation |

### 13.3 — Mastery Event Hooks

The mastery system works by listening to **events** emitted by the combat engine and dungeon systems. This is the recommended event list:

| Event | Payload | Emitted When |
|---|---|---|
| `BATTLE_WON` | squad composition, turns taken, KO list | Player wins any battle |
| `BATTLE_LOST` | squad composition | All player Glyphs KO'd |
| `GLYPH_USED_TECHNIQUE` | glyph_id, technique_id, target_id | Any technique is used |
| `GLYPH_KO` | glyph_id, battle_context | A Glyph reaches 0 HP |
| `GLYPH_DEALT_FINISHING_BLOW` | glyph_id, target_id | A Glyph's attack KOs an enemy |
| `AFFINITY_ADVANTAGE_HIT` | glyph_id, target_id | A technique hits with affinity advantage |
| `INTERRUPT_TRIGGERED` | glyph_id, interrupt_technique_id | An interrupt fires successfully |
| `CAPTURE_SUCCESS` | captured_species_id | A rift fragment is collected |
| `FLOOR_CLEARED_NO_KO` | floor_number | Player descends a floor with no KOs on that floor |
| `BOSS_DEFEATED` | boss_species_id, squad_composition | A boss encounter is won |

Each mastery objective is implemented as a **condition function** that evaluates against these events. When a condition is met, the objective is marked complete and the UI shows a notification.

### 13.4 — Prototype Scope Exclusions

Out of scope for prototype, noted for future:
- Guard Team faction choice at game start (story branching)
- Online features
- More than 15 Glyph species
- More than 7 rifts
- Full procedural generation (beyond template shuffling)
- Voice acting or animated cutscenes
- Difficulty settings
- New Game+

### 13.5 — UI Requirements (Minimum Viable)

**Dungeon View:**
- Top-down node graph. Rooms as circles/squares with type icons. Paths as lines between nodes.
- Fog of war: unrevealed rooms show as dim "?" nodes.
- Crawler position highlighted. Energy and Hull HP displayed in a persistent HUD bar.
- Item inventory accessible via button/hotkey.

**Battle View:**
- Two sides, each with front/back row Glyph sprites.
- HP bars above each Glyph. Status effect icons below HP bars.
- **Turn order bar** across the top showing next 6 turns as portraits.
- Action menu: Attack (opens technique list) / Guard / Swap.
- Technique list shows: name, affinity color, range icon, power, cooldown status, status effect (if any).
- Target selection: highlight eligible targets when a technique is selected. Click/tap to confirm.
- Interrupt trigger: visual flash + text overlay when an interrupt fires ("STATIC GUARD!"). Brief pause so the player registers it.
- Damage numbers float above targets.
- Phase transition: screen flash + boss sprite change + "PHASE 2" text overlay.

**Fusion View:**
- Two slots for parent Glyphs. Drag from roster or click to select.
- Greyed-out Glyphs that aren't mastered or are tier-incompatible.
- Result preview panel: Tier, Affinity, Species (??? or name), inherited stat bonuses, technique inheritance picker.
- Confirm button. Discovery animation on first-time species.

**Bastion View:**
- Simple scene or menu with facility buttons. Does not need to be a walkable hub for prototype — a menu screen with labeled sections is sufficient.

**Codex View:**
- Tabbed interface: Registry / Fusion Log / Rift Atlas / Crawler.
- Registry: Scrollable grid of species portraits (or silhouettes). Click to expand entry.
- Fusion Log: Chronological list, filterable by result species.

---

## 14. Balancing Guidelines

### 14.1 — Time Targets

| Activity | Target Duration |
|---|---|
| Master a T1 Glyph | 3–5 battles |
| Master a T2 Glyph | 5–8 battles |
| Master a T3 Glyph | 8–12 battles |
| Complete a Minor Rift | 15–20 minutes |
| Complete a Standard Rift | 20–30 minutes |
| Complete a Major Rift | 30–40 minutes |
| Complete an Apex Rift | 40–50 minutes |
| First T2 Glyph fusion | ~30–45 minutes into the game |
| First T3 Glyph fusion | ~2–2.5 hours into the game |
| First T4 Glyph fusion | ~3.5–4.5 hours into the game |

### 14.2 — Economy Rules

- After clearing any rift, the player should have at least **2 fusion-ready (mastered) Glyphs**, assuming they engaged with most encounters and captured when possible.
- Cross-affinity fusions should always produce **viable species** — never strictly worse than same-affinity fusions. Cross-affinity results should have interesting technique combinations that compensate for any stat differences.
- Crawler Energy should be tuned so that a player who scans every room will **run out of Energy by floor 4 of a 6-floor rift.** This forces prioritization.
- Boss encounters should be **beatable on the first attempt** by a player who has engaged with mastery and fusion systems, but punishing to a player who has been avoiding fights or ignoring type advantage.
- T1 Glyphs should **always be available** in re-entered rifts of any tier so the player never runs out of fusion material.
- Item drops should average **1–2 consumables per rift run** from caches, with puzzles providing the more valuable items.

### 14.3 — Difficulty Curve

Difficulty escalates through:
1. **Enemy squad composition** — later rifts feature mixed-affinity squads that can't be swept with a single advantage.
2. **Enemy technique variety** — early enemies use only basic attacks; mid-game enemies use cooldown techniques and status effects; late-game enemies use interrupts.
3. **Resource pressure** — later rifts have more hazard rooms and fewer caches, straining Crawler Hull and Energy.
4. **Boss mechanics** — later bosses have more dangerous Phase 2 transitions and wider technique coverage.
5. **Formation pressure** — later enemy squads are positioned strategically (e.g., a Piercing-range attacker in the back row targeting your back row).

Difficulty **never** comes from:
- Stat inflation that requires grinding.
- Mandatory re-runs of cleared content.
- Level-gated progression.
- RNG-dependent captures required for advancement.

---

## Appendix A — Complete Glyph Definitions (All 15 Species)

### — T1 ELECTRIC —

**Zapplet**
- **Stats:** HP 12 | ATK 10 | DEF 8 | SPD 14 | RES 9
- **GP:** 2
- **Techniques:**
  - Static Snap (Electric, Ranged, Power 8, CD 0)
  - Jolt Rush (Electric, Melee, Power 14, CD 2)
- **Fixed Mastery Objectives:**
  1. Use Jolt Rush 3 times.
  2. Win a battle without Zapplet taking damage.

**Sparkfin**
- **Stats:** HP 14 | ATK 12 | DEF 9 | SPD 11 | RES 10
- **GP:** 2
- **Techniques:**
  - Static Snap (Electric, Ranged, Power 8, CD 0)
  - Spark Shower (Electric, Ranged, Power 6, CD 2, Stun 60%)
- **Fixed Mastery Objectives:**
  1. Successfully apply Stun to an enemy via Spark Shower.
  2. Win a battle where Sparkfin is in the back row.

### — T1 GROUND —

**Stonepaw**
- **Stats:** HP 15 | ATK 11 | DEF 13 | SPD 8 | RES 11
- **GP:** 2
- **Techniques:**
  - Rock Toss (Ground, Ranged, Power 8, CD 0)
  - Brace (Neutral, Self, Shield 2 turns, CD 3)
- **Fixed Mastery Objectives:**
  1. Use Brace, then survive 2+ attacks in the same battle without being KO'd.
  2. Win a battle while Stonepaw is in the front row.

**Mossling**
- **Stats:** HP 16 | ATK 9 | DEF 11 | SPD 10 | RES 12
- **GP:** 2
- **Techniques:**
  - Vine Lash (Ground, Melee, Power 13, CD 1)
  - Root Hold (Ground, Ranged ally, heal 20% max HP, CD 3)
- **Fixed Mastery Objectives:**
  1. Use Root Hold to heal an ally 2 times.
  2. Win a battle where Mossling deals the finishing blow to at least 1 enemy.

### — T1 WATER —

**Driftwisp**
- **Stats:** HP 10 | ATK 13 | DEF 8 | SPD 14 | RES 8
- **GP:** 2
- **Techniques:**
  - Phase Dart (Water, Ranged, Power 8, CD 0)
  - Entropic Touch (Water, Melee, Power 8, CD 2, Weaken 65%)
- **Fixed Mastery Objectives:**
  1. Apply Weaken to an enemy via Entropic Touch.
  2. Have Driftwisp take the first turn in a battle (highest SPD).

**Glitchkit**
- **Stats:** HP 11 | ATK 11 | DEF 9 | SPD 13 | RES 10
- **GP:** 2
- **Techniques:**
  - Phase Dart (Water, Ranged, Power 8, CD 0)
  - Destabilize (Water, Ranged, Power 4, CD 2, Burn 70%)
- **Fixed Mastery Objectives:**
  1. Apply Burn to 2 different enemies (cumulative across battles).
  2. Win a battle in 5 turns or fewer.

### — T2 ELECTRIC —

**Thunderclaw**
- **Stats:** HP 20 | ATK 22 | DEF 15 | SPD 24 | RES 16
- **GP:** 4
- **Techniques:**
  - Arc Fang (Electric, Melee, Power 18, CD 1)
  - Chain Bolt (Electric, Piercing, Power 12, CD 2)
  - Static Guard (Electric, Interrupt ON_MELEE, 10 Electric dmg + 50% reduction, CD 3)
- **Fixed Mastery Objectives:**
  1. Successfully trigger Static Guard.
  2. Defeat an enemy with Chain Bolt (piercing kill).

### — T2 GROUND —

**Ironbark**
- **Stats:** HP 28 | ATK 18 | DEF 22 | SPD 14 | RES 20
- **GP:** 4
- **Techniques:**
  - Iron Ram (Ground, Melee, Power 18, CD 2)
  - Fortress (Ground, Self, Shield 2 turns, CD 3)
  - Stone Wall (Ground, Interrupt ON_RANGED, blocks attack entirely, CD 4)
- **Fixed Mastery Objectives:**
  1. Successfully trigger Stone Wall.
  2. Win a battle where Ironbark takes the most total damage on the team and survives.

### — T2 WATER —

**Vortail**
- **Stats:** HP 22 | ATK 20 | DEF 16 | SPD 22 | RES 17
- **GP:** 4
- **Techniques:**
  - Warp Claw (Water, Melee, Power 18, CD 2)
  - Destabilize (Water, Ranged, Power 4, CD 2, Burn 70%)
  - Phase Shift (Water, Interrupt ON_AOE, self takes 0 AoE damage, CD 3)
- **Fixed Mastery Objectives:**
  1. Successfully trigger Phase Shift.
  2. Apply Burn and then defeat the burned enemy before Burn expires.

### — T3 ELECTRIC —

**Stormfang**
- **Stats:** HP 32 | ATK 36 | DEF 24 | SPD 36 | RES 24
- **GP:** 6
- **Techniques:**
  - Storm Lance (Electric, Ranged, Power 24, CD 2)
  - Thunder Cascade (Electric, AoE, Power 14, CD 3)
  - Spark Shower (Electric, Ranged, Power 6, CD 2, Stun 60%)
  - Static Guard (Electric, Interrupt ON_MELEE, 10 Electric dmg + 50% reduction, CD 3)
- **Fixed Mastery Objectives:**
  1. Win a battle using only Stormfang (solo — other squad Glyphs must not take a turn).
  2. Stun an enemy with Spark Shower, then defeat it on Stormfang's next turn.

### — T3 GROUND —

**Terradon**
- **Stats:** HP 42 | ATK 28 | DEF 36 | SPD 22 | RES 32
- **GP:** 6
- **Techniques:**
  - Spire Crush (Ground, Melee, Power 24, CD 2)
  - Quake Stomp (Ground, AoE, Power 13, CD 3)
  - Root Hold (Ground, Ranged ally, heal 20% max HP, CD 3)
  - Tremor Response (Ground, Interrupt ON_MELEE, applies Slow 70%, CD 3)
- **Fixed Mastery Objectives:**
  1. Use Root Hold to heal an ally from below 30% HP.
  2. Win a battle against 3 enemies without any ally Glyph being KO'd.

### — T3 WATER —

**Riftmaw**
- **Stats:** HP 30 | ATK 38 | DEF 22 | SPD 34 | RES 26
- **GP:** 6
- **Techniques:**
  - Null Beam (Water, Piercing, Power 22, CD 2)
  - Rift Pulse (Water, AoE, Power 14, CD 3)
  - Entropic Touch (Water, Melee, Power 8, CD 2, Weaken 65%)
  - Null Counter (Water, Interrupt ON_MELEE, 14 Water dmg, CD 3)
- **Fixed Mastery Objectives:**
  1. Defeat an enemy of a higher tier.
  2. Apply Weaken, then hit the weakened enemy with Null Beam in the same battle.

### — T4 ELECTRIC —

**Voltarion**
- **Stats:** HP 48 | ATK 55 | DEF 38 | SPD 50 | RES 36
- **GP:** 8
- **Techniques:**
  - Apocalt Strike (Electric, Melee, Power 32, CD 3)
  - Thunder Cascade (Electric, AoE, Power 14, CD 3)
  - Storm Lance (Electric, Ranged, Power 24, CD 2)
  - Disrupt (Electric, Interrupt ON_SUPPORT, cancels enemy support, CD 4)
- **Mastery:** None (T4).

### — T4 GROUND —

**Lithosurge**
- **Stats:** HP 60 | ATK 42 | DEF 50 | SPD 32 | RES 45
- **GP:** 8
- **Techniques:**
  - Worldbreaker (Ground, AoE, Power 22, CD 3)
  - Tectonic Slam (Ground, Piercing, Power 20, CD 2)
  - Harmonic Pulse (Neutral, AoE ally, heal 12% max HP all allies, CD 4)
  - Stone Wall (Ground, Interrupt ON_RANGED, blocks attack entirely, CD 4)
- **Mastery:** None (T4).

### — T4 WATER —

**Nullweaver**
- **Stats:** HP 45 | ATK 52 | DEF 34 | SPD 48 | RES 40
- **GP:** 8
- **Techniques:**
  - Void Collapse (Water, AoE, Power 26, CD 3)
  - Null Beam (Water, Piercing, Power 22, CD 2)
  - Flux Veil (Water, Ranged ally, status immunity next application, CD 4)
  - Phase Shift (Water, Interrupt ON_AOE, self takes 0 AoE damage, CD 3)
- **Mastery:** None (T4).

---

## Appendix B — Sample Rift Template (Full Specification)

### Minor Rift: "The Frayed Edge" (4 Floors)

**Floor 1 — 6 rooms**

```
Room layout (grid positions):
    [R1: 0,0] ── [R2: 1,0] ── [R3: 2,0]
                      |
                  [R4: 1,1] ── [R5: 2,1]
                      |
                  [R6: 1,2]

Room assignments:
  R1: START
  R2: Content Pool A
  R3: Content Pool B
  R4: Content Pool A
  R5: Content Pool C
  R6: EXIT

Content Pools:
  Pool A (common): Enemy (60%), Empty (25%), Hazard (15%)
  Pool B (rewarding): Cache (50%), Puzzle (30%), Enemy (20%)
  Pool C (risky): Hazard (40%), Enemy (35%), Hidden-adjacent (25%)
```

**Floor 2 — 8 rooms**

```
Room layout:
    [R1: 0,0] ── [R2: 1,0] ── [R3: 2,0] ── [R4: 3,0]
                      |                          |
                  [R5: 1,1]     [R6: 2,1] ── [R7: 3,1]
                      |
                  [R8: 1,2]

Room assignments:
  R1: START
  R3: Content Pool B
  R6: Content Pool C
  R8: EXIT
  Others: Content Pool A

(Hidden room eligible on R6 if rolled as Hidden-adjacent — a hidden room
 is generated as an invisible node connected to R6, only revealed by Scan.)
```

**Floor 3 — 8 rooms**

```
Room layout:
    [R1: 0,0]               [R2: 2,0]
        |                       |
    [R3: 0,1] ── [R4: 1,1] ── [R5: 2,1]
                      |
    [R6: 0,2] ── [R7: 1,2]
                      |
                  [R8: 1,3]

Room assignments:
  R1: START
  R2: Content Pool C
  R4: Content Pool B
  R6: Content Pool A (mandatory enemy — only path to EXIT)
  R8: EXIT
  Others: Content Pool A
```

**Floor 4 (Boss Floor) — 5 rooms**

```
Room layout:
    [R1: 0,0] ── [R2: 1,0]
                      |
    [R3: 0,1] ── [R4: 1,1]
                      |
                  [R5: 1,2]

Room assignments:
  R1: START
  R2: Content Pool A
  R3: Cache (fixed — guaranteed pre-boss supplies)
  R4: Content Pool A
  R5: BOSS
```

### Template Data Format (JSON sketch)

```json
{
  "rift_id": "minor_01",
  "name": "The Frayed Edge",
  "tier": "minor",
  "floors": [
    {
      "floor_number": 1,
      "rooms": [
        {"id": "f1_r1", "x": 0, "y": 0, "type": "start"},
        {"id": "f1_r2", "x": 1, "y": 0, "type": "pool_a"},
        {"id": "f1_r3", "x": 2, "y": 0, "type": "pool_b"},
        {"id": "f1_r4", "x": 1, "y": 1, "type": "pool_a"},
        {"id": "f1_r5", "x": 2, "y": 1, "type": "pool_c"},
        {"id": "f1_r6", "x": 1, "y": 2, "type": "exit"}
      ],
      "connections": [
        ["f1_r1", "f1_r2"],
        ["f1_r2", "f1_r3"],
        ["f1_r2", "f1_r4"],
        ["f1_r4", "f1_r5"],
        ["f1_r4", "f1_r6"]
      ]
    }
  ],
  "content_pools": {
    "pool_a": {"enemy": 0.60, "empty": 0.25, "hazard": 0.15},
    "pool_b": {"cache": 0.50, "puzzle": 0.30, "enemy": 0.20},
    "pool_c": {"hazard": 0.40, "enemy": 0.35, "hidden_eligible": 0.25}
  },
  "boss": {
    "species_id": "ironbark_wild",
    "stat_modifier": 1.2,
    "phase2_bonus_technique": "quake_stomp"
  }
}
```

---

## Appendix C — NPC Dialogue Samples (Per Game Phase)

### Phase 1 — Post-Tutorial

**Kael:** "Welcome back, Warden. You handled yourself well in there. A tip: if you Guard with a Glyph that knows an Interrupt technique, it'll fire off automatically when the conditions are right. It's the difference between a good Warden and a great one."

**Lira:** "The Codex is your most valuable tool. Every species you discover is catalogued there — and the ones you haven't found yet leave traces. Pay attention to the silhouettes. I've added notes where I can."

**Maro:** "Your Crawler's seen better days, but she'll hold. Bring her back without a scratch sometime and I'll see what I can do about the hull plating."

### Phase 2 — After First Fusion

**Kael:** "You performed your first fusion? Good. Here's something they don't teach in the Academy: mixing affinities produces unexpected results. Don't be afraid to combine an Electric with a Ground. You might be surprised."

**Lira:** "Fascinating — the Glyph you created doesn't match any species in my field records. I've updated the Codex. I wonder... there are several silhouettes that seem to resonate with storm energy. Perhaps try fusing two of the same affinity next?"

**Maro:** "Hey, you're filling up that Cargo hold. If you find yourself turning down captures, come talk to me — I might be able to squeeze in another slot once you've done some exploring."

### Phase 3 — Before Major Rift

**Kael:** "The Major Rift is no joke. The boss in there — a Riftmaw — hits hard and fast. Phase 2 it switches to Piercing attacks, so your back row isn't safe. Bring something tanky with an Interrupt, or you'll be eating Null Beams all day."

**Lira:** "I've been studying Glyph #009 in the Codex — the one we haven't identified yet. Its energy signature resonates with both storm and fracture wavelengths. If I had to guess... you'd need to fuse an Electric Prime with a Water Prime to find it. But that's just a theory."

**Maro:** "You've been through a lot of rifts. Your Crawler's got character now — battle scars and all. If you manage to clear the Major Rift, I've got something special waiting for your Capacity rating."

---

*End of document. Version 0.3 — renamed from Riftbound to Glyphrift. Every system is defined to implementation specificity. Start with the Data Loader and Glyph Model, validate with the Combat Engine, and build outward. The game is ready for prototype development.*
