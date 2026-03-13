# Glyphrift Art Direction

All visual assets share a unified style: bold outlines, flat fills, limited palettes, high contrast. Everything must read clearly at its smallest display size.

This is the single source of truth for all art direction — characters, creatures, animations, environments, icons, and UI.

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

## Glyph Animations

### Animation States — Sprite Frames vs. Tween-Only

At typical display sizes (60-64px), not every visual effect benefits from drawn sprite frames. The split below balances visual quality against production cost (18 species x frames).

#### Drawn sprite frames (require sprite sheet art)

| State | Frames | FPS | Loop | What the artist draws |
|-------|--------|-----|------|-----------------------|
| **Idle** | 4 | 4 | Yes | Subtle species-specific motion: breathing, bobbing, element particles cycling. Conveys the creature is alive while waiting. Even at 60px, a 2-4 frame idle loop is the difference between a static image and a living creature. |
| **Attack** | 4 | 8 | No | Species-specific wind-up → strike → follow-through → settle. This is the most personality-defining animation. Each species should have a visually distinct attack that reflects its signature technique and body shape. |
| **Hurt** | 2 | 6 | No | Flinch/recoil pose. The drawn pose is combined with tween effects (white flash + screen shake) for the full hit reaction. Frame 1: impact flinch. Frame 2: recovery (can be similar to idle frame 0). |
| **KO** | 3 | 4 | No (hold last) | Collapse or dissolution specific to the creature's anatomy and element. Frame 1: stagger. Frame 2: falling/dissolving. Frame 3: final down pose (held, then tween fades out). |

#### Tween-only (no sprite art needed)

| Effect | Tween Method | Why no sprite frames |
|--------|-------------|---------------------|
| **Guard** | Scale pulse (1.0→1.05→1.0) + cyan shield color overlay | Guard is a defensive stance, not a dramatic motion. A subtle pulse with the existing shield border system reads clearly. A drawn brace pose would be a 5th animation row for minimal payoff. |
| **Status applied** | Target flashes status color + icon pops in with scale bounce | The status icon system already communicates what happened. Creature pose doesn't need to change. |
| **Active turn** | Gentle scale oscillation (1.0↔1.03, ~1s period) | Too subtle for drawn frames at display size. A slow tween "breathing" pulse on the current idle frame works. |
| **Capture** | Horizontal shake (3 wobbles) + squash/stretch + flash on success or dash-off on failure | The capture animation is about the containment, not the creature's pose. Tween motion on the static portrait reads perfectly. |
| **Victory** | Bounce (translate Y -8px and back, 2 bounces) | Positional celebration. The idle animation continues playing during the bounce. |
| **Defeat** | Scale Y to 0.8, modulate to grey, translate Y +4px | Post-KO team mood. Subtle droop. Already KO'd at this point. |
| **Fusion dissolve** | Parents: scale down + modulate to white + fade out. Result: scale up from 0 + modulate from white to normal | See Fusion Discovery Animation section for the full sequence. All tween-based using existing portrait and silhouette assets. |

#### Why 4 rows is right

The original sprite sheet spec (4 rows: Idle, Attack, Hurt, KO) is correct for this game. Adding Guard or Status poses would mean 5-6 rows per species x 18 species = significant extra art production with diminishing returns at 60px display size. The four states cover the moments that matter most for creature personality. Everything else layers tweens on top.

### Perspective and View

**Decision: Single 3/4 view, same angle as portraits. Mirror for enemies.**

- All sprites face **right** in their canonical orientation (matching the existing 512x512 portraits)
- **Player's team** displays facing right (as-is)
- **Enemy team** displays facing left (horizontal flip in code: `flip_h = true`)
- No back view, no turnaround, no rotation — all animation happens from this one angle
- This is the standard approach for the genre (Pokemon, Final Fantasy, Shin Megami Tensei, most 2D monster RPGs)

**Why not top-down for the dungeon map?** The battle sprites and dungeon map sprites can use different views. The map representation of creatures is too small (16-24px) for animation frames anyway — they'll use the static portrait, possibly as a silhouette. Only the crawler needs a dedicated map-view representation (see Crawler Visual Design section).

### Per-Species Animation Direction

