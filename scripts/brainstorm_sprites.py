#!/usr/bin/env python3
"""Brainstorm visual directions for glyph species using Gemini image generation.

Usage:
    python3 scripts/brainstorm_sprites.py
    python3 scripts/brainstorm_sprites.py --species shimmer
    python3 scripts/brainstorm_sprites.py --directions "arcane,prismatic"

Generates concept art for each species × direction combination.
Output goes to raw/brainstorm/<species>_<direction>.png for side-by-side comparison.

Reads API key from .env file (GEMINI_API_KEY=...).
"""

import argparse
import os
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
ENV_FILE = PROJECT_DIR / ".env"
OUTPUT_DIR = PROJECT_DIR / "raw" / "brainstorm"

MODEL = "gemini-3-pro-image-preview"

# Shared style/framing block (same as generate_sprites.py)
STYLE_BLOCK = (
    "Clean vector/cartoon style. Bold black outlines, flat color fills. "
    "No gradients, no soft brushwork, no painterly texture. "
    "The design should be simple enough to read clearly when scaled down to 64x64 pixels. "
    "No thin lines or intricate patterns."
)

FRAMING_BLOCK = (
    "512x512 image. Full body visible, facing right in a 3/4 view. Neutral idle pose. "
    "Character should fill roughly 80% of the canvas, centered, with even padding on all sides. "
    "No part of the creature should touch the canvas edge. Solid white background. "
    "No ground shadow, no environment, no effects, no text, no UI elements, no watermarks."
)

# Species base descriptions (gameplay role, no visual direction)
SPECIES = {
    "gritstone": {
        "tier": "T1",
        "role": "a dense, sturdy melee fighter. It tackles enemies head-on and can brace into a defensive stance.",
        "personality": "solid, reliable, stubborn, compact. Low to the ground, heavy despite small size.",
        # Direction-appropriate names to avoid "grit/stone" skewing the image
        "names": {
            "arcane": "Wardkin",
            "prismatic": "Prismite",
            "glitch": "Bitcrumb",
            "origami": "Foldling",
        },
    },
    "shimmer": {
        "tier": "T1",
        "role": "a wispy, agile support creature. It tackles at range and soothes allies with a gentle pulse of neutral energy.",
        "personality": "ethereal, calming, mysterious, gentle. Hovers above the ground, soft and elusive.",
        "names": {
            "arcane": "Sigilwisp",
            "prismatic": "Gleamlet",
            "glitch": "Flickermote",
            "origami": "Creasel",
        },
    },
    "monolith": {
        "tier": "T2",
        "role": "a balanced generalist born from fusing two T1 neutral creatures. It tackles, braces defensively, soothes allies, and projects a ward pulse that shields the entire squad.",
        "personality": "ancient, balanced, quietly powerful. Larger and more imposing than T1s — a clear evolution.",
        "names": {
            "arcane": "Aegis",
            "prismatic": "Spectra",
            "glitch": "Staticore",
            "origami": "Oriform",
            "kintsugi": "Remnant",
            "constellation": "Astralith",
            "rorschach": "Mirraxis",
            "mercury": "Quickform",
            "totem": "Graven",
            "hologram": "Lumencore",
            "fossil": "Paleoward",
            "smoke": "Hazeform",
            "mosaic": "Tessera",
            "chalk": "Scrawl",
        },
    },
}

