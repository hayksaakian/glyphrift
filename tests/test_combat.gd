extends SceneTree

var _data_loader: Node = null
var _engine: Node = null
var pass_count: int = 0
var fail_count: int = 0

## Signal tracking
var _events: Array[String] = []


func _init() -> void:
	## Manually instantiate DataLoader
	var dl_script: GDScript = load("res://core/data_loader.gd") as GDScript
	_data_loader = dl_script.new() as Node
	_data_loader.name = "DataLoader"
	root.add_child(_data_loader)

	## Manually instantiate CombatEngine
	var ce_script: GDScript = load("res://core/combat/combat_engine.gd") as GDScript
	_engine = ce_script.new() as Node
	_engine.name = "CombatEngine"
	_engine.data_loader = _data_loader
	root.add_child(_engine)

	await process_frame
	_run_tests()
	quit()


func _run_tests() -> void:
	print("")
	print("========================================")
	print("  GLYPHRIFT — Combat Engine Tests")
	print("========================================")
	print("")

	_test_glyph_instance()
	_test_damage_calculator()
	_test_turn_queue()
	_test_status_manager()
	_test_ai_controller()
	_test_interrupt_ko()
	_test_auto_battle()
	_test_boss_variety()

	print("")
	print("========================================")
	print("  RESULTS: %d passed, %d failed" % [pass_count, fail_count])
	print("========================================")
	if fail_count == 0:
		print("  ALL TESTS PASSED")
	else:
		print("  SOME TESTS FAILED — review output above")
	print("")


func _assert(condition: bool, test_name: String) -> void:
	if condition:
		print("[PASS] %s" % test_name)
		pass_count += 1
	else:
		print("[FAIL] %s" % test_name)
		fail_count += 1


# --- GlyphInstance Tests ---

func _test_glyph_instance() -> void:
	print("--- GlyphInstance ---")

	var sp: GlyphSpecies = _data_loader.get_species("zapplet")
	var g: GlyphInstance = GlyphInstance.create_from_species(sp, _data_loader)

	_assert(g.species == sp, "GlyphInstance has correct species reference")
	_assert(g.max_hp == sp.base_hp, "GlyphInstance max_hp matches base_hp (no bonuses)")
	_assert(g.current_hp == g.max_hp, "GlyphInstance current_hp starts at max")
	_assert(g.atk == sp.base_atk, "GlyphInstance atk matches base_atk")
	_assert(g.def_stat == sp.base_def, "GlyphInstance def matches base_def")
	_assert(g.spd == sp.base_spd, "GlyphInstance spd matches base_spd")
	_assert(g.res == sp.base_res, "GlyphInstance res matches base_res")
	_assert(g.techniques.size() == sp.technique_ids.size(), "GlyphInstance has correct technique count")
	_assert(g.instance_id > 0, "GlyphInstance has unique instance_id")

	## Test effective stat modifiers
	g.active_statuses["slow"] = 3
	var eff_spd: float = g.get_effective_spd()
	var expected_spd: float = float(sp.base_spd) * 0.7
	_assert(absf(eff_spd - expected_spd) < 0.01, "Slow reduces effective SPD by 30%%")

	g.active_statuses["weaken"] = 3
	var eff_atk: float = g.get_effective_atk()
	var expected_atk: float = float(sp.base_atk) * 0.75
	_assert(absf(eff_atk - expected_atk) < 0.01, "Weaken reduces effective ATK by 25%%")

	g.active_statuses["corrode"] = 3
	var eff_def: float = g.get_effective_def()
	var expected_def: float = float(sp.base_def) * 0.75
	_assert(absf(eff_def - expected_def) < 0.01, "Corrode reduces effective DEF by 25%%")

	## Test reset
	g.reset_combat_state()
	_assert(g.active_statuses.is_empty(), "reset_combat_state clears statuses")
	_assert(g.cooldowns.is_empty(), "reset_combat_state clears cooldowns")
	_assert(not g.is_guarding, "reset_combat_state clears guarding")
	_assert(not g.is_knocked_out, "reset_combat_state clears knocked_out")

	## Test GP cost
	_assert(g.get_gp_cost() == 2, "Zapplet GP cost is 2")

	print("")


# --- DamageCalculator Tests ---