Each species has animation briefs describing what their idle/attack/hurt/KO look like, informed by their creature design, signature techniques, and element. These briefs live in **`data/glyph_animations.json`** so the sprite sheet generation pipeline can consume them programmatically.

The briefs are structured as prompt-ready descriptions. The generation pipeline reads the species' animation data + the shared style block to produce per-species sprite sheet prompts (same approach as the portrait generation pipeline in `glyph-sprite-prompts.md`).

#### Animation brief format (per species in `data/glyph_animations.json`)

```json
{
  "species_id": "zapplet",
  "name": "Zapplet",
  "tier": 1,
  "affinity": "electric",
  "body_type": "small quadruped",
  "signature_technique": "jolt_rush",
  "idle": "Ears twitch in alternation. Tiny sparks pop between ear tips...",
  "attack": "Crouches low (wind-up), then lunges forward with ears flattened...",
  "hurt": "Flinches backward with ears pressed flat, sparks scatter...",
  "ko": "Staggers sideways, sparks sputter and die. Slumps onto side..."
}
```

#### Design principles for animation briefs

1. **Signature technique drives the attack animation.** Each species' most iconic technique (usually their first fixed mastery objective technique) defines the attack motion. Zapplet lunges because of Jolt Rush. Stonepaw swipes because of Rock Toss. Riftmaw opens its jaws because of Null Beam.

2. **Element shows in idle.** Electric creatures spark and crackle. Ground creatures have shifting stone/root particles. Water creatures ripple, phase-shift, or drip. Neutral creatures have star twinkles and constellation-line flickers.

3. **Tier affects intensity.** T1 animations are small, quick, cute. T2 animations are more deliberate and powerful. T3 animations have weight and drama. T4 animations have an otherworldly, reality-bending quality — the creature doesn't just attack, it commands its element.

4. **Anatomy dictates KO.** Quadrupeds collapse sideways. Floating creatures drift down and flicker out. Rocky creatures crack and crumble. Ethereal creatures phase out and dissolve.

5. **Readability at 60px.** Every animation must read as distinct from the idle state even at the primary display size. Favor large silhouette changes (lunging, crouching, spreading limbs) over subtle internal movements (facial expressions, small particle effects).

---

## Fusion Discovery Animation

The fusion discovery moment is the game's peak reward experience — the player has mastered two creatures and combined them to discover something new. The animation should feel special without requiring custom sprite art beyond what already exists (portraits + silhouettes).

### Sequence (all tween-based, ~3.5 seconds total)

| Step | Duration | Visual | Audio cue (future) |
|------|----------|--------|---------------------|
| 1. **Parents converge** | 0.5s | Parent A portrait slides in from left, Parent B from right. Both settle at center, overlapping slightly. Affinity-colored glow borders pulse. | Low hum building |
| 2. **Energy merge** | 0.4s | Both parents scale down to 0.7x while modulating toward white. Spinning ring of particles (alternating parent affinity colors) appears around them. | Rising tone |
| 3. **Flash** | 0.15s | Screen flashes white (full-screen ColorRect at opacity 0→1→0). Parents disappear (scale to 0). | Sharp crack |
| 4. **Silhouette reveal** | 0.6s | Result species silhouette (from existing `silhouettes/` assets) fades in at center, at 128x128. Gentle scale bounce (0.8→1.1→1.0). | Mysterious chord |
| 5. **Color fill** | 0.5s | Silhouette cross-fades to full portrait. A radial wipe or simple alpha blend. Affinity-colored ring pulse radiates outward from the portrait. | Triumphant swell |
| 6. **Name reveal** | 0.4s | Species name typewriter-reveals below the portrait in gold text. If first-time discovery, a "NEW DISCOVERY" banner scales in above with a gold shimmer. | Chime |
| 7. **Stats fade in** | 0.5s | Base stats, tier, and affinity label fade in below. Inherited techniques listed. | — |
| 8. **Hold for input** | — | "Continue" button fades in. Portrait plays idle animation if sprite sheet exists, otherwise static. | — |

### Implementation notes

