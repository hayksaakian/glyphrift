# Glyphrift — Project Instructions

## Autonomous Work Mode

When working autonomously (user is away), follow this protocol:

### What to work on
Work through `docs/session10-punchlist.md` items in this priority order:
1. **Crawler Upgrades** — milestone detection, awards, chassis UI, save/load
2. **Mid-rift save/load** — save dungeon state so quitting mid-rift resumes
3. **Animations** — tween-based combat/dungeon/capture/bastion animations
4. **UI Polish** — button states, text overflow, smooth transitions
5. **Balance pass** — only after features are done

### How to work
- **No plan mode** — just implement directly, one feature at a time
- **Commit after each feature** — small, working increments
- **Write tests first** when adding logic (red → green → refactor)
- **Run `~/bin/godot --headless --script res://tests/test_runner.gd`** after every change to verify nothing breaks
- **All 1271+ tests must pass** before committing
- **Read existing code** before modifying — follow established patterns
- **Update `docs/session10-punchlist.md`** — check off items as completed
- **Update memory** in `~/.claude/projects/-Users-hayk-godot-glyphrift/memory/MEMORY.md` when completing major features

### Key references
- GDD: `glyphrift-design-doc-v0.3.md` — game design source of truth
- TDD: `glyphrift-tdd-v1.1.md` — technical design details
- Punchlist: `docs/session10-punchlist.md` — current work items
- Memory: see MEMORY.md for architecture patterns, test conventions, gotchas

### Testing conventions
- Tests extend `SceneTree`, use `_init()` + `await process_frame`
- Autoloads NOT available in `--script` mode — instantiate manually
- Use `instant_mode = true` on UI components for headless testing
- AnimationQueue: `instant_mode` + `drain()` for batch processing
- NO `await` inside individual test methods
- Use Dictionary for mutable signal tracking (GDScript lambda limitation)

### Don't
- Don't enter plan mode
- Don't ask user questions — make reasonable decisions
- Don't skip tests or use `--no-verify`
- Don't create documentation files beyond what's needed
- Don't refactor code that isn't related to the current task