func _test_damage_calculator() -> void:
	print("--- DamageCalculator ---")

	var zapplet: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("zapplet"), _data_loader)
	var mossling: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("mossling"), _data_loader)
	var stonepaw: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("stonepaw"), _data_loader)

	var static_snap: TechniqueDef = _data_loader.get_technique("static_snap")
	var rock_toss: TechniqueDef = _data_loader.get_technique("rock_toss")

	## Manual damage calculation: Zapplet (ATK 10) → Mossling (DEF 11) with Static Snap (power 8, electric vs ground)
	## raw = 8 * (10 / 11) = 7.27..
	## affinity: electric vs ground = 0.65 (disadvantage)
	## row: front = 1.0, shield: none = 1.0, guard: none = 1.0, variance: 1.0
	## final = 7.27 * 0.65 * 1.0 = 4.72 → int = 4
	var dmg: int = DamageCalculator.calculate_fixed(zapplet, mossling, static_snap, 1.0)
	_assert(dmg == 4, "Zapplet→Mossling Static Snap = 4 (electric vs ground disadvantage, variance=1.0), got %d" % dmg)

	## Zapplet (electric) → Stonepaw (ground) — disadvantage
	## raw = 8 * (10 / 13) = 6.15..
	## affinity: electric vs ground = 0.65 (disadvantage! electric is weak to ground)
	## Electric > Water > Ground > Electric means: Ground beats Electric
	## So electric attacking ground = disadvantage = 0.65
	dmg = DamageCalculator.calculate_fixed(zapplet, stonepaw, static_snap, 1.0)
	## raw = 8 * (10/13) * 0.65 = 4.0
	_assert(dmg == 4, "Zapplet→Stonepaw Static Snap = 4 (electric vs ground = 0.65x), got %d" % dmg)

	## Test affinity advantage: Stonepaw (ground, ATK 11) → Zapplet (electric, DEF 8) with Rock Toss (power 8, ground)
	## raw = 8 * (11 / 8) = 11.0
	## affinity: ground vs electric = 1.5 (advantage)
	## final = 11.0 * 1.5 = 16.5 → 16
	dmg = DamageCalculator.calculate_fixed(stonepaw, zapplet, rock_toss, 1.0)
	_assert(dmg == 16, "Stonepaw→Zapplet Rock Toss = 16 (ground vs electric advantage), got %d" % dmg)

	## Test affinity multiplier values
	_assert(DamageCalculator.has_affinity_advantage("electric", "water"), "Electric has advantage over Water")
	_assert(DamageCalculator.has_affinity_advantage("water", "ground"), "Water has advantage over Ground")
	_assert(DamageCalculator.has_affinity_advantage("ground", "electric"), "Ground has advantage over Electric")
	_assert(not DamageCalculator.has_affinity_advantage("electric", "ground"), "Electric does NOT have advantage over Ground")
	_assert(not DamageCalculator.has_affinity_advantage("neutral", "electric"), "Neutral has no advantages")

	## Test support technique returns 0
	var brace: TechniqueDef = _data_loader.get_technique("brace")
	dmg = DamageCalculator.calculate_fixed(zapplet, mossling, brace, 1.0)
	_assert(dmg == 0, "Support technique deals 0 damage")

	## Test guard modifier
	mossling.is_guarding = true
	## 8 * (10/11) * 0.65 * 0.5 = 2.36 → 2
	dmg = DamageCalculator.calculate_fixed(zapplet, mossling, static_snap, 1.0)
	_assert(dmg == 2, "Guard halves damage (expected 2), got %d" % dmg)
	mossling.is_guarding = false

	## Test back row modifier with ranged
	mossling.row_position = "back"
	## 8 * (10/11) * 0.65 * 0.7 = 3.30 → 3
	dmg = DamageCalculator.calculate_fixed(zapplet, mossling, static_snap, 1.0)
	_assert(dmg == 3, "Back row reduces ranged damage by 30%% (expected 3), got %d" % dmg)

	## Test piercing ignores back row
	var chain_bolt: TechniqueDef = _data_loader.get_technique("chain_bolt")
	## Piercing: 12 * (10/11) * 0.65 * 1.0 = 7.09 → 7
	dmg = DamageCalculator.calculate_fixed(zapplet, mossling, chain_bolt, 1.0)
	_assert(dmg == 7, "Piercing ignores back row (expected 7), got %d" % dmg)
	mossling.row_position = "front"

	## Test shield modifier
	mossling.active_statuses["shield"] = 2
	## 8 * (10/11) * 0.65 * 0.75 = 3.54 → 3
	dmg = DamageCalculator.calculate_fixed(zapplet, mossling, static_snap, 1.0)
	_assert(dmg == 3, "Shield reduces damage by 25%% (expected 3), got %d" % dmg)
	mossling.active_statuses.erase("shield")

	## Test minimum damage is 1
	## Create a low-power scenario
	var weak_glyph: GlyphInstance = GlyphInstance.new()
	weak_glyph.species = _data_loader.get_species("zapplet")
	weak_glyph.atk = 1
	weak_glyph.max_hp = 10
	weak_glyph.current_hp = 10
	var tank: GlyphInstance = GlyphInstance.new()
	tank.species = _data_loader.get_species("stonepaw")
	tank.def_stat = 100
	tank.max_hp = 100
	tank.current_hp = 100
	## power 8 * (1/100) * 0.65 = 0.052 → min 1
	dmg = DamageCalculator.calculate_fixed(weak_glyph, tank, static_snap, 1.0)
	_assert(dmg == 1, "Minimum damage is 1, got %d" % dmg)

	print("")