# Visual directions to brainstorm — each defines shape language, palette, and thematic hook
DIRECTIONS = {
    "arcane": {
        "label": "Arcane Construct",
        "description": (
            "The creature looks CONSTRUCTED, not natural. Its body is made of smooth, "
            "machined-looking panels or plates with glowing sigil/rune engravings. "
            "It resembles rift infrastructure that became sentient — like a magical robot "
            "or animated ward-stone. Clean geometric edges, visible seams where plates meet. "
            "Rune markings glow with inner light."
        ),
        "palette": "white and silver body panels, soft lavender glow on runes/sigils, pale gold accent lines, dark grey/black outlines",
        "NOT": "NOT stone, NOT rock, NOT earthy. Think porcelain or polished metal, not geology.",
    },
    "prismatic": {
        "label": "Prismatic / Iridescent",
        "description": (
            "The creature's body is translucent white/clear with rainbow-edge highlights "
            "along its silhouette and surface facets — like light passing through a prism "
            "or crystal. It refracts light rather than having a fixed color. The rainbow "
            "accents suggest it could become any elemental type but hasn't committed to one. "
            "Faceted, gem-like body surfaces."
        ),
        "palette": "translucent white/clear body, rainbow-spectrum edge highlights (subtle — not garish), pale pink and pale cyan accents, dark grey/black outlines",
        "NOT": "NOT grey, NOT monochrome. The rainbow edges are the key distinguishing feature.",
    },
    "glitch": {
        "label": "Glitch / Static",
        "description": (
            "The creature looks like raw rift signal that hasn't fully resolved into a "
            "type. Parts of its body appear pixelated, fragmented, or have scan-line "
            "artifacts. Some body sections are offset or duplicated slightly, like a "
            "corrupted image. It feels unstable but coherent — digital noise given form. "
            "Square/rectangular motifs in the body shape."
        ),
        "palette": "white and light grey body with black scan-line/pixel artifacts, magenta and cyan glitch-flicker accents, dark grey/black outlines",
        "NOT": "NOT smooth or organic. Should look digitally corrupted. NOT similar to Glitchkit (Water T1) — Glitchkit is cat/gremlin-like. These should be more abstract/geometric.",
    },
    "origami": {
        "label": "Origami / Paper-Fold",
        "description": (
            "The creature is made of angular, faceted, paper-like folds — as if someone "
            "folded it into existence from sheets of pure white material. Clean geometric "
            "creases, triangular facets, sharp edges. It looks crafted and intentional, "
            "like sacred geometry given life. Minimal detail — maximum shape language. "
            "The folds catch light differently, creating subtle value shifts."
        ),
        "palette": "white and off-white body with visible fold creases in light grey, pale blue shadow on fold undersides, single warm gold accent (eyes or core marking), dark grey/black outlines",
        "NOT": "NOT rounded or organic. Angular facets are the defining feature. Think low-poly 3D or actual paper craft.",
    },
    # ── Round 2: 10 standalone concepts, each with a unique creature ──
    # These are generated via --standalone mode, not species × direction
    "kintsugi": {
        "label": "Kintsugi / Broken & Repaired",
        "standalone_name": "Remnant",
        "standalone_prompt": (
            'Design a creature called "Remnant" for a 2D top-down RPG called Glyphrift. '
            "Remnant is a Neutral-type monster — neither fire, water, earth, nor electric. "
            "It is the raw substrate of the rift itself, predating all elements.\n\n"
            "Remnant's body is smooth white ceramic that has been shattered and repaired "
            "with glowing gold seams — the Japanese art of kintsugi. The cracks and gold "
            "repair lines ARE the design. It was broken by the rift and put itself back "
            "together, stronger for having been broken. Pieces fit imperfectly, with gaps "
            "filled by warm golden light leaking through. Medium-sized, upright bipedal "
            "stance, calm and dignified. One arm is more cracked than the other. A single "
            "gold-glowing eye where the largest crack meets.\n\n"
            "NOT stone, NOT rock. Smooth CERAMIC like a porcelain figure. The gold crack-lines are the focal point.\n\n"
        ),
        "palette": "smooth white/cream ceramic body, bright gold crack-lines and seams that glow, dark grey/black outlines. NO other colors.",
    },
    "constellation": {
        "label": "Constellation / Star-Map",
        "standalone_name": "Astralith",
        "standalone_prompt": (
            'Design a creature called "Astralith" for a 2D top-down RPG called Glyphrift. '
            "Astralith is a Neutral-type monster — it predates all elements, born from the "
            "cosmos before the rift split energy into types.\n\n"
            "Astralith's body is deep navy-black, like a window into the night sky. Glowing "
            "white star-dots are scattered across its surface, connected by thin silver lines "
            "forming constellation patterns. It looks like someone cut a creature-shaped hole "
            "in reality and the cosmos shows through. Medium-sized, four-legged, sturdy but "
            "graceful — like a celestial deer or elk. Antler-like projections with stars at "
            "the tips. Calm, watchful presence.\n\n"
            "NOT grey or washed out. The body must be DARK (night sky) with BRIGHT star accents. Strong contrast.\n\n"
        ),
        "palette": "deep navy/dark indigo body, bright white star dots, pale silver constellation lines, soft blue glow around stars, dark grey/black outlines",
    },
    "constellation_b": {
        "label": "Constellation / Star-Map (small)",
        "standalone_name": "Novakit",
        "standalone_prompt": (
            'Design a small creature called "Novakit" for a 2D top-down RPG called Glyphrift. '
            "Novakit is a Tier 1 Neutral-type starter monster — small, quick, and curious. "
            "It darts around like a shooting star.\n\n"
            "Novakit's body is deep navy-black, like a window into the night sky. Bright white "
            "star-dots are scattered across its surface, connected by thin silver constellation "
            "lines. It is small, compact, and fox-like — pointy ears, a bushy tail that trails "
            "stars, alert posture. A bright star marks each ear tip and the tail tip. Big "
            "curious eyes made of two bright stars. It looks like a piece of the night sky "
            "shaped itself into a little fox kit.\n\n"
            "NOT grey or washed out. DARK body with BRIGHT star accents. Strong contrast.\n\n"
        ),
        "palette": "deep navy/dark indigo body, bright white star dots, pale silver constellation lines, soft blue glow around stars, dark grey/black outlines",
    },
    "constellation_c": {
        "label": "Constellation / Star-Map (hovering)",
        "standalone_name": "Orbweft",
        "standalone_prompt": (
            'Design a small creature called "Orbweft" for a 2D top-down RPG called Glyphrift. '
            "Orbweft is a Tier 1 Neutral-type support monster — gentle, hovering, and soothing. "
            "It pulses with calm stellar energy.\n\n"
            "Orbweft's body is deep navy-black, like a window into the night sky. Star-dots "
            "glow across its surface connected by silver constellation lines. It is a small, "
            "round, jellyfish-like creature that hovers — a domed bell-shaped top with 4-5 "
            "trailing tendrils that fade to wisps of starlight. The dome has a prominent bright "
            "star at its center. Gentle pulsing glow. No legs — it floats serenely. Peaceful "
            "and mysterious.\n\n"
            "NOT grey or washed out. DARK body with BRIGHT star accents. Strong contrast.\n\n"
        ),
        "palette": "deep navy/dark indigo body, bright white star dots, pale silver constellation lines, soft blue glow around stars, dark grey/black outlines",
    },
    "rorschach": {
        "label": "Rorschach / Ink-Blot",
        "standalone_name": "Mirraxis",
        "standalone_prompt": (
            'Design a creature called "Mirraxis" for a 2D top-down RPG called Glyphrift. '
            "Mirraxis is a Neutral-type monster — a living psychological test, a blank canvas "
            "that reflects the viewer's expectations.\n\n"
            "Mirraxis is a living Rorschach ink-blot — a PERFECTLY symmetrical black-and-white "
            "form with an ambiguous silhouette. Is it a butterfly? A face? Two creatures? Its "
            "body is made of flowing ink-like substance with organic splatter edges and drip "
            "details at the bottom. The symmetry is eerie and deliberate. Medium-sized, "
            "roughly humanoid but abstract. Floating slightly off the ground. Two pale violet "
            "eye-dots are the only color.\n\n"
            "NOT messy or chaotic. The symmetry must be PERFECT and deliberate. Think clinical psychology test, not splatter painting.\n\n"
        ),
        "palette": "stark black ink body with white negative-space patterns inside it, pale violet eye-glow as the only color accent, white background",
    },
    "mercury": {
        "label": "Liquid Mercury / Chrome",
        "standalone_name": "Quickform",
        "standalone_prompt": (
            'Design a creature called "Quickform" for a 2D top-down RPG called Glyphrift. '
            "Quickform is a Neutral-type monster — liquid potential that hasn't committed to "
            "any elemental form. It absorbs and reflects everything.\n\n"
            "Quickform's body is made of liquid mercury — smooth, reflective, chrome-like "
            "surface that catches and warps light. Bulging, blob-like forms held together by "
            "surface tension. Some parts stretch into thin metallic tendrils. Medium-sized, "
            "vaguely quadrupedal but constantly shifting — like a mercury sculpture that's "
            "still deciding what shape to be. Bright white highlight spots where light hits. "
            "Two dark eye-indentations on a featureless face.\n\n"
            "NOT matte or textured. The surface must look WET and REFLECTIVE — liquid metal, not brushed steel.\n\n"
        ),
        "palette": "silver-chrome body with white highlights and dark grey reflections, subtle blue-tint on shadow side, dark grey/black outlines",
    },
    "mercury_b": {
        "label": "Liquid Mercury / Chrome (small)",
        "standalone_name": "Dropkin",
        "standalone_prompt": (
            'Design a small creature called "Dropkin" for a 2D top-down RPG called Glyphrift. '
            "Dropkin is a Tier 1 Neutral-type starter monster — small, bouncy, and curious. "
            "A little blob of liquid potential.\n\n"
            "Dropkin's body is a small ball of liquid mercury — smooth, reflective, chrome-like. "
            "It looks like a large mercury droplet that grew stubby little legs and a face. "
            "Round body, two small arm-nubs, two stubby legs. Its surface is perfectly smooth "
            "and reflective with bright white highlight spots. Two dark circular eye-dents in "
            "its featureless chrome face. A small antenna-like mercury tendril on top of its "
            "head, wobbling. It looks like it could puddle back into liquid at any moment.\n\n"
            "NOT matte or textured. WET and REFLECTIVE surface — liquid metal, not brushed steel.\n\n"
        ),
        "palette": "silver-chrome body with white highlights and dark grey reflections, subtle blue-tint on shadow side, dark grey/black outlines",
    },
    "mercury_c": {
        "label": "Liquid Mercury / Chrome (hovering)",
        "standalone_name": "Mirrorwisp",
        "standalone_prompt": (
            'Design a small creature called "Mirrorwisp" for a 2D top-down RPG called Glyphrift. '
            "Mirrorwisp is a Tier 1 Neutral-type support monster — gentle, floating, reflective. "
            "A hovering mirror that soothes allies.\n\n"
            "Mirrorwisp is a floating creature made of liquid mercury. Its body is a flattened "
            "disc or lens shape — like a hovering mercury mirror — with a smooth, perfectly "
            "reflective surface. Two small wing-like mercury fins extend from its sides, gently "
            "rippling. A single dark eye-ring in the center of its disc-face. Tiny mercury "
            "droplets orbit slowly around it. No legs — it hovers. Serene and hypnotic.\n\n"
            "NOT matte or textured. WET and REFLECTIVE surface — liquid metal mirror, not solid steel.\n\n"
        ),
        "palette": "silver-chrome body with white highlights and dark grey reflections, subtle blue-tint on shadow side, dark grey/black outlines",
    },
    "totem": {
        "label": "Totem / Carved Mask",
        "standalone_name": "Graven",
        "standalone_prompt": (
            'Design a creature called "Graven" for a 2D top-down RPG called Glyphrift. '
            "Graven is a Neutral-type monster — an ancestral spirit that connects all elements "
            "through ritual and balance.\n\n"
            "Graven resembles a walking carved totem pole or ceremonial mask stack. Its body "
            "is made of smooth carved WOOD (not stone) with bold painted markings. Multiple "
            "carved faces stacked vertically — a large main face as the torso, a smaller one "
            "as the head. Short stubby legs, no arms — the carved faces ARE its expression. "
            "Bold geometric tribal patterns. Symmetrical painted markings in red and teal. "
            "Amber glowing eyes on each face. It feels sacred and ancient.\n\n"
            "NOT stone. Smooth CARVED WOOD. Think Pacific Northwest totem art or tiki — bold, graphic, ceremonial.\n\n"
        ),
        "palette": "warm cream/ivory carved wood body, bold red and teal painted markings (symmetrical), black carved lines, gold or amber eye accents",
    },
    "hologram": {
        "label": "Hologram / Projection",
        "standalone_name": "Lumencast",
        "standalone_prompt": (
            'Design a creature called "Lumencast" for a 2D top-down RPG called Glyphrift. '
            "Lumencast is a Neutral-type monster — not fully materialized, still being "
            "projected into existence by the rift.\n\n"
            "Lumencast is a semi-transparent holographic projection. You can faintly see "
            "through its body. It flickers with faint horizontal scan lines and has a soft "
            "blue-white glow. Some edges double or ghost slightly, like a bad signal. "
            "Medium-sized, floating, roughly humanoid with long trailing limbs that fade "
            "to nothing. A bright white core in its chest — the projection source. Its face "
            "is a simple glowing visor-line. Serene but incomplete.\n\n"
            "NOT opaque or solid. Transparency and glow are essential. Think sci-fi hologram table.\n\n"
        ),
        "palette": "semi-transparent pale blue body with white glow edges, faint horizontal scan lines in darker blue, bright white core/eyes, dark grey/black outlines on outer edge only",
    },
    "fossil": {
        "label": "Fossil / Amber-Preserved",
        "standalone_name": "Ambergast",
        "standalone_prompt": (
            'Design a creature called "Ambergast" for a 2D top-down RPG called Glyphrift. '
            "Ambergast is a Neutral-type monster — an ancient rift creature from before "
            "elements existed, preserved in amber and reanimated.\n\n"
            "Ambergast has a bone-white skeletal framework — visible ribs, spine ridges, "
            "a stylized skull with hollow eye sockets that glow warm amber. Parts of its body "
            "are encased in translucent honey-colored amber/resin, as if partially fossilized. "
            "Medium-sized, quadrupedal, a mix of exposed bones and amber-preserved sections. "
            "An amber crystal grows from its back like a dorsal fin. Slow, ancient, dignified.\n\n"
            "NOT grey or cold-colored. The amber warmth is the key accent. NOT a real dinosaur — stylized creature skeleton with amber.\n\n"
        ),
        "palette": "bone-white skeletal body, warm amber/honey translucent resin sections, soft orange glow in eye sockets and joints, dark grey/black outlines",
    },
    "smoke": {
        "label": "Smoke / Vapor Form",
        "standalone_name": "Hazewalker",
        "standalone_prompt": (
            'Design a creature called "Hazewalker" for a 2D top-down RPG called Glyphrift. '
            "Hazewalker is a Neutral-type monster — formless potential given just enough "
            "shape to exist. Smoke fills any container, takes any shape.\n\n"
            "Hazewalker is made of dense, swirling smoke that holds a coherent shape through "
            "sheer will. Its upper body is dense and opaque with visible swirl patterns inside. "
            "Its lower body and limbs trail off into wisps and tendrils. Medium-sized, roughly "
            "ape-like posture — broad shoulders, long arms, hunched. Two piercing amber eyes "
            "glow through the haze like headlights in fog. A denser core glows faintly inside "
            "its chest.\n\n"
            "NOT a ghost or specter. PHYSICAL SMOKE — dense and volumetric, not transparent and spooky.\n\n"
        ),
        "palette": "pale grey-white smoke body with darker grey swirl details inside, soft warm yellow/amber glowing eyes and inner core, dark grey/black outlines on dense parts only",
    },
    "mosaic": {
        "label": "Mosaic / Stained Glass",
        "standalone_name": "Tessera",
        "standalone_prompt": (
            'Design a creature called "Tessera" for a 2D top-down RPG called Glyphrift. '
            "Tessera is a Neutral-type monster — it contains fragments of ALL elements "
            "combined into one form. A patchwork of every color, committed to none.\n\n"
            "Tessera's body is made of small colored tile pieces separated by dark lead-line "
            "borders — like a stained glass window or Roman mosaic that came to life. Each "
            "tile is a different soft pastel color (pale pink, pale blue, pale green, pale "
            "gold, pale lavender). Medium-sized, turtle-like or armadillo-like — a domed "
            "shell of mosaic tiles on top, sturdy legs below. Simple round eyes made of "
            "clear/white tiles. The patchwork IS the beauty.\n\n"
            "NOT monochrome. The VARIETY of soft pastel colors is the whole point. Think church window or Byzantine mosaic.\n\n"
        ),
        "palette": "multi-pastel tile pieces (pale pink, pale blue, pale green, pale gold, pale lavender) separated by dark grey/black lead lines, dark grey/black outlines",
    },
    "mosaic_b": {
        "label": "Mosaic / Stained Glass (small)",
        "standalone_name": "Shardling",
        "standalone_prompt": (
            'Design a small creature called "Shardling" for a 2D top-down RPG called Glyphrift. '
            "Shardling is a Tier 1 Neutral-type starter monster — small, scrappy, and colorful. "
            "A living fragment of a stained glass window.\n\n"
            "Shardling's body is made of mosaic tile pieces separated by dark lead-line borders "
            "— like a piece of stained glass that broke free and came to life. Each tile is a "
            "different soft pastel color (pale pink, pale blue, pale green, pale gold, pale "
            "lavender). Small and lizard-like — four short legs, a jagged tail made of "
            "triangular tile shards, a head with two round white-tile eyes. Some tiles at the "
            "edges are cracked or missing, showing it broke off from something larger. Eager "
            "and scrappy.\n\n"
            "NOT monochrome. VARIETY of soft pastel colors is the whole point. Think broken stained glass fragment.\n\n"
        ),
        "palette": "multi-pastel tile pieces (pale pink, pale blue, pale green, pale gold, pale lavender) separated by dark grey/black lead lines, dark grey/black outlines",
    },
    "mosaic_c": {
        "label": "Mosaic / Stained Glass (hovering)",
        "standalone_name": "Kaleidore",
        "standalone_prompt": (
            'Design a small creature called "Kaleidore" for a 2D top-down RPG called Glyphrift. '
            "Kaleidore is a Tier 1 Neutral-type support monster — gentle, floating, and "
            "mesmerizing. A living kaleidoscope.\n\n"
            "Kaleidore's body is made of mosaic tile pieces separated by dark lead-line borders. "
            "Each tile is a different soft pastel color (pale pink, pale blue, pale green, pale "
            "gold, pale lavender). Its shape is a floating mandala or rosette — a circular, "
            "symmetrical disc-body with petal-like tile extensions radiating outward, like a "
            "stained glass rose window. A single bright white tile at the center serves as its "
            "eye. No legs — it hovers and slowly rotates. Hypnotic and calming.\n\n"
            "NOT monochrome. VARIETY of soft pastel colors in a symmetrical mandala pattern. Think rose window.\n\n"
        ),
        "palette": "multi-pastel tile pieces (pale pink, pale blue, pale green, pale gold, pale lavender) separated by dark grey/black lead lines, dark grey/black outlines",
    },
    "chalk": {
        "label": "Chalk / Sketched Into Existence",
        "standalone_name": "Scrawl",
        "standalone_prompt": (
            'Design a creature called "Scrawl" for a 2D top-down RPG called Glyphrift. '
            "Scrawl is a Neutral-type monster — the IDEA of a creature before it becomes "
            "real. A rough draft given life.\n\n"
            "Scrawl looks like it was drawn on a blackboard with chalk. Visible chalk "
            "texture, rough sketch-like lines, slight smudging at the edges. Some body parts "
            "are thickly drawn (dense chalk) while others are barely suggested (thin ghostly "
            "lines, unfinished). Chalk dust particles float around it. Medium-sized, roughly "
            "bear-like but sketchy and unfinished — one arm is fully drawn, the other is just "
            "an outline. Simple dot eyes. It looks like a child's drawing that stood up.\n\n"
            "NOT clean or polished. ROUGH, TEXTURED, hand-drawn. Think actual chalk on blackboard.\n\n"
        ),
        "palette": "white chalk lines and fills on a dark charcoal/slate body, colored chalk accents in pale blue and pale pink for eyes and markings, chalk dust particles in white",
    },
}


