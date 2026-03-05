# Session 11 — Playtest Punchlist

## Formation Flow Rework
- [x] Remove mandatory formation screen before every battle — BattleScene.skip_formation flag
- [x] Combat popups (enemy, boss) get two buttons: "Fight" (use current formation) and "Formation" (adjust)
- [x] "Adjust Formation" opens the formation screen in dungeon, then proceeds to fight on confirm
- [x] Show formation preview in combat popups (small front/back row glyph icons with F:/B: labels)
- [x] Formation UI uses properly-sized glyph art (56x56 portraits, scalable via portrait_size property)
- [ ] Consider: reusable glyph display component for visual consistency across formation, barracks, squad overlay

## Mastery Visibility
- [x] Victory screen now shows squad mastery status (stars + next objective progress) on every win
- [x] Add mastery stars (0-3) to GlyphPanel (battle), GlyphCard (barracks/fusion), SquadOverlay (dungeon)
- [x] Fully mastered glyphs show gold stars; GlyphCard already had gold mastery border
- [x] Victory screen shows per-glyph next incomplete objective with progress counters
- [ ] GlyphPortrait (turn strip) too small for stars — deferred until reusable component refactor

## Visual / Art Issues
(collecting from playtest)

## Flow / UX Issues
(collecting from playtest)

## Bug Fixes
- [x] Mid-rift save persisted after extraction/loss — `current_dungeon` not cleared before auto-save on `won=false`