# --- TurnQueue Tests ---

func _test_turn_queue() -> void:
	print("--- TurnQueue ---")

	## Create glyphs with known SPD values
	var fast: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("zapplet"), _data_loader)  # SPD 14
	var medium: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("glitchkit"), _data_loader)  # SPD 13
	var slow_g: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("stonepaw"), _data_loader)  # SPD 8

	var queue: TurnQueue = TurnQueue.new()
	var all: Array[GlyphInstance] = [slow_g, fast, medium]  ## Unsorted input
	queue.build(all, false)

	_assert(queue.current() == fast, "Fastest glyph (SPD 14) goes first")
	queue.advance()
	_assert(queue.current() == medium, "Second fastest (SPD 13) goes second")
	queue.advance()
	_assert(queue.current() == slow_g, "Slowest (SPD 8) goes last")
	queue.advance()
	_assert(queue.is_round_complete(), "Round complete after all glyphs acted")

	## Test boss-last on first round
	var boss: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("stormfang"), _data_loader)  # SPD 36
	boss.is_boss = true
	var glyphs: Array[GlyphInstance] = [fast, boss, slow_g]
	queue.build(glyphs, true)
	## Boss should be last despite highest SPD
	var last: GlyphInstance = null
	while not queue.is_round_complete():
		last = queue.current()
		queue.advance()
	_assert(last == boss, "Boss acts last on first round despite highest SPD")

	## Test KO'd glyphs excluded
	slow_g.is_knocked_out = true
	queue.build([fast, slow_g, medium], false)
	var count: int = 0
	while not queue.is_round_complete():
		_assert(queue.current() != slow_g, "KO'd glyph not in queue")
		queue.advance()
		count += 1
	_assert(count == 2, "Only 2 alive glyphs in queue, got %d" % count)
	slow_g.is_knocked_out = false

	## Test preview
	queue.build([fast, medium, slow_g], false)
	var preview: Array[GlyphInstance] = queue.get_preview(2)
	_assert(preview.size() == 2, "Preview returns requested count")
	_assert(preview[0] == fast, "Preview shows upcoming glyphs in order")

	## Test deterministic tiebreak cascade (GDD 8.3)
	## Zapplet (SPD 14, T1 electric) vs Driftwisp (SPD 14, T1 water) — same tier, affinity breaks tie
	var electric_t1: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("zapplet"), _data_loader)
	var water_t1: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("driftwisp"), _data_loader)
	electric_t1.side = "player"
	water_t1.side = "enemy"
	queue.build([water_t1, electric_t1], false)
	_assert(queue.current() == electric_t1, "Tiebreak: electric beats water at same SPD and tier")

	## Ironbark (SPD 14, T2 ground) vs Zapplet (SPD 14, T1 electric) — tier breaks tie
	var ground_t2: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("ironbark"), _data_loader)
	ground_t2.side = "player"
	queue.build([electric_t1, ground_t2], false)
	_assert(queue.current() == ground_t2, "Tiebreak: higher tier (T2) beats lower tier (T1) at same SPD")

	## Same species, same side — HP% breaks tie (lower HP% goes first)
	var wounded: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("zapplet"), _data_loader)
	wounded.side = "player"
	wounded.current_hp = 1  ## Very low HP%
	electric_t1.current_hp = electric_t1.max_hp  ## Full HP
	queue.build([electric_t1, wounded], false)
	_assert(queue.current() == wounded, "Tiebreak: lower HP% acts first (desperation)")

	## Same SPD, same tier, same affinity, same HP — player side wins
	var player_g: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("zapplet"), _data_loader)
	var enemy_g: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("zapplet"), _data_loader)
	player_g.side = "player"
	enemy_g.side = "enemy"
	queue.build([enemy_g, player_g], false)
	_assert(queue.current() == player_g, "Tiebreak: player side wins over enemy at full tie")

	## Determinism: same input always gives same output (run 5 times)
	var consistent: bool = true
	for _i: int in range(5):
		queue.build([water_t1, electric_t1], false)
		if queue.current() != electric_t1:
			consistent = false
			break
	_assert(consistent, "Tiebreak is deterministic across 5 repeated sorts")

	print("")