def load_api_key() -> str:
    """Load GEMINI_API_KEY from .env file."""
    if not ENV_FILE.exists():
        print(f"ERROR: {ENV_FILE} not found. Create it with GEMINI_API_KEY=your_key")
        sys.exit(1)
    for line in ENV_FILE.read_text().splitlines():
        line = line.strip()
        if line.startswith("GEMINI_API_KEY="):
            return line.split("=", 1)[1].strip()
    print("ERROR: GEMINI_API_KEY not found in .env")
    sys.exit(1)


def generate_image(api_key: str, prompt: str) -> bytes | None:
    """Call Gemini API to generate an image. Returns PNG bytes or None."""
    try:
        from google import genai
        from google.genai import types
    except ImportError:
        print("ERROR: google-genai not installed. Run: pip3 install google-genai")
        sys.exit(1)

    client = genai.Client(api_key=api_key)

    try:
        response = client.models.generate_content(
            model=MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_modalities=["TEXT", "IMAGE"],
            ),
        )
    except Exception as e:
        print(f"  API error: {e}")
        return None

    if not response.candidates:
        print("  No candidates in response")
        return None

    for part in response.candidates[0].content.parts:
        if part.inline_data and part.inline_data.mime_type.startswith("image/"):
            return part.inline_data.data

    print("  No image in response (text only)")
    if response.candidates[0].content.parts:
        for part in response.candidates[0].content.parts:
            if part.text:
                print(f"  Response text: {part.text[:200]}")
    return None


