# Adding a New Glyph — End-to-End Guide

This documents every step for adding a new glyph species to Glyphrift, from initial concept to fully integrated game asset.

---

## 1. Design the Species

Decide on:
- **Name** and **species_id** (lowercase, single word, e.g. `ironbark`)
- **Tier** (1–4) and **affinity** (`electric`, `ground`, `water`, or `neutral`)
- **GP cost** (T1=2, T2=3, T3=4/6, T4=8 — see GDD 6.2)
- **Base stats** (hp, atk, def, spd, res — see GDD 8.4 for tier stat budgets)
- **Techniques** (2–4 from `data/techniques.json`, or create new ones)
- **Mastery objectives** (2–4 fixed objectives — see existing species for patterns)
- **Fusion recipe** if applicable (which two parents fuse into this species?)

---

## 2. Update Data Files

### A. `data/glyphs.json` — Species definition (REQUIRED)

Add a new entry to the array:

```json
{
  "id": "newspecies",
  "name": "New Species",
  "tier": 1,
  "affinity": "electric",
  "gp_cost": 2,
  "base_hp": 12,
  "base_atk": 10,
  "base_def": 8,
  "base_spd": 14,
  "base_res": 9,
  "technique_ids": ["spark_zap", "volt_charge"],
  "fixed_mastery_objectives": [
    {
      "type": "use_technique_n_times",
      "params": {"technique_id": "spark_zap", "count": 8},
      "description": "Use Spark Zap 8 times"
    }
  ]
}
```

### B. `data/codex_entries.json` — Lore entry (REQUIRED)

```json
"newspecies": {
  "hint": "One-line hint shown before discovery.",
  "lore": "Full backstory shown after discovery. Two to four sentences."
}
```

### C. `data/fusion_table.json` — Fusion recipe (if fusable)

Add **both orderings** for O(1) lookup:

```json
{"parent_a": "parent1", "parent_b": "parent2", "result": "newspecies"},
{"parent_a": "parent2", "parent_b": "parent1", "result": "newspecies"}
```

### D. `data/rift_templates.json` — Wild encounters (REQUIRED)

Add the species_id to `wild_glyph_pool` in appropriate rift templates:
- T1 species → tutorial and minor rifts
- T2+ species → standard, major, and apex rifts

### E. `data/bosses.json` — Boss entry (only if it's a rift boss)

```json
{
  "rift_id": "minor_05",
  "species_id": "newspecies",
  "mastery_stars": 2,
  "phase1_technique_ids": ["tech_a", "tech_b"],
  "phase2_technique_ids": ["tech_c", "tech_d"]
}
```

### F. `data/techniques.json` — New techniques (only if needed)

If the species uses techniques not already in the library, add them here.

---

## 3. Update Code References

### A. `ui/dungeon/puzzle_echo.gd` — Echo encounter text (REQUIRED)

Add to the `ECHO_LORE` dictionary (~line 12):

```gdscript
"newspecies": {
    "encounter": "Flavor text when encountering this echo...",
    "fragment": "Memory Fragment: \"Lore snippet for discovery\""
},
```

### B. `scripts/process_sprites.sh` — VALID_IDS array (REQUIRED for sprite processing)

Add the species_id to the `VALID_IDS` array (~line 24):

```bash
VALID_IDS=(
  zapplet sparkfin stonepaw mossling driftwisp glitchkit
  vesper equinox newspecies
  ...
)
```

### C. `core/progression/roster_state.gd` — Starter list (only if it's a starter)

### D. `core/game_state.gd` — Initial codex discovery (only if it's a starter)

---

## 4. Create Sprite Art

### A. Write a prompt in `docs/glyph-sprite-prompts.md`

Follow the existing format — each species gets a `### N. SpeciesName` section with a blockquoted prompt. The prompt should include:

1. **Identity**: name, tier, affinity, role, signature techniques
2. **Personality & shape**: body form, distinctive features, expression
3. **Style rules**: bold outlines, flat fills, limited palette, no gradients, reads at 64x64
4. **Framing**: 512x512, 3/4 view, idle pose, 80% canvas fill, magenta (#FF00FF) background

Use the shared style block in the file as a reference.

### B. Generate the raw image

```bash
python3 scripts/generate_sprites.py newspecies
# or generate multiple candidates to pick from:
python3 scripts/generate_sprites.py newspecies --candidates 3
```

This calls Gemini and saves the raw PNG to `raw/newspecies.png`. Requires `GEMINI_API_KEY` in `.env` and `pip3 install google-genai`.

### C. Process into game-ready assets

```bash
./scripts/process_sprites.sh raw/
```

This pipeline:
1. **Detects background color** (magenta or white) from corner pixel
2. **Removes background** via edge flood-fill from all 4 corners
3. **Trims and resizes** to 512x512, centered at 80% fill
4. **AI cleanup** — finds interior white/magenta pockets via ImageMagick connected components, classifies each as "pocket" vs "feature" using Gemini vision, flood-fills only the pockets
5. **Generates silhouette** — solid dark shape preserving alpha

Output:
- `assets/sprites/glyphs/portraits/newspecies.png` (512x512, transparent background)
- `assets/sprites/glyphs/silhouettes/newspecies_silhouette.png` (dark shape)

### D. Review the result

Open the portrait PNG and verify:
- Background is fully transparent (no trapped white/magenta pockets)
- Intentional white features (eyes, teeth, highlights) are preserved
- Creature is centered and fills ~80% of the canvas
- Silhouette is a clean dark shape

If pockets remain, re-run cleanup on just that sprite:

```bash
python3 scripts/cleanup_sprites.py assets/sprites/glyphs/portraits/newspecies.png
```

If the AI is too aggressive, use `--dry-run` to preview classifications before applying.

### E. Environment variables

| Variable | Purpose |
|----------|---------|
| `GEMINI_API_KEY` | Required in `.env` for generation and AI cleanup |
| `SKIP_AI_CLEANUP=1` | Forces old heuristic cleanup instead of AI |
| `GODOT` | Path to Godot binary (default: `godot` in PATH) |

---

## 5. Run Tests

```bash
~/bin/godot --headless --script res://tests/test_data_loader.gd
```

This validates that the new species loads correctly from JSON, has valid technique references, and passes all data integrity checks.

---

## 6. Verify In-Game

Run the game and check:
- Species appears in the Codex browser
- Sprite renders correctly in battle (64x64 portrait), barracks (card), and squad overlay
- Silhouette shows for undiscovered species in the Codex
- Wild encounters spawn correctly in the assigned rifts
- Fusion works if a recipe was added
- Echo puzzle has flavor text

---

## Quick Checklist

| Step | File | Required? |
|------|------|-----------|
| Species definition | `data/glyphs.json` | Always |
| Codex lore | `data/codex_entries.json` | Always |
| Fusion recipe | `data/fusion_table.json` | If fusable |
| Wild pool | `data/rift_templates.json` | Always |
| Boss entry | `data/bosses.json` | If rift boss |
| New techniques | `data/techniques.json` | If needed |
| Echo lore | `ui/dungeon/puzzle_echo.gd` | Always |
| Valid IDs | `scripts/process_sprites.sh` | For sprite processing |
| Sprite prompt | `docs/glyph-sprite-prompts.md` | For art generation |
| Portrait + silhouette | `assets/sprites/glyphs/` | Always |
| Starter list | `core/progression/roster_state.gd` | If starter |
| Initial discovery | `core/game_state.gd` | If starter |