# --- StatusManager Tests ---

func _test_status_manager() -> void:
	print("--- StatusManager ---")

	var g: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("zapplet"), _data_loader)

	## Test apply
	var applied: bool = StatusManager.apply(g, "burn")
	_assert(applied, "Burn applied successfully")
	_assert(g.active_statuses.has("burn"), "Burn is in active_statuses")
	_assert(g.active_statuses["burn"] == 3, "Burn has 3-turn duration")

	## Test tick — burn damage
	var result: Dictionary = StatusManager.tick(g)
	var expected_burn: int = maxi(1, int(float(g.max_hp) * 0.08))
	_assert(result["burn_damage"] == expected_burn, "Burn deals 8%% max HP (%d), got %d" % [expected_burn, result["burn_damage"]])
	_assert(g.current_hp == g.max_hp - expected_burn, "HP reduced by burn damage")
	_assert(g.active_statuses["burn"] == 2, "Burn duration decremented to 2")

	## Tick again
	StatusManager.tick(g)
	_assert(g.active_statuses["burn"] == 1, "Burn duration decremented to 1")

	## Tick until expire
	result = StatusManager.tick(g)
	_assert(not g.active_statuses.has("burn"), "Burn expired after 3 ticks")
	_assert("burn" in result["expired"], "Burn reported as expired")
	_assert(g.status_immunities.has("burn"), "1-turn immunity granted after burn expired")

	## Test immunity blocks reapplication
	applied = StatusManager.apply(g, "burn")
	_assert(not applied, "Burn blocked by immunity")
	_assert(not g.active_statuses.has("burn"), "Burn not in active statuses while immune")

	## Clear immunity
	StatusManager.clear_immunities_tick(g)
	_assert(not g.status_immunities.has("burn"), "Immunity cleared after 1 turn")

	## Now burn can be reapplied
	applied = StatusManager.apply(g, "burn")
	_assert(applied, "Burn reapplied after immunity expired")

	## Test stun
	g.reset_combat_state()
	StatusManager.apply(g, "stun")
	_assert(StatusManager.is_stunned(g), "is_stunned returns true")
	_assert(g.active_statuses["stun"] == 1, "Stun lasts 1 turn")
	StatusManager.tick(g)
	_assert(not StatusManager.is_stunned(g), "Stun expires after 1 tick")
	_assert(g.status_immunities.has("stun"), "Stun immunity granted")

	## Test refresh (non-stacking)
	g.reset_combat_state()
	StatusManager.apply(g, "slow")
	_assert(g.active_statuses["slow"] == 3, "Slow starts at 3")
	StatusManager.tick(g)
	_assert(g.active_statuses["slow"] == 2, "Slow decremented to 2")
	StatusManager.apply(g, "slow")
	_assert(g.active_statuses["slow"] == 3, "Slow refreshed to 3 (not stacked)")

	## Test shield
	g.reset_combat_state()
	StatusManager.apply(g, "shield")
	_assert(g.active_statuses["shield"] == 2, "Shield lasts 2 turns")

	## Test clear_all
	StatusManager.apply(g, "burn")
	StatusManager.apply(g, "slow")
	StatusManager.clear_all(g)
	_assert(g.active_statuses.is_empty(), "clear_all removes all statuses")

	print("")


# --- AIController Tests ---

