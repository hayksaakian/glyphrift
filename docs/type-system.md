# Glyphrift Type System — Design Draft

_Version: 2 — Status: **DRAFT** — approved in principle, not yet implemented._
_Replaces the 3-type triangle (Electric > Water > Ground) from GDD v0.3._

## Overview

8 combat types + Neutral (9 total). Glyphs can be single-type or dual-type. Techniques are always single-type. Offense and defense are decoupled — being SE against a type does not automatically mean you resist it.

## Types

| Type | Identity | Color (proposed) |
|------|----------|-----------------|
| **Fire** | Combustion, heat, raw destruction | Red-orange |
| **Ice** | Cold, stasis, crystallization | Pale blue |
| **Electric** | Energy, speed, circuits | Gold |
| **Ground** | Earth, solidity, stability | Brown |
| **Water** | Fluid, adaptive, erosion | Teal |
| **Void** | Emptiness, vacuum, dimensional entropy | Deep purple |
| **Bio** | Life force, growth, organic | Green |
| **Light** | Radiance, holy, spirit | White-gold |
| **Neutral** | No affinity — universal 1.0x | Grey |

## Offensive Chart (attacker deals 1.5x)

| Type | Super effective against |
|------|----------------------|
| Fire | Ice, Bio |
| Ice | Electric, Bio, Ground |
| Electric | Water, Void |
| Water | Fire, Ground |
| Ground | Electric, Light, Fire |
| Void | Fire, Water, Bio, Light |
| Bio | Water, Ground |
| Light | Ice, Void |
| Neutral | _(nothing)_ |

## Defensive Chart (defender takes 0.65x)

Decoupled from offense — not every SE relationship implies resistance.

| Type | Resists (takes 0.65x from) |
|------|---------------------------|
| Fire | Ice, Bio |
| Ice | Electric, Bio, Ground |
| Electric | Water, Void |
| Water | Fire, Ground |
| Ground | Electric, Light, Fire |
| Void | Fire, Water, Bio |
| Bio | Water, Ground |
| Light | Ice |
| Neutral | _(nothing)_ |

### Key decouplings

- **Light does NOT resist Void** (despite Light > Void offensively). Void hits Light at 1.5x with no resistance buffer.
- **Void does NOT resist Light** (despite Void > Light offensively). Light hits Void at 1.5x with no resistance buffer.
- This makes Void <> Light a pure "who strikes first" showdown — mutual destruction with no defensive safety net.

## Weakness Summary

| Type | Weak to (takes 1.5x from) | Resists (takes 0.65x from) |
|------|--------------------------|---------------------------|
| **Fire** | Water, Void, Ground | Ice, Bio |
| **Ice** | Fire, Light | Electric, Bio, Ground |
| **Electric** | Ice, Ground | Water, Void |
| **Water** | Electric, Void, Bio | Fire, Ground |
| **Ground** | Water, Bio, Ice | Electric, Light, Fire |
| **Void** | Light, Electric | Fire, Water, Bio |
| **Bio** | Fire, Ice, Void | Water, Ground |
| **Light** | Ground, Void | Ice |
| **Neutral** | _(nothing)_ | _(nothing)_ |

## Balance Notes

| Type | SE targets | Weaknesses | Resistances | Character |
|------|-----------|------------|-------------|-----------|
| Fire | 2 | 3 | 2 | Fragile attacker |
| Ice | 3 | 2 | 3 | Bulky offensive |
| Electric | 2 | 2 | 2 | Balanced |
| Water | 2 | 3 | 2 | Versatile but vulnerable |
| Ground | 3 | 3 | 3 | Most connected, sturdy |
| Void | 4 | 2 | 3 | Dominant threat |
| Bio | 2 | 3 | 2 | Fragile life force |
| Light | 2 | 2 | 1 | Glass cannon holy |
| Neutral | 0 | 0 | 0 | Safe but no leverage |

### Balance lever: Void > Light

Void is the most offensively dominant type (4 SE targets). If playtesting shows Void is too strong, the first knob to turn is **removing Void > Light**, reducing Void to 3 SE targets and Light to 1 weakness. This is noted as an explicit design option.

### Pocket options (not yet needed)

These matchups were discussed and set aside. They can be added if balance requires:

- **Ice > Electric resistance dropped** — Ice currently resists Electric. If Ice feels too bulky, remove this resistance (keep Ice SE against Electric offensively).
- **Water resists Ice** — Pokemon has this. Could help Water's fragility.
- **Ground immune to Electric** — Pokemon has this as a full immunity (0x). Could be added if Ground needs more defensive identity.

## Matchup Intuition Guide

Every matchup should pass the "one sentence" test:

| # | Matchup | Why |
|---|---------|-----|
| 1 | Fire > Ice | Heat melts ice |
| 2 | Fire > Bio | Fire burns living things |
| 3 | Ice > Electric | Cold kills circuits and batteries |
| 4 | Ice > Bio | Frost kills life |
| 5 | Ice > Ground | Permafrost freezes earth |
| 6 | Electric > Water | Current conducts through water |
| 7 | Electric > Void | Energy arcs through vacuum |
| 8 | Water > Fire | Water extinguishes flame |
| 9 | Water > Ground | Erosion and flooding |
| 10 | Ground > Electric | Earth grounds current |
| 11 | Ground > Light | Solid matter absorbs radiance |
| 12 | Ground > Fire | Earth smothers flame |
| 13 | Void > Fire | Vacuum snuffs flame (needs oxygen) |
| 14 | Void > Water | Vacuum boils water |
| 15 | Void > Bio | Emptiness snuffs life |
| 16 | Void > Light | Void consumes radiance |
| 17 | Light > Ice | Radiance breaks frozen stasis |
| 18 | Light > Void | Holy light banishes emptiness |
| 19 | Bio > Water | Life absorbs water |
| 20 | Bio > Ground | Roots crack earth |

## Dual Typing

Glyphs can have one or two types. Techniques are always single-type.

### Offense (attacker is dual-type)

**No STAB (same-type attack bonus).** This is an existing Glyphrift design choice — affinity lives on the technique, not the Glyph using it. A Fire/Ice Glyph using a Water technique deals exactly the same damage as a pure Water Glyph using the same technique. The attacker's type(s) never modify outgoing damage.

This means dual-typing is purely a defensive property. A Glyph's type determines what it resists and what it's weak to, not what it hits harder with. Offensive coverage comes from technique selection and inheritance through fusion.

### Defense (defender is dual-type)

When a dual-type Glyph is hit, look up the modifier for the attack's type against each of the defender's types, then **multiply** them (Pokemon/Temtem-style). This produces a wider range than single-type matchups:

| Scenario | Modifier |
|----------|----------|
| SE vs both types | 1.5 × 1.5 = **2.25x** |
| SE vs one, neutral vs other | 1.5 × 1.0 = **1.5x** |
| SE vs one, resisted by other | 1.5 × 0.65 = **0.975x** (cancel) |
| Neutral vs both | 1.0 × 1.0 = **1.0x** |
| Resisted by one, neutral vs other | 0.65 × 1.0 = **0.65x** |
| Resisted by both | 0.65 × 0.65 = **0.42x** |

The range (0.42x–2.25x) is meaningful but not as extreme as Pokemon's (0.25x–4x), since our base multipliers are 0.65x/1.5x instead of 0.5x/2x.

### Examples

- Electric attack vs **Water/Bio** defender: 1.5x (SE vs Water) × 0.65x (Bio resists Water) = **0.975x** (effectively neutral — the types cancel out)
- Ice attack vs **Bio/Ground** defender: 1.5x (SE vs Bio) × 1.5x (SE vs Ground) = **2.25x** (double super effective)
- Fire attack vs **Ice/Water** defender: 1.5x (SE vs Ice) × 0.65x (Water resists Fire) = **0.975x** (cancel)
- Void attack vs **Fire/Bio** defender: 1.5x (SE vs Fire) × 1.5x (SE vs Bio) = **2.25x** (double SE — Void wrecks this combo)

## Self-Resist

All types resist themselves (take 0.65x from same type). Neutral does not self-resist (always 1.0x).

## Neutral Type

Neutral has no offensive advantages, no weaknesses, and no resistances. It is the safe default — no risk, no reward. Neutral techniques always deal 1.0x regardless of defender type.

**Neutral wildcard fusion rule** (unchanged from GDD v0.3): When one fusion parent is Neutral, the lookup treats both parents as the non-Neutral species.

## Impact on Existing Systems

This type expansion requires changes to:

### Data files
- `data/glyphs.json` — new species for Fire, Ice, Void, Bio, Light affinities
- `data/techniques.json` — new techniques for new affinities
- `data/fusion_table.json` — expanded fusion pairs
- `data/mastery_pools.json` — new affinity-specific objectives

### Code
- `core/affinity.gd` — new COLORS and EMOJI entries
- `core/combat/damage_calculator.gd` — new advantage lookup, decoupled resistance lookup
- `core/combat/ai_controller.gd` — affinity targeting with new types
- `core/data_loader.gd` — validate new affinity strings

### Documentation
- `glyphrift-design-doc-v0.3.md` — affinity section, fusion table, species list
- `glyphrift-tdd-v1.1.md` — affinity enum, damage formula, code examples
- `docs/adding-a-glyph.md` — affinity options list
- `docs/sprite-asset-spec.md` — species reference table
- `docs/glyph-sprite-prompts.md` — species affinity references
- `docs/roadmap.md` — type system item (mark as designed)

### Design work (not code)
- Species roster expansion — target ~40 species (5 per type)
- Technique roster expansion — target ~80 techniques (10 per type)
- Fusion table redesign — combinatorial explosion needs careful curation