def build_prompt(species_id: str, direction_id: str) -> str:
    """Build a full prompt for a species × direction combination."""
    sp = SPECIES[species_id]
    dr = DIRECTIONS[direction_id]
    name = sp["names"][direction_id]

    prompt = (
        f'Design a creature called "{name}" for a 2D top-down RPG called Glyphrift. '
        f'{name} is a {sp["tier"]} Neutral-type monster — {sp["role"]} '
        f"Neutral-type creatures are NOT elemental — they are the raw substrate of the rift itself.\n\n"
        f'Visual direction — "{dr["label"]}": {dr["description"]}\n\n'
        f'Personality and shape: {sp["personality"]}\n\n'
        f'{dr["NOT"]}\n\n'
        f'Style rules: {STYLE_BLOCK} Limited color palette — {dr["palette"]}.\n\n'
        f"Framing: {FRAMING_BLOCK}"
    )
    return prompt


def build_standalone_prompt(direction_id: str) -> str:
    """Build a full standalone prompt for a direction (unique creature, no species dependency)."""
    dr = DIRECTIONS[direction_id]
    base = dr["standalone_prompt"]
    prompt = (
        f"{base}"
        f'Style rules: {STYLE_BLOCK} Limited color palette — {dr["palette"]}.\n\n'
        f"Framing: {FRAMING_BLOCK}"
    )
    return prompt