func _test_ai_controller() -> void:
	print("--- AIController ---")

	var actor: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("thunderclaw"), _data_loader)
	actor.row_position = "front"
	actor.side = "enemy"

	var target1: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("zapplet"), _data_loader)
	target1.row_position = "front"
	target1.side = "player"

	var target2: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("mossling"), _data_loader)
	target2.row_position = "front"
	target2.side = "player"

	var allies: Array[GlyphInstance] = [actor]
	var enemies: Array[GlyphInstance] = [target1, target2]

	var decision: Dictionary = AIController.decide(actor, allies, enemies, _data_loader)
	_assert(decision["action"] == "attack", "AI chooses attack action")
	_assert(decision["technique"] != null, "AI picks a technique")
	_assert(decision["target"] != null, "AI picks a target")

	## Thunderclaw techniques: Arc Fang (melee 18), Chain Bolt (piercing 12), Static Guard (interrupt)
	## Should pick Arc Fang (highest power, not interrupt)
	var tech: TechniqueDef = decision["technique"]
	_assert(tech.id == "arc_fang", "AI picks highest power non-interrupt technique (Arc Fang), got %s" % tech.id)

	## Test cooldown fallback
	actor.put_on_cooldown(_data_loader.get_technique("arc_fang"))
	decision = AIController.decide(actor, allies, enemies, _data_loader)
	tech = decision["technique"]
	_assert(tech.id == "chain_bolt", "AI falls back to Chain Bolt when Arc Fang on cooldown, got %s" % tech.id)

	## Test back row melee restriction
	actor.row_position = "back"
	actor.cooldowns.clear()
	decision = AIController.decide(actor, allies, enemies, _data_loader)
	tech = decision["technique"]
	_assert(tech.id == "chain_bolt", "AI skips melee from back row, picks Chain Bolt, got %s" % tech.id)
	actor.row_position = "front"

	## Test KO priority — target1 has 1 HP
	target1.current_hp = 1
	actor.cooldowns.clear()
	decision = AIController.decide(actor, allies, enemies, _data_loader)
	var target: GlyphInstance = decision["target"]
	_assert(target == target1, "AI targets glyph that can be KO'd (1 HP)")
	target1.current_hp = target1.max_hp

	## Test lowest HP fallback — inflate HP so neither target can be KO'd
	## Thunderclaw ATK=22, Arc Fang power=18 vs Zapplet DEF=8: ~49 damage, vs Mossling DEF=11: ~23 damage
	## Set HP well above max damage so KO priority doesn't trigger
	target1.max_hp = 200
	target1.current_hp = 120
	target2.max_hp = 200
	target2.current_hp = 100  ## Lower than target1
	actor.cooldowns.clear()
	decision = AIController.decide(actor, allies, enemies, _data_loader)
	target = decision["target"]
	_assert(target == target2, "AI targets lowest HP glyph as fallback")
	## Restore original stats
	target1.max_hp = _data_loader.get_species("zapplet").base_hp
	target1.current_hp = target1.max_hp
	target2.max_hp = _data_loader.get_species("mossling").base_hp
	target2.current_hp = target2.max_hp

	## Test melee can't hit back row when front exists
	target2.row_position = "back"
	actor.cooldowns.clear()
	decision = AIController.decide(actor, allies, enemies, _data_loader)
	tech = decision["technique"]
	if tech.range_type == "melee":
		target = decision["target"]
		_assert(target == target1, "Melee AI doesn't target back row when front exists")
	else:
		_assert(true, "AI picked non-melee so back-row targeting is valid")
	target2.row_position = "front"

	print("")


# --- Interrupt KO Tests (BUG-023) ---

