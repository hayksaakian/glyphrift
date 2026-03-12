# Glyphrift Art Direction

All visual assets share a unified style: bold outlines, flat fills, limited palettes, high contrast. Everything must read clearly at its smallest display size.

---

## Shared Principles

- **Bold black outlines** (2-4px at 512px, 1-2px at 128px) — defines every shape
- **Flat color fills** — no gradients, no soft brushwork, no painterly texture
- **Limited palette** — 3-5 colors per asset plus black outlines
- **High contrast** — distinct shapes on magenta (#FF00FF) generation background
- **Scale-friendly** — no thin lines or fine details that disappear at small sizes
- **Consistent lighting** — no cast shadows, no environment, no ground plane

---

## NPC Portraits

**Source**: 512x512 PNG, magenta background
**Display sizes**: 80x80 (dialogue panel), 48x48 (bastion hub button)
**Output**: `assets/sprites/npcs/{npc_id}.png`

### Shared NPC Style

Half-body portrait (head + shoulders + upper torso), facing slightly right in 3/4 view. Expressive face with clear emotion. Simple clothing with 2-3 accent colors. Bold black outlines, flat fills. Character should fill ~80% of canvas. Same vector/cartoon style as glyph sprites — these characters exist in the same world.

### Kael — Veteran Warden

- **Role**: Combat mentor, grizzled veteran
- **Palette**: Deep red (#CC4444) primary, dark grey armor accents, warm skin tone
- **Design**: Weathered face with a scar across one eyebrow. Short-cropped dark hair, greying at temples. Wears a red warden's cloak over dark plate armor. Strong jaw, serious but not unkind expression. Mid-40s.
- **Personality in pose**: Arms crossed or one hand on sword hilt. Steady, confident posture.
- **Prompt fragment**: `Half-body portrait of a grizzled fantasy soldier called "Kael" for a 2D RPG. Veteran Warden — a seasoned monster-tamer and combat instructor. Weathered face, scar across left eyebrow, short dark hair greying at temples. Wears a deep red warden's cloak over dark plate armor. Arms crossed, steady confident expression — tough but fair. Mid-40s human male.`

### Lira — Rift Researcher

- **Role**: Codex/discovery mentor, curious scientist
- **Palette**: Teal (#44AACC) primary, white lab coat accents, warm skin tone
- **Design**: Young woman with bright curious eyes behind round glasses. Hair pulled back in a messy bun with a pencil stuck in it. Wears a teal-trimmed white researcher's coat with rift-energy patterns embroidered on the collar. Late 20s.
- **Personality in pose**: One hand adjusting glasses or holding a glowing codex tablet. Eager, leaning slightly forward.
- **Prompt fragment**: `Half-body portrait of a young fantasy scientist called "Lira" for a 2D RPG. Rift Researcher — studies the creatures and dimensional rifts. Bright curious eyes behind round glasses, dark hair in a messy bun with a pencil in it. Wears a white researcher's coat with teal trim and glowing rift-energy patterns on the collar. Holding a glowing tablet, leaning forward with eager expression. Late 20s human female.`

### Maro — Crawler Mechanic

- **Role**: Crawler mentor, jovial engineer
- **Palette**: Amber/brown (#CC8844) primary, oil-stained work clothes, warm skin tone
- **Design**: Stocky build, broad friendly grin. Goggles pushed up on forehead. Short beard, calloused hands. Wears a thick leather apron over amber-brown work clothes, tool belt with wrenches and energy cells. Early 30s.
- **Personality in pose**: One hand holding a wrench or tinkering with a small mechanical part. Relaxed, approachable grin.
- **Prompt fragment**: `Half-body portrait of a stocky fantasy mechanic called "Maro" for a 2D RPG. Crawler Mechanic — maintains and upgrades the exploration vehicle. Broad friendly grin, short beard, goggles pushed up on forehead. Wears a thick leather apron over amber-brown work clothes with a tool belt (wrenches, energy cells). Holding a wrench, relaxed approachable expression. Early 30s human male.`

---

## Status Effect Icons

**Source**: 128x128 PNG, magenta background
**Display size**: 22x22 (battle UI, on glyph panels)
**Output**: `assets/sprites/icons/status/{status_id}.png`

### Shared Icon Style

Simple symbolic icon, centered on canvas. Bold black outline, flat fill using the status color. Must be instantly recognizable at 22x22 — favor simple shapes over detailed illustrations. White detail elements where needed. No text (turn count is overlaid by code).

### Individual Icons

| Status | Color | Symbol | Prompt Description |
|--------|-------|--------|-------------------|
| **burn** | #FF4444 (red) | Flame | A single bold flame shape. Bright red-orange with yellow core, black outline. Simple teardrop flame silhouette. |
| **stun** | #FFDD44 (yellow) | Stars/sparks | Three small stars or spark bursts arranged in a cluster. Bright yellow with white centers, black outline. Classic "dizzy" indicator. |
| **weaken** | #FF8800 (orange) | Broken sword | A sword or blade cracked/broken in the middle. Orange with dark accents, black outline. Conveys reduced attack power. |
| **slow** | #4488FF (blue) | Snail/spiral | A downward-pointing arrow or spiral. Blue with darker blue accents, black outline. Conveys reduced speed. |
| **corrode** | #8B6914 (brown) | Dripping drops | An acid droplet or cracked shield. Dark brown-green with drip marks, black outline. Conveys defense decay. |
| **shield** | #00DDDD (cyan) | Shield | A simple heraldic shield shape. Bright cyan with white highlight, black outline. Conveys damage reduction. |

### Generation Prompt Template

```
A single game UI icon on a solid magenta (#FF00FF) background. 128x128 pixels.
Bold black outlines, flat color fills, no gradients. The icon is a simple
{symbol_description}. Colors: {color_description}. The icon should be
instantly readable at 22x22 pixels — keep the shape bold and simple with
no fine details. No text, no effects, no shadow.
```

---

## Room Type Icons

**Source**: 128x128 PNG, magenta background
**Display size**: 24x24 (dungeon floor map, on room tiles)
**Output**: `assets/sprites/icons/rooms/{room_type}.png`

### Shared Icon Style

Same as status icons — simple symbolic shape, bold outline, flat fill, must read at 24x24. Each icon uses the room type's established color as its primary fill. White or dark accents only.

### Individual Icons

| Room Type | Color | Symbol | Prompt Description |
|-----------|-------|--------|-------------------|
| **start** | #44AA44 (green) | Flag/banner | A small triangular flag or banner on a short pole. Green with white flag detail, black outline. Marks the starting point. |
| **exit** | #4488FF (blue) | Stairs down | Descending stairs or a downward arrow. Blue with lighter blue steps, black outline. Indicates floor exit. |
| **enemy** | #FF4444 (red) | Crossed swords | Two small swords crossed in an X. Red blades with dark hilts, black outline. Indicates a combat encounter. |
| **hazard** | #FF8800 (orange) | Warning triangle | A triangle with an exclamation mark inside. Orange with dark interior mark, black outline. Classic danger warning. |
| **puzzle** | #AA44FF (purple) | Question mark | A bold question mark inside a circle or gem shape. Purple with white question mark, black outline. Indicates a puzzle room. |
| **cache** | #FFD700 (gold) | Treasure chest | A small closed chest or diamond gem. Gold with brown chest body and white highlight, black outline. Indicates loot. |
| **hidden** | #00DDDD (cyan) | Eye/reveal | A stylized eye or magnifying glass. Cyan with white pupil/lens, black outline. Indicates a discoverable secret. |
| **boss** | #FF2222 (bright red) | Skull/crown | A crowned skull or a star with fangs. Bright red with white crown/teeth details, black outline. Indicates the rift boss. |
| **empty** | #888888 (grey) | Circle/dot | A simple hollow circle or small dot. Grey with darker grey outline. Indicates nothing of note. |

### Generation Prompt Template

```
A single game UI icon on a solid magenta (#FF00FF) background. 128x128 pixels.
Bold black outlines, flat color fills, no gradients. The icon is a simple
{symbol_description}. Colors: {color_description}. The icon should be
instantly readable at 24x24 pixels — keep the shape bold and simple with
no fine details. No text, no effects, no shadow.
```

---

## Asset Pipeline Summary

| Asset Type | Source Size | Display Size | Gen Script | Process Script | Output Path |
|-----------|------------|-------------|------------|----------------|-------------|
| Glyph portraits | 512x512 | 16-80px | `generate_sprites.py` | `process_sprites.sh` | `assets/sprites/glyphs/portraits/` |
| Glyph silhouettes | 512x512 | 16-60px | (auto from portrait) | `process_sprites.sh` | `assets/sprites/glyphs/silhouettes/` |
| NPC portraits | 512x512 | 48-80px | `generate_npc_portraits.py` | `process_npc_portraits.sh` | `assets/sprites/npcs/` |
| Status icons | 128x128 | 22x22 | `generate_icons.py --type status` | `process_icons.sh` | `assets/sprites/icons/status/` |
| Room icons | 128x128 | 24x24 | `generate_icons.py --type room` | `process_icons.sh` | `assets/sprites/icons/rooms/` |