- All achievable with Godot Tween + existing assets (portraits, silhouettes)
- No new sprite art required — this is purely choreographed tween animation
- `instant_mode`: skip directly to step 7 (show result immediately)
- The spinning particle ring in step 2 can be a simple rotating `Polygon2D` ring or programmatic draw
- Background dims to 70% opacity during the sequence (same overlay as popups)
- The sequence replaces the current instant-reveal in `fusion_chamber.gd`

---

## Crawler Visual Design

The Crawler is the player's modular armored vehicle — part rover, part APC, built to survive dimensional rifts. It should look rugged, functional, and distinctly mechanical against the organic/elemental creature aesthetic.

### Design language

- **Shape**: Compact and squat. Wider than tall. The silhouette should read as "armored vehicle" instantly at 32px.
- **Proportions**: Chunky treaded wheels or hover-pads on a low-slung chassis. A reinforced cab section with a glowing viewport. Utility mounts on the top and sides.
- **Personality**: Utilitarian, reliable, not flashy. This is a working machine, not a sports car. It should look like something Maro built and maintains — practical engineering with visible bolts, panels, and access hatches.
- **No organic elements**: Pure mechanical/industrial. This contrasts with the Glyphs' creature designs and makes the crawler visually distinct in every context.

### Art specifications

| Property | Value |
|----------|-------|
| **Source resolution** | 512x512 PNG (same as all other assets) |
| **Style** | Same flat art style — bold black outlines (2-4px), flat color fills, limited palette, no gradients |
| **View** | 3/4 view facing right (consistent with glyph portraits and game's visual language) |
| **Background** | Magenta (#FF00FF) for generation, transparent for game use |
| **Display sizes** | 128x128 (Crawler Bay center panel), 28-32px (dungeon map token) |
| **Output path** | `assets/sprites/crawler/{chassis_id}.png` |

### Chassis variants

Each chassis is a distinct full sprite (not a paper-doll overlay). Four sprites total. They share the same basic vehicle proportions and viewport placement but differ in silhouette, plating, and attachments.

#### Standard

- **Color palette**: Steel grey (#888888) primary, dark charcoal (#444444) panels, cyan (#00DDDD) viewport glow
- **Shape**: Base vehicle design. Compact, balanced proportions. Six small wheels visible in the 3/4 view (3 per side). Flat-topped with a small antenna. Smooth hull panels with minimal detail.
- **Key features**: Clean lines, no extras. This is the "blank" chassis — recognizable but unspecialized.
- **Feeling**: Reliable, new, factory-standard.

#### Ironclad

- **Color palette**: Blue-steel (#4488FF) armor plates over dark grey (#333333) base hull, cyan (#00DDDD) viewport (narrower slit)
- **Shape**: Same base proportions but visibly heavier. Additional bolted armor plates on the hull sides and top. Reinforced front bumper/ram plate. Slightly lower stance (suspension compressed under weight). Viewport is a narrow armored slit instead of a full window.
- **Key features**: Visible rivets on armor plates. Thicker wheel guards. A heavy front plate. The silhouette is blockier and more angular than Standard.
- **Feeling**: Tank-like, fortified, imposing. Clearly built to take hits.
- **Prompt note**: "Same vehicle as standard but with welded-on armor plates, bolt marks, narrow viewport slit, reinforced bumper. Looks like it was retrofitted for a warzone."

#### Scout

- **Color palette**: Green (#44DD88) accent panels over light grey (#AAAAAA) base hull, bright cyan (#00DDDD) viewport (wider lens)
- **Shape**: Sleeker profile. Less armor plating visible — thinner panels, more exposed frame. A rotating radar dish on the roof. Antenna array on the back. Wider, more prominent sensor viewport (looks like a large lens). Slightly raised suspension (higher ground clearance).
- **Key features**: Radar dish is the defining silhouette element. Signal-wave arcs drawn emanating from the dish (1-2 flat colored arcs). Lighter frame. The overall shape is more horizontal/streamlined than Standard.
- **Feeling**: Fast, perceptive, lightly armored. Built to see everything and get out quickly.
- **Prompt note**: "Same base vehicle but streamlined, with a rotating radar dish on top, antenna array, wide sensor lens viewport, lighter frame. Built for speed and detection."

#### Hauler

- **Color palette**: Amber (#CC8844) cargo sections over warm grey (#777766) base hull, cyan (#00DDDD) viewport
- **Shape**: Extended rear section. The front cab is similar to Standard, but the vehicle body stretches back with a visible cargo bay. Storage racks or crate tie-downs on the sides and top. Wider wheelbase to support the extra weight. Slightly rear-heavy stance.
- **Key features**: Cargo containers/racks strapped to the sides are the defining element. A wider body overall. Maybe a small crane or loading arm folded on top. The extra bulk should be clearly "cargo" not "armor" — open racks and crates, not solid plates.
- **Feeling**: Pack mule, overloaded but capable. Maro's favorite.
- **Prompt note**: "Same base vehicle but with an extended cargo bay, crate racks on sides and top, wider wheelbase. Looks like a supply truck adapted for rift exploration."

### Equipment visualization

**In Crawler Bay (128px display):** Equipment icons (already designed at 128x128, displayed at 36x36) are shown in their respective slots on the Crawler Bay UI panel, adjacent to the crawler sprite. Equipment is NOT drawn onto the crawler sprite itself — this avoids needing 4 chassis x 8 equipment = 32+ composite renders. The crawler sprite shows the chassis; the equipment is shown via the icon slots.

**On dungeon map (28-32px display):** Only the chassis variant is shown. Equipment is invisible at this scale — the chassis silhouette and accent color are enough to identify the vehicle. The chassis color accent (grey/blue/green/amber) matches the chassis icon color, reinforcing recognition.

### Crawler Bay layout reference

```
┌──────────────────────────────────────────────┐
│  COMPUTER SLOTS          CRAWLER          ACCESSORY SLOTS  │
│  ┌──────────┐      ┌──────────────┐      ┌──────────┐     │
│  │ [icon 1] │      │              │      │ [icon 1] │     │
│  │ [icon 2] │      │   128x128    │      │ [icon 2] │     │
│  └──────────┘      │   crawler    │      └──────────┘     │
│                    │   sprite     │                        │
│                    └──────────────┘                        │
│  CHASSIS: [Standard ▼]     STATS: Hull 100 Energy 50      │
└──────────────────────────────────────────────┘
```

### Generation prompts

**Shared style block** (prepend to all crawler prompts):
```
A compact armored exploration vehicle for a 2D RPG game. 3/4 view facing right,
on a solid magenta (#FF00FF) background. 512x512 pixels. Clean vector/cartoon
style with bold black outlines (2-4px), flat color fills, no gradients or soft
shading. The vehicle should be squat and wide — an armored rover/APC hybrid
with treaded wheels. It has a reinforced cab with a glowing cyan viewport,
utility mounts, and visible mechanical details (bolts, hatches, panels). No
environment, no shadow, no ground plane. The vehicle should fill ~80% of the
canvas.
```

Append the chassis-specific prompt notes (above) for each variant.

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

## Crawler Chassis Icons

**Source**: 128x128 PNG, magenta background
**Display size**: 36x36 (Crawler Bay cards)
**Output**: `assets/sprites/icons/chassis/{chassis_id}.png`

### Shared Icon Style

Same as status/room icons — simple symbolic shape, bold black outline, flat fill, must read at 36x36. Each chassis icon should convey the chassis's identity at a glance.

### Individual Icons

| Chassis | Color | Symbol | Prompt Description |
|---------|-------|--------|-------------------|
| **standard** | #888888 (grey) | Wheel/gear | A simple gear or wheel shape. Neutral grey with darker grey accents, black outline. Default all-purpose vehicle. |
| **ironclad** | #4488FF (blue) | Heavy shield | A thick reinforced shield or armor plate. Blue with white rivet details, black outline. Conveys heavy protection and durability. |
| **scout** | #44DD88 (green) | Radar dish | A small radar dish or antenna with signal waves. Green with lighter green accents, black outline. Conveys scanning and speed. |
| **hauler** | #CC8844 (amber) | Cargo crate | A small cargo container or crate with a plus sign. Amber-brown with gold trim, black outline. Conveys extra carrying capacity. |

### Generation Prompt Template

```
A single game UI icon on a solid magenta (#FF00FF) background. 128x128 pixels.
Bold black outlines, flat color fills, no gradients. The icon is a simple
{symbol_description}. Colors: {color_description}. The icon should be
instantly readable at 36x36 pixels — keep the shape bold and simple with
no fine details. No text, no effects, no shadow.
```

---

## Crawler Equipment Icons

**Source**: 128x128 PNG, magenta background
**Display size**: 36x36 (Crawler Bay cards)
**Output**: `assets/sprites/icons/equipment/{equipment_id}.png`

### Shared Icon Style

Same as other icons — simple symbolic shape, bold black outline, flat fill, must read at 36x36. Computer equipment uses cooler tones (cyan, blue, yellow). Accessory equipment uses warmer tones (amber, brown, gold).

### Computer Slot Icons

| Equipment | Color | Symbol | Prompt Description |
|-----------|-------|--------|-------------------|
| **scan_amplifier** | #00DDDD (cyan) | Radar/eye | A radar dish emitting signal arcs, or a glowing eye lens. Cyan with white highlight, black outline. Reveals all rooms on scan. |
| **energy_recycler** | #44DD44 (green) | Circular arrows | Two arrows forming a recycling circle around an energy bolt. Green with lighter green accents, black outline. Regenerates energy. |
| **affinity_filter** | #AA44FF (purple) | Prism | A triangular prism splitting a beam of light into colors. Purple body with colored light rays (red, blue, yellow), black outline. Boosts capture chance. |
| **capacitor_cell** | #FFDD44 (yellow) | Battery | A battery or power cell with a lightning bolt symbol. Yellow with white charge indicator, black outline. Increases max energy. |

### Accessory Slot Icons

| Equipment | Color | Symbol | Prompt Description |
|-----------|-------|--------|-------------------|
| **hull_plating** | #4488FF (blue) | Armor plate | A thick rectangular armor plate with bolt marks. Blue with silver rivet details, black outline. Extra hull HP. |
| **cargo_rack** | #CC8844 (amber) | Shelf/rack | A small shelving unit or rack with items on it. Amber-brown with gold shelf brackets, black outline. Extra bench slot. |
| **repair_drone** | #FF8800 (orange) | Drone/wrench | A small hovering drone with a wrench or repair arm. Orange with white propeller accents, black outline. Auto-heals hull. |
| **trophy_mount** | #FFD700 (gold) | Trophy/medal | A star medal or trophy cup on a small mount. Gold with white highlight, black outline. Boosts capture chance. |

### Generation Prompt Template

```
A single game UI icon on a solid magenta (#FF00FF) background. 128x128 pixels.
Bold black outlines, flat color fills, no gradients. The icon is a simple
{symbol_description}. Colors: {color_description}. The icon should be
instantly readable at 36x36 pixels — keep the shape bold and simple with
no fine details. No text, no effects, no shadow.
```

---

## Background Art

Backgrounds support the game's flat art style without competing with foreground UI and character art. They establish mood and location through color, shape, and layering.

### Shared background principles

- **Flat color layers** — backgrounds are built from layered flat-colored shapes at varying opacities, creating depth without gradients. This is consistent with the game's "no gradients" art rule while allowing environmental atmosphere.
- **No bold outlines on background elements** — outlines are reserved for foreground/interactive elements (characters, UI). Background shapes use color contrast and edge sharpness instead. This creates natural visual hierarchy.
- **Muted compared to foreground** — background colors are desaturated and darker than character/UI colors. The player's eye should go to the creatures and interface first.
- **Geometric over organic** — rift environments favor crystalline, angular, fractured shapes. The Bastion favors industrial, mechanical, paneled shapes. Neither uses naturalistic forms (trees, clouds, etc.).
- **Resolution**: 1920x1080 source PNG. Scaled to viewport by Godot.
- **Output path**: `assets/sprites/backgrounds/{context}/{variant}.png`

### Battle backgrounds

The battle takes place inside a dimensional rift — an unstable tear in reality. The background should feel alien, energetic, and slightly dangerous without distracting from the combat UI.

**Structure (3 layers, back to front):**
1. **Deep void** — near-black base color. The "space" of the rift dimension.
2. **Crystal formations** — geometric shard shapes (hexagons, fractured planes, crystalline spires) at ~20-30% opacity. These float in the void at varying depths, creating spatial feel. Colored in the rift's affinity palette.
3. **Ground plane** — a subtle horizontal band at the bottom ~30% of the frame. Geometric tile/grid pattern in slightly lighter dark tones. This is where the creatures stand. Faint, not prominent.

**Color palettes by rift tier:**

| Rift Tier | Void Base | Crystal Color | Ground Tint | Mood |
|-----------|-----------|---------------|-------------|------|
| **Minor** | Deep navy (#12121e) | Dim teal (#1a4040) + grey (#2a2a30) | Dark blue-grey (#181822) | Quiet, cautious. First rifts feel like exploring a cave. |
| **Standard** | Dark indigo (#1a1430) | Medium purple (#3a2855) + warm amber (#3a3020) | Dark purple-grey (#1c1826) | More vibrant. Stakes are rising. |
| **Major** | Dark crimson (#221418) | Deep red (#3a1a22) + bright accents (#4a2030) | Dark red-grey (#1e1618) | Intense, threatening. Boss territory. |
| **Apex** | Near-black (#0a0a0e) | Prismatic — all three affinity colors at low opacity, shifting | Dark void (#101014) with faint white noise texture | Otherworldly, final. Reality is fraying. |

**Variants**: 1 background per rift tier (4 total for battle). Future: 2-3 per tier for variety.

### Dungeon map background

The dungeon map is a tactical/navigator view. The background should feel like looking at a scanner display — dark, functional, slightly technical.

- **Color**: Very dark charcoal (#0c0c12) base
- **Pattern**: Subtle hexagonal or square grid in slightly lighter tone (#161620), 30-40px spacing. The grid suggests the rift's spatial structure without dominating.
- **Vignette**: Edges darken to near-black (#060608), drawing focus to the center where the map lives.
- **Optional particle layer**: Very sparse, tiny dots (~2px) drifting slowly — dimensional particles floating in the void. Subtle enough to be subliminal.

**1 background total.** The dungeon map doesn't need tier variants — room nodes and line connections provide all the visual variety.

### Bastion backgrounds

The Bastion is the player's safe haven — a warm, mechanical, lived-in space. Backgrounds should feel sheltered and functional, contrasting with the cold hostility of the rifts.

**Shared Bastion style:**
- Warm mid-tones (browns, greys, amber) instead of cool darks
- Industrial/workshop details: wall panels, pipe runs, riveted seams, equipment racks
- These details are simplified flat shapes (consistent with art style), not realistic — think "the idea of a workshop" not a photorealistic garage
- Warm amber (#CC8844 at low opacity) accent lighting from fixtures
- Cyan (#00DDDD at low opacity) glow from screens/displays

**Sub-screen variants:**

| Screen | Background Concept | Key Visual Elements | Palette |
|--------|--------------------|---------------------|---------|
| **Hub** | Central command room | Wide room with console banks on sides, overhead pipes, status displays with cyan glow. Warm ambient lighting. A large viewport or screen at the back showing a dim rift exterior. | Warm grey (#2a2420) walls, amber accents, cyan screen glows |
| **Barracks** | Glyph containment wing | Rows of containment pod outlines along the walls (hexagonal or cylindrical shapes). Soft affinity-colored glows from pods. More structured, clinical feel than the hub. | Cool grey (#222228) walls, soft multi-color pod glows |
| **Fusion Chamber** | Energy lab | Central containment ring outline at the back (large circle or hexagon). Energy conduit lines running along walls and floor toward center. Brighter than other rooms — the fusion process emits light. | Dark purple (#1e1628) base, bright white-purple (#6644aa at 20%) conduit glows |
| **Rift Gate** | Portal chamber | The back wall IS the rift portal — a large vertical tear/opening with dimensional energy. Darker room, dramatic backlighting from the portal. The portal shimmers with the colors of the selected rift. | Dark (#161618) room, rift-colored portal glow |
| **Codex** | Archive/library | Data screens and display panels along walls. Organized, clean. Shelving outlines with data crystal shapes. More orderly than other bastion rooms. | Dark blue-grey (#1a1e24) walls, cyan data-screen glows |
| **Crawler Bay** | Vehicle hangar | Open floor space. Tool racks and equipment shelves on side walls. Overhead gantry/lift shapes. Grease stains on the floor (darker patches). This is Maro's domain. | Warm brown (#2a2218) walls, amber tool-rack highlights, oil-dark (#1a1a14) floor |

**6 backgrounds total for Bastion.** Each is a single 1920x1080 image. Details are flat shapes, not drawn illustrations — wall panel rectangles, pipe line segments, circular pod shapes, etc.

### Popup/modal overlay

Not a background asset — handled in code:
- Semi-transparent black overlay (#000000 at 65% opacity) behind all popup panels
- Popup panels use existing `PanelContainer` `StyleBoxFlat` theming
- No background art needed for popups

---

## Title Screen

The title screen establishes the game's identity — dimensional rifts, creature capture, and expedition. It should be atmospheric and evocative without being complex.

### Composition

```
┌─────────────────────────────────────────────────┐
│                                                 │
│              G L Y P H R I F T                  │  Title: upper third
│           ─ ─ ─ ─ ─ ─ ─ ─ ─ ─                  │  Subtitle line
│                                                 │
│          ╱                    ╲                  │
│         ╱    RIFT PORTAL       ╲                 │  Center: vertical rift tear
│        │   (prismatic glow)     │                │  with light spilling through
│         ╲                      ╱                 │
│          ╲                    ╱                  │
│                                                 │
│    ⚡ sparks         🪨 crystals     💧 ripples  │  Affinity accents frame the rift
│                                                 │
│              ▄▄▄▄▄▄▄▄▄▄▄▄▄                     │  Crawler silhouette
│              █  CRAWLER   █                     │  approaching from bottom
│              ▀▀▀▀▀▀▀▀▀▀▀▀▀                     │
│                                                 │
│              ► START                            │  Menu: lower third
│                CONTINUE                         │
│                OPTIONS                          │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Visual elements

**Background void:**
- Near-black (#0a0a0e) base, similar to Apex rift battle background
- Very subtle distant crystal formations in deep blues and purples at extreme low opacity (~10%)
- This is the deepest point of the dimensional void — the source of all rifts

**Rift portal (center focal point):**
- A vertical tear/crack in space, roughly centered in the frame
- Jagged edges (like cracked glass or a lightning bolt silhouette)
- Light spills through the crack — prismatic white with hints of all three affinity colors at the edges
- The tear has depth — the interior glows brighter toward the center
- Rendered as layered flat shapes: dark crack outline → bright interior fill → outer glow shapes at low opacity
- This is the single most important visual element — the game is about entering these rifts

**Affinity accents (framing the rift):**
- **Electric** (left side): Angular spark/lightning shapes in gold (#FFD700) at ~15% opacity. Crackling energy.
- **Ground** (right side): Crystalline shard shapes in earthy brown (#C2855A) at ~15% opacity. Stable, heavy.
- **Water** (bottom corners): Fluid/ripple arc shapes in teal (#00ACC1) at ~15% opacity. Flowing, unstable.
- These are subtle environmental accents, not prominent illustrations. They frame the rift and hint at the three-element system.

**Crawler silhouette (lower center):**
- Small (~64-80px wide in the composition) dark silhouette of the Standard chassis crawler
- Positioned below the rift, facing toward it — approaching the unknown
- Cyan viewport glow is the only color detail on the crawler (a tiny dot of light)
- Emphasizes scale: the rift is vast, the crawler is small but determined

**Title text:**
- "GLYPHRIFT" in a bold, geometric sans-serif typeface
- Gold (#FFD700) primary fill with a 2px darker gold (#B8960F) outline
- Letter edges are slightly fractured/fragmented — small notches cut into the letters as if reality is cracking through them (echo of the rift motif)
- Positioned in the upper third, horizontally centered
- Optional subtitle below in smaller white (#AAAAAA) text: "A Rift Warden's Chronicle" or similar (TBD)

**Menu items:**
- Lower third of the screen
- START / CONTINUE / OPTIONS
- Default: white (#BBBBBB) text, clean sans-serif
- Selected/hover: gold (#FFD700) text with a subtle ">" indicator
- Muted and minimal — the art does the talking

### Color palette summary

| Element | Color | Opacity |
|---------|-------|---------|
| Void background | #0a0a0e | 100% |
| Distant crystals | #1a1a2e, #161630 | 8-12% |
| Rift crack outline | #222230 | 100% |
| Rift interior glow | #FFFFFF, #EEEEFF | 60-90% (brighter at center) |
| Electric accents | #FFD700 | 12-18% |
| Ground accents | #C2855A | 12-18% |
| Water accents | #00ACC1 | 12-18% |
| Crawler silhouette | #0a0a0e (same as void, defined by viewport glow) | 100% |
| Crawler viewport | #00DDDD | 100% (small dot) |
| Title text | #FFD700 fill, #B8960F outline | 100% |
| Menu text | #BBBBBB default, #FFD700 selected | 100% |

### Art specs

| Property | Value |
|----------|-------|
| **Resolution** | 1920x1080 PNG |
| **Layers** | Can be delivered as a single flat image, or as 4 separate layers (void, crystals+accents, rift portal, crawler silhouette) for optional parallax/animation |
| **Style** | Flat shapes with layered opacity — consistent with game art style but more atmospheric than character art. No bold outlines on background elements (reserved for rift crack edges and crawler silhouette). |
| **Animation (optional)** | Rift portal: gentle inner-glow pulse (tween opacity 0.6↔0.9, ~3s period). Crystal accents: very slow drift (~0.5px/s). Crawler viewport: subtle cyan blink every ~4s. All tween-based, all optional — the static image must work on its own. |
| **Output path** | `assets/sprites/backgrounds/title_screen.png` (or layered: `title_bg_void.png`, `title_bg_rift.png`, etc.) |

### Mood

Mysterious, vast, beckoning. The rift is dangerous but fascinating — a crack in reality that calls to explorers. The crawler is small against the void, but its glowing viewport says it's ready. The gold title promises discovery. This is an adventure game, not a horror game — the tone is wonder-tinged-with-danger, not dread.

---

## Asset Pipeline Summary

| Asset Type | Source Size | Display Size | Gen Script | Process Script | Output Path |
|-----------|------------|-------------|------------|----------------|-------------|
| Glyph portraits | 512x512 | 16-80px | `generate_sprites.py` | `process_sprites.sh` | `assets/sprites/glyphs/portraits/` |
| Glyph silhouettes | 512x512 | 16-60px | (auto from portrait) | `process_sprites.sh` | `assets/sprites/glyphs/silhouettes/` |
| Glyph sprite sheets | 512x512 | 60-128px | (future — reads `data/glyph_animations.json`) | (future) | `assets/sprites/glyphs/sheets/` |
| NPC portraits | 512x512 | 48-80px | `generate_npc_portraits.py` | `process_npc_portraits.sh` | `assets/sprites/npcs/` |
| Crawler chassis | 512x512 | 28-128px | (future — see Crawler Visual Design) | (future) | `assets/sprites/crawler/` |
| Battle backgrounds | 1920x1080 | viewport | (future — see Background Art) | (future) | `assets/sprites/backgrounds/battle/` |
| Bastion backgrounds | 1920x1080 | viewport | (future — see Background Art) | (future) | `assets/sprites/backgrounds/bastion/` |
| Dungeon background | 1920x1080 | viewport | (future — see Background Art) | (future) | `assets/sprites/backgrounds/dungeon/` |
| Title screen | 1920x1080 | viewport | (future — see Title Screen) | (future) | `assets/sprites/backgrounds/title/` |
| Status icons | 128x128 | 22x22 | `generate_icons.py --type status` | `process_icons.sh` | `assets/sprites/icons/status/` |
| Room icons | 128x128 | 24x24 | `generate_icons.py --type room` | `process_icons.sh` | `assets/sprites/icons/rooms/` |
| Chassis icons | 128x128 | 36x36 | `generate_icons.py --type chassis` | `process_icons.sh` | `assets/sprites/icons/chassis/` |
| Equipment icons | 128x128 | 36x36 | `generate_icons.py --type equipment` | `process_icons.sh` | `assets/sprites/icons/equipment/` |