func _test_interrupt_ko() -> void:
	print("--- Interrupt KO (BUG-023) ---")

	## Test 1: static_guard interrupt KOs attacker — attack should be cancelled
	## Use _resolve_interrupt directly to test the return value
	var attacker: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("zapplet"), _data_loader)
	attacker.side = "player"
	attacker.row_position = "front"
	attacker.current_hp = 1  ## Will die to static_guard counter damage

	var defender: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("thunderclaw"), _data_loader)
	defender.side = "enemy"
	defender.row_position = "front"
	defender.is_guarding = true

	var static_guard_tech: TechniqueDef = _data_loader.get_technique("static_guard")
	var attack_tech: TechniqueDef = _data_loader.get_technique("vine_lash")  ## melee, triggers ON_MELEE

	var cancelled: bool = _engine._resolve_interrupt(defender, static_guard_tech, attacker, attack_tech)
	_assert(attacker.is_knocked_out, "static_guard KO: attacker is KO'd by interrupt damage")
	_assert(cancelled, "static_guard KO: _resolve_interrupt returns true (attack cancelled)")

	## Test 2: null_counter interrupt KOs attacker — attack should be cancelled
	var attacker2: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("mossling"), _data_loader)
	attacker2.side = "player"
	attacker2.row_position = "front"
	attacker2.current_hp = 1  ## Will die to null_counter

	var nullweaver: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("nullweaver"), _data_loader)
	nullweaver.side = "enemy"
	nullweaver.row_position = "front"
	nullweaver.is_guarding = true

	var null_counter_tech: TechniqueDef = _data_loader.get_technique("null_counter")

	var cancelled2: bool = _engine._resolve_interrupt(nullweaver, null_counter_tech, attacker2, attack_tech)
	_assert(attacker2.is_knocked_out, "null_counter KO: attacker is KO'd by interrupt damage")
	_assert(cancelled2, "null_counter KO: _resolve_interrupt returns true (attack cancelled)")

	## Test 3: static_guard interrupt that does NOT KO attacker — attack should still proceed
	var attacker3: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("stonepaw"), _data_loader)
	attacker3.side = "player"
	attacker3.row_position = "front"
	## Stonepaw has high HP (15), won't be KO'd by static_guard

	var defender3: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("thunderclaw"), _data_loader)
	defender3.side = "enemy"
	defender3.row_position = "front"
	defender3.is_guarding = true

	var cancelled3: bool = _engine._resolve_interrupt(defender3, static_guard_tech, attacker3, attack_tech)
	_assert(not attacker3.is_knocked_out, "non-lethal static_guard: attacker survives interrupt")
	_assert(not cancelled3, "non-lethal static_guard: _resolve_interrupt returns false (attack proceeds)")

	## Test 4: Full integration — static_guard KOs attacker, target takes no damage
	## Use start_battle + _execute_attack to test the full flow
	## Must use a melee attack technique since static_guard triggers ON_MELEE
	var atk4: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("zapplet"), _data_loader)
	var def4: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("thunderclaw"), _data_loader)

	var p_squad: Array[GlyphInstance] = [atk4]
	var e_squad: Array[GlyphInstance] = [def4]
	_engine.start_battle(p_squad, e_squad)
	## Manually set state instead of set_formation (which starts turns)
	_engine.phase = _engine.BattlePhase.TURN_ACTIVE
	atk4.row_position = "front"
	def4.row_position = "front"
	def4.is_guarding = true
	## Set HP to 1 AFTER start_battle (which resets combat state including HP)
	atk4.current_hp = 1

	var melee_tech: TechniqueDef = _data_loader.get_technique("jolt_rush")
	var def4_hp_before: int = def4.current_hp
	var tracking: Dictionary = {"tech_count": 0}
	var tech_handler: Callable = func(_u: GlyphInstance, _t: TechniqueDef, _tgt: GlyphInstance, _d: int) -> void:
		tracking["tech_count"] += 1
	_engine.technique_used.connect(tech_handler)

	_engine._execute_attack(atk4, melee_tech, def4)

	_assert(atk4.is_knocked_out, "full flow: attacker KO'd by static_guard interrupt")
	_assert(def4.current_hp == def4_hp_before, "full flow: target takes no damage when attacker KO'd by interrupt")
	## Only the interrupt technique fires, not the attack
	_assert(tracking["tech_count"] == 1, "full flow: only 1 technique_used (interrupt), got %d" % tracking["tech_count"])

	_engine.technique_used.disconnect(tech_handler)

	print("")


# --- Auto Battle Integration Test ---