def main():
    parser = argparse.ArgumentParser(description="Brainstorm neutral glyph visual directions via Gemini")
    parser.add_argument("--species", type=str, help="Generate for one species only (e.g. shimmer)")
    parser.add_argument("--directions", type=str, help="Comma-separated directions to try (default: all)")
    parser.add_argument("--standalone", action="store_true", help="Generate standalone concepts (one unique creature per direction, no species dependency)")
    parser.add_argument("--dry-run", action="store_true", help="Print prompts without calling API")
    args = parser.parse_args()

    # Standalone mode: one unique creature per direction
    if args.standalone:
        standalone_dirs = {k: v for k, v in DIRECTIONS.items() if "standalone_prompt" in v}
        direction_list = args.directions.split(",") if args.directions else list(standalone_dirs.keys())

        for d in direction_list:
            if d not in standalone_dirs:
                print(f"ERROR: No standalone prompt for '{d}'. Available: {', '.join(standalone_dirs.keys())}")
                sys.exit(1)

        total = len(direction_list)
        print(f"Brainstorming {total} standalone concepts")
        print(f"Output: {OUTPUT_DIR}/\n")

        if args.dry_run:
            for direction_id in direction_list:
                dr = standalone_dirs[direction_id]
                prompt = build_standalone_prompt(direction_id)
                print(f"{'=' * 60}")
                print(f"{dr['standalone_name']} — {dr['label']}")
                print(f"{'=' * 60}")
                print(prompt)
                print()
            return

        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        api_key = load_api_key()

        generated = 0
        for direction_id in direction_list:
            dr = standalone_dirs[direction_id]
            out_path = OUTPUT_DIR / f"standalone_{direction_id}.png"
            if out_path.exists():
                print(f"  SKIP {dr['standalone_name']} — {direction_id} (already exists)")
                generated += 1
                continue

            print(f"[{generated + 1}/{total}] {dr['standalone_name']} — {dr['label']}")

            prompt = build_standalone_prompt(direction_id)
            image_data = generate_image(api_key, prompt)

            if image_data is None:
                print(f"  FAILED — no image returned")
                continue

            out_path.write_bytes(image_data)
            size_kb = len(image_data) / 1024
            print(f"  saved: {out_path.name} ({size_kb:.0f} KB)")
            generated += 1

        print(f"\nDone. {generated}/{total} standalone concepts in {OUTPUT_DIR}/")
        return

    # Original mode: species × direction matrix
    species_list = [args.species.lower()] if args.species else list(SPECIES.keys())
    direction_list = args.directions.split(",") if args.directions else [k for k in DIRECTIONS.keys() if "standalone_prompt" not in DIRECTIONS[k]]

    # Validate
    for s in species_list:
        if s not in SPECIES:
            print(f"ERROR: Unknown species '{s}'. Available: {', '.join(SPECIES.keys())}")
            sys.exit(1)
    for d in direction_list:
        if d not in DIRECTIONS:
            print(f"ERROR: Unknown direction '{d}'. Available: {', '.join(DIRECTIONS.keys())}")
            sys.exit(1)

    total = len(species_list) * len(direction_list)
    print(f"Brainstorming {total} concepts: {len(species_list)} species × {len(direction_list)} directions")
    print(f"Output: {OUTPUT_DIR}/\n")

    if args.dry_run:
        for species_id in species_list:
            for direction_id in direction_list:
                prompt = build_prompt(species_id, direction_id)
                print(f"{'=' * 60}")
                print(f"{species_id} × {direction_id}")
                print(f"{'=' * 60}")
                print(prompt)
                print()
        return

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    api_key = load_api_key()

    generated = 0
    for species_id in species_list:
        for direction_id in direction_list:
            out_path = OUTPUT_DIR / f"{species_id}_{direction_id}.png"
            if out_path.exists():
                print(f"  SKIP {species_id} × {direction_id} (already exists)")
                generated += 1
                continue

            print(f"[{generated + 1}/{total}] {species_id} × {direction_id} ({DIRECTIONS[direction_id]['label']})")

            prompt = build_prompt(species_id, direction_id)
            image_data = generate_image(api_key, prompt)

            if image_data is None:
                print(f"  FAILED — no image returned")
                continue

            out_path.write_bytes(image_data)
            size_kb = len(image_data) / 1024
            print(f"  saved: {out_path.name} ({size_kb:.0f} KB)")
            generated += 1

    print(f"\nDone. {generated}/{total} concepts generated in {OUTPUT_DIR}/")
    print("Review the images and pick a direction, then update the prompts in docs/glyph-sprite-prompts.md")


if __name__ == "__main__":
    main()