func _test_auto_battle() -> void:
	print("--- Auto Battle Simulation ---")

	## Connect signals for event tracking
	_events.clear()
	_engine.battle_started.connect(_on_battle_started)
	_engine.turn_started.connect(_on_turn_started)
	_engine.technique_used.connect(_on_technique_used)
	_engine.glyph_ko.connect(_on_glyph_ko)
	_engine.status_applied.connect(_on_status_applied)
	_engine.status_expired.connect(_on_status_expired)
	_engine.burn_damage.connect(_on_burn_damage)
	_engine.guard_activated.connect(_on_guard)
	_engine.battle_won.connect(_on_battle_won)
	_engine.battle_lost.connect(_on_battle_lost)
	_engine.interrupt_triggered.connect(_on_interrupt)
	_engine.affinity_advantage_hit.connect(_on_affinity_advantage)
	_engine.round_started.connect(_on_round_started)

	## Create squads: Player (Zapplet, Stonepaw, Driftwisp) vs Enemy (Sparkfin, Mossling, Glitchkit)
	var p1: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("zapplet"), _data_loader)
	var p2: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("stonepaw"), _data_loader)
	var p3: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("driftwisp"), _data_loader)
	var e1: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("sparkfin"), _data_loader)
	var e2: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("mossling"), _data_loader)
	var e3: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("glitchkit"), _data_loader)

	var p_squad: Array[GlyphInstance] = [p1, p2, p3]
	var e_squad: Array[GlyphInstance] = [e1, e2, e3]

	_engine.auto_battle = true
	_engine.start_battle(p_squad, e_squad)
	_engine.set_formation()

	## Battle should have completed synchronously (all AI, no awaits)
	var ended: bool = _engine.phase == _engine.BattlePhase.VICTORY or _engine.phase == _engine.BattlePhase.DEFEAT
	_assert(ended, "Battle completed (phase = %d)" % _engine.phase)

	var is_victory: bool = _engine.phase == _engine.BattlePhase.VICTORY
	print("       Result: %s in %d turns" % ["VICTORY" if is_victory else "DEFEAT", _engine.turn_count])

	_assert(_engine.turn_count > 0, "Turn count > 0 (was %d)" % _engine.turn_count)
	_assert(_events.size() > 0, "Events were emitted (%d total)" % _events.size())

	## Verify at least some techniques were used
	var tech_events: int = 0
	for e: String in _events:
		if e.begins_with("TECHNIQUE:"):
			tech_events += 1
	_assert(tech_events > 0, "Techniques were used (%d times)" % tech_events)

	## Verify KOs happened
	var ko_events: int = 0
	for e: String in _events:
		if e.begins_with("KO:"):
			ko_events += 1
	_assert(ko_events > 0, "KOs occurred (%d)" % ko_events)

	## Print battle log summary
	print("")
	print("  --- Battle Log ---")
	for e: String in _events:
		print("  %s" % e)
	print("  --- End Log ---")

	## Disconnect signals
	_engine.battle_started.disconnect(_on_battle_started)
	_engine.turn_started.disconnect(_on_turn_started)
	_engine.technique_used.disconnect(_on_technique_used)
	_engine.glyph_ko.disconnect(_on_glyph_ko)
	_engine.status_applied.disconnect(_on_status_applied)
	_engine.status_expired.disconnect(_on_status_expired)
	_engine.burn_damage.disconnect(_on_burn_damage)
	_engine.guard_activated.disconnect(_on_guard)
	_engine.battle_won.disconnect(_on_battle_won)
	_engine.battle_lost.disconnect(_on_battle_lost)
	_engine.interrupt_triggered.disconnect(_on_interrupt)
	_engine.affinity_advantage_hit.disconnect(_on_affinity_advantage)
	_engine.round_started.disconnect(_on_round_started)

	print("")


# --- Signal Handlers ---

func _on_battle_started(_p: Array[GlyphInstance], _e: Array[GlyphInstance]) -> void:
	_events.append("BATTLE START: %d vs %d" % [_p.size(), _e.size()])

func _on_round_started(round_num: int) -> void:
	_events.append("ROUND %d" % round_num)

func _on_turn_started(glyph: GlyphInstance, turn_idx: int) -> void:
	_events.append("TURN %d: %s (%s) [HP %d/%d]" % [turn_idx, glyph.species.name, glyph.side, glyph.current_hp, glyph.max_hp])

func _test_boss_variety() -> void:
	print("--- Boss Variety ---")

	## Test: all bosses have squads
	var bosses: Array = _data_loader.bosses.values()
	for boss_def: BossDef in bosses:
		_assert(boss_def.squad.size() >= 2, "Boss %s has squad with %d members (>= 2)" % [boss_def.species_id, boss_def.squad.size()])

	## Test: all squad technique IDs are valid
	for boss_def: BossDef in bosses:
		for entry: Dictionary in boss_def.squad:
			for tid: String in entry.get("technique_ids", []):
				var tech: TechniqueDef = _data_loader.get_technique(tid)
				_assert(tech != null, "Boss %s squad member %s technique '%s' exists" % [boss_def.species_id, entry["species_id"], tid])

	## Test: all squad species IDs are valid
	for boss_def: BossDef in bosses:
		for entry: Dictionary in boss_def.squad:
			var species: GlyphSpecies = _data_loader.get_species(entry["species_id"])
			_assert(species != null, "Boss %s squad member '%s' is a valid species" % [boss_def.species_id, entry["species_id"]])

	## Test: varied stat bonuses — not all identical
	var bonus_strings: Array[String] = []
	for boss_def: BossDef in bosses:
		var s: String = str(boss_def.phase2_stat_bonus)
		if not bonus_strings.has(s):
			bonus_strings.append(s)
	_assert(bonus_strings.size() >= 3, "At least 3 distinct phase2_stat_bonus configs (got %d)" % bonus_strings.size())

	## Test: DEF bonus applies correctly in phase transition
	var ironbark_def: BossDef = _data_loader.get_boss("minor_01")
	_assert(ironbark_def.phase2_stat_bonus.has("def"), "Ironbark boss has DEF phase2 bonus")

	var boss_species: GlyphSpecies = _data_loader.get_species(ironbark_def.species_id)
	var boss: GlyphInstance = GlyphInstance.create_from_species(boss_species, _data_loader)
	boss.is_boss = true
	boss.boss_phase = 1
	for tid: String in ironbark_def.phase1_technique_ids:
		var tech: TechniqueDef = _data_loader.get_technique(tid)
		if tech != null:
			boss.techniques.append(tech)

	var pre_def: int = boss.def_stat
	boss.current_hp = boss.max_hp / 2
	_engine._boss = boss
	_engine._boss_def = ironbark_def
	_engine._check_boss_phase_transition(boss)
	_assert(boss.boss_phase == 2, "Boss entered phase 2")
	_assert(boss.def_stat > pre_def, "Boss DEF increased from %d to %d after phase 2" % [pre_def, boss.def_stat])

	## Test: boss with only ATK bonus doesn't change DEF
	var apex_def: BossDef = _data_loader.get_boss("apex_01")
	var nw_sp: GlyphSpecies = _data_loader.get_species(apex_def.species_id)
	var nw_boss: GlyphInstance = GlyphInstance.create_from_species(nw_sp, _data_loader)
	nw_boss.is_boss = true
	nw_boss.boss_phase = 1
	for tid: String in apex_def.phase1_technique_ids:
		var tech: TechniqueDef = _data_loader.get_technique(tid)
		if tech != null:
			nw_boss.techniques.append(tech)
	var nw_pre_def: int = nw_boss.def_stat
	var nw_pre_atk: int = nw_boss.atk
	nw_boss.current_hp = nw_boss.max_hp / 2
	_engine._boss = nw_boss
	_engine._boss_def = apex_def
	_engine._check_boss_phase_transition(nw_boss)
	_assert(nw_boss.boss_phase == 2, "Nullweaver entered phase 2")
	_assert(nw_boss.atk > nw_pre_atk, "Nullweaver ATK increased (had 20%% ATK bonus)")
	_assert(nw_boss.def_stat == nw_pre_def, "Nullweaver DEF unchanged (no DEF bonus)")

	## Test: RES bonus for standard_02 terradon
	var terra_def: BossDef = _data_loader.get_boss("standard_02")
	_assert(terra_def.phase2_stat_bonus.has("res"), "Terradon boss has RES phase2 bonus")
	_assert(terra_def.phase2_stat_bonus.has("def"), "Terradon boss has DEF phase2 bonus")

	## Clean up engine state
	_engine._boss = null
	_engine._boss_def = null


func _on_technique_used(user: GlyphInstance, technique: TechniqueDef, target: GlyphInstance, damage: int) -> void:
	_events.append("TECHNIQUE: %s uses %s on %s → %d dmg" % [user.species.name, technique.name, target.species.name, damage])

func _on_glyph_ko(glyph: GlyphInstance, attacker: GlyphInstance) -> void:
	var atk_name: String = attacker.species.name if attacker != null else "burn"
	_events.append("KO: %s (%s) knocked out by %s" % [glyph.species.name, glyph.side, atk_name])

func _on_status_applied(target: GlyphInstance, status_id: String) -> void:
	_events.append("STATUS: %s applied to %s" % [status_id, target.species.name])

func _on_status_expired(target: GlyphInstance, status_id: String) -> void:
	_events.append("EXPIRED: %s on %s" % [status_id, target.species.name])

func _on_burn_damage(glyph: GlyphInstance, damage: int) -> void:
	_events.append("BURN: %s takes %d burn damage [HP %d/%d]" % [glyph.species.name, damage, glyph.current_hp, glyph.max_hp])

func _on_guard(glyph: GlyphInstance) -> void:
	_events.append("GUARD: %s is guarding" % glyph.species.name)

func _on_battle_won(_p: Array[GlyphInstance], turns: int, kos: Array[GlyphInstance]) -> void:
	_events.append("VICTORY in %d turns (%d KOs)" % [turns, kos.size()])

func _on_battle_lost(_p: Array[GlyphInstance]) -> void:
	_events.append("DEFEAT")

func _on_interrupt(defender: GlyphInstance, technique: TechniqueDef, attacker: GlyphInstance) -> void:
	_events.append("INTERRUPT: %s triggers %s against %s" % [defender.species.name, technique.name, attacker.species.name])

func _on_affinity_advantage(attacker: GlyphInstance, target: GlyphInstance) -> void:
	_events.append("ADVANTAGE: %s (%s) vs %s (%s)" % [attacker.species.name, attacker.species.affinity, target.species.name, target.species.affinity])
