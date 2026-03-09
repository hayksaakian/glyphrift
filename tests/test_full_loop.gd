extends SceneTree

## GLYPHRIFT — Interactive Text Adventure (Session 5)
## Run: ~/bin/godot --headless --script res://tests/test_full_loop.gd

var _dl: Node = null
var _engine: Node = null
var _fusion: FusionEngine = null
var _codex: CodexState = null
var _roster: RosterState = null
var _crawler: CrawlerState = null
var _game: GameState = null
var _tracker: MasteryTracker = null

var _extracted: bool = false
var _capture_bonus: float = 0.0
var _prev_room_id: String = ""


func _init() -> void:
	## DataLoader
	var dl_script: GDScript = load("res://core/data_loader.gd") as GDScript
	_dl = dl_script.new() as Node
	_dl.name = "DataLoader"
	root.add_child(_dl)

	## CombatEngine
	var ce_script: GDScript = load("res://core/combat/combat_engine.gd") as GDScript
	_engine = ce_script.new() as Node
	_engine.name = "CombatEngine"
	_engine.data_loader = _dl
	_engine.auto_battle = false
	root.add_child(_engine)

	## FusionEngine
	_fusion = FusionEngine.new()
	_fusion.name = "FusionEngine"
	_fusion.data_loader = _dl
	root.add_child(_fusion)

	## CodexState
	_codex = CodexState.new()
	_codex.name = "CodexState"
	root.add_child(_codex)

	## RosterState
	_roster = RosterState.new()
	_roster.name = "RosterState"
	root.add_child(_roster)

	## CrawlerState
	_crawler = CrawlerState.new()
	_crawler.name = "CrawlerState"
	root.add_child(_crawler)

	## Wire FusionEngine
	_fusion.codex_state = _codex
	_fusion.roster_state = _roster

	## GameState
	_game = GameState.new()
	_game.name = "GameState"
	_game.data_loader = _dl
	_game.roster_state = _roster
	_game.codex_state = _codex
	_game.crawler_state = _crawler
	_game.combat_engine = _engine
	_game.fusion_engine = _fusion
	root.add_child(_game)

	## MasteryTracker — connect once, stays connected
	_tracker = MasteryTracker.new()
	_tracker.connect_to_combat(_engine)

	await process_frame
	_title_screen()
	quit()


# ============================================================
#  TITLE SCREEN
# ============================================================

func _title_screen() -> void:
	print("")
	print("╔══════════════════════════════════════╗")
	print("║          G L Y P H R I F T           ║")
	print("║   Dungeon-Crawling Monster Fusion     ║")
	print("╚══════════════════════════════════════╝")
	print("")
	print("  1. New Game")
	print("  2. Quit")
	print("")
	var choice: String = _prompt("Choose: ")
	match choice:
		"1":
			_game.start_new_game()
			_bastion_loop()
		_:
			print("Goodbye!")


# ============================================================
#  BASTION LOOP
# ============================================================

func _bastion_loop() -> void:
	while true:
		print("")
		print("========================================")
		print("  BASTION  (Phase %d)" % _game.game_phase)
		print("========================================")
		print("  1. Enter Rift")
		print("  2. Manage Squad")
		print("  3. Fuse Glyphs")
		print("  4. View Codex")
		print("  5. View Crawler")
		print("  6. Quit")
		print("")
		var choice: String = _prompt("Choose: ")
		match choice:
			"1":
				_enter_rift()
			"2":
				_manage_squad()
			"3":
				_fuse_glyphs()
			"4":
				_view_codex()
			"5":
				_view_crawler()
			"6":
				print("Goodbye!")
				return
			_:
				print("Invalid choice.")


# ============================================================
#  ENTER RIFT
# ============================================================

func _enter_rift() -> void:
	var rifts: Array[RiftTemplate] = _game.get_available_rifts()
	if rifts.is_empty():
		print("No rifts available.")
		return

	print("")
	print("--- Available Rifts ---")
	for i: int in range(rifts.size()):
		var t: RiftTemplate = rifts[i]
		var cleared_tag: String = " [CLEARED]" if _codex.is_rift_cleared(t.rift_id) else ""
		print("  %d. %s (%s)%s" % [i + 1, t.name, t.tier, cleared_tag])
	print("  0. Back")
	print("")
	var choice: String = _prompt("Choose rift: ")
	var idx: int = int(choice) - 1
	if idx < 0 or idx >= rifts.size():
		return

	_extracted = false
	_game.start_rift(rifts[idx])
	_game.current_dungeon.forced_extraction.connect(_on_forced_extraction)
	_game.current_dungeon.crawler_damaged.connect(_on_crawler_damaged)
	print("")
	print("Entering %s..." % rifts[idx].name)
	_dungeon_loop(rifts[idx])


func _on_forced_extraction() -> void:
	_extracted = true


func _on_crawler_damaged(amount: int, remaining_hp: int) -> void:
	print("  Hazard! Hull takes %d damage. (Hull: %d/%d)" % [amount, remaining_hp, _crawler.max_hull_hp])


# ============================================================
#  DUNGEON LOOP
# ============================================================

func _dungeon_loop(template: RiftTemplate) -> void:
	while not _extracted:
		var dungeon: DungeonState = _game.current_dungeon
		if dungeon == null:
			break
		var room: Dictionary = dungeon.get_current_room()
		if room.is_empty():
			break

		print("")
		print("--- Floor %d | Room %s | Type: %s ---" % [
			dungeon.current_floor, room["id"], room["type"]])
		print("  Crawler: Hull %d/%d | Energy %d/%d" % [
			_crawler.hull_hp, _crawler.max_hull_hp,
			_crawler.energy, _crawler.max_energy])

		## Handle room effects
		_handle_room(room, template)

		if _extracted:
			print("")
			print("*** FORCED EXTRACTION — Hull destroyed! ***")
			_game.current_dungeon = null
			_game.transition_to(GameState.State.BASTION)
			break

		## Navigation
		var adjacent: Array[Dictionary] = dungeon.get_adjacent_rooms()
		if adjacent.is_empty():
			print("  No exits from this room.")
			print("  Rift exploration complete!")
			break

		print("")
		print("  Adjacent rooms:")
		for i: int in range(adjacent.size()):
			var adj: Dictionary = adjacent[i]
			var type_label: String = adj["type"] if adj["revealed"] else "???"
			var visited_tag: String = " (visited)" if adj["visited"] else ""
			print("    %d. %s [%s]%s" % [i + 1, adj["id"], type_label, visited_tag])

		## Crawler abilities & items
		print("    S. Scan (%d energy)" % _crawler.get_ability_cost("scan"))
		print("    R. Reinforce (%d energy)" % _crawler.get_ability_cost("reinforce"))
		print("    F. Field Repair (%d energy)" % _crawler.get_ability_cost("field_repair"))
		print("    P. Purge hazard (%d energy)" % _crawler.get_ability_cost("purge"))
		print("    W. Emergency Warp (%d energy)" % _crawler.get_ability_cost("emergency_warp"))
		if not _crawler.items.is_empty():
			print("    I. Use Item (%d in cargo)" % _crawler.items.size())
		print("    0. Flee rift (return to Bastion)")
		print("")

		var choice: String = _prompt("Move to: ")

		if choice.to_lower() == "i":
			_use_item()
			continue
		elif choice.to_lower() == "f":
			_use_field_repair(dungeon)
			continue
		elif choice.to_lower() == "p":
			if dungeon.use_crawler_ability("purge"):
				print("  Purged an adjacent hazard room!")
			else:
				print("  Not enough energy or no adjacent hazard to purge.")
			continue
		elif choice.to_lower() == "s":
			if dungeon.use_crawler_ability("scan"):
				print("  Scanning... adjacent rooms revealed!")
			else:
				print("  Not enough energy!")
			continue
		elif choice.to_lower() == "r":
			if dungeon.use_crawler_ability("reinforce"):
				print("  Hull reinforced for next hazard.")
			else:
				print("  Not enough energy!")
			continue
		elif choice.to_lower() == "w":
			if dungeon.use_crawler_ability("emergency_warp"):
				print("  Emergency warp activated!")
			continue
		elif choice == "0":
			print("  Fleeing rift...")
			_game.current_dungeon = null
			_game.transition_to(GameState.State.BASTION)
			break

		var move_idx: int = int(choice) - 1
		if move_idx < 0 or move_idx >= adjacent.size():
			print("  Invalid choice.")
			continue

		_prev_room_id = dungeon.current_room_id
		var _was_reinforced: bool = _crawler.is_reinforced
		var target_type: String = adjacent[move_idx].get("type", "")
		dungeon.move_to_room(adjacent[move_idx]["id"])
		## Check if reinforced blocked a hazard (flag consumed by move_to_room)
		if _was_reinforced and not _crawler.is_reinforced:
			print("  Hazard! But hull was reinforced — no damage.")
		## Exit rooms now emit exit_reached — descend to next floor
		if target_type == "exit":
			print("  Descending to next floor...")
			dungeon.descend()


func _handle_room(room: Dictionary, template: RiftTemplate) -> void:
	var room_type: String = room["type"]

	if room.get("battle_done", false) and room_type in ["enemy", "boss"]:
		print("  (Battle already completed here)")
		return
	if room.get("looted", false) and room_type == "cache":
		print("  (Already looted)")
		return

	match room_type:
		"enemy":
			print("  Wild glyphs appear!")
			var enemies: Array[GlyphInstance] = _generate_wild_enemies(template)
			var won: bool = _run_combat(enemies, false, template)
			if won:
				room["battle_done"] = true
			else:
				## GDD 8.13: Push back to previous room, crawler takes 15 hull damage
				## Enemy resets (battle_done NOT set, so re-entry triggers new fight)
				_handle_battle_loss()
		"boss":
			print("  BOSS ENCOUNTER!")
			var boss_def: BossDef = _dl.get_boss(template.rift_id)
			var boss: GlyphInstance = _create_boss(boss_def)
			var enemies: Array[GlyphInstance] = [boss]
			var won: bool = _run_combat(enemies, true, template, boss_def)
			if won:
				room["battle_done"] = true
				print("")
				print("  *** RIFT CLEARED: %s ***" % template.name)
				_game.complete_rift(template.rift_id)
				_extracted = true
			else:
				_handle_battle_loss()
		"cache":
			var item_keys: Array = _dl.items.keys()
			var item_id: String = item_keys[randi() % item_keys.size()]
			var item: ItemDef = _dl.get_item(item_id)
			if _crawler.add_item(item):
				print("  Found: %s — %s" % [item.name, item.description])
			else:
				print("  Found %s but cargo is full!" % item.name)
			room["looted"] = true
		"hazard":
			pass  ## Damage handled by DungeonState; display via signals + reinforced check
		"start", "exit", "empty", "hidden", "puzzle":
			print("  Nothing happens here.")


# ============================================================
#  WILD ENEMY GENERATION
# ============================================================

func _generate_wild_enemies(template: RiftTemplate) -> Array[GlyphInstance]:
	var count: int = randi_range(1, 3)
	var enemies: Array[GlyphInstance] = []
	var pool: Array[String] = []
	## Filter pool to species whose tier is in the enemy_tier_pool
	for sid: String in template.wild_glyph_pool:
		var sp: GlyphSpecies = _dl.get_species(sid)
		if sp.tier in template.enemy_tier_pool:
			pool.append(sid)
	if pool.is_empty():
		pool = template.wild_glyph_pool.duplicate()
	for i: int in range(count):
		var sid: String = pool[randi() % pool.size()]
		var g: GlyphInstance = GlyphInstance.create_from_species(_dl.get_species(sid), _dl)
		enemies.append(g)
	return enemies


func _create_boss(boss_def: BossDef) -> GlyphInstance:
	var sp: GlyphSpecies = _dl.get_species(boss_def.species_id)
	var boss: GlyphInstance = GlyphInstance.new()
	boss.species = sp
	boss.is_boss = true
	## Apply mastery stars: each star = +2 all stats
	var stars: int = boss_def.mastery_stars
	if stars > 0:
		boss.bonus_hp = stars * 2
		boss.bonus_atk = stars * 2
		boss.bonus_def = stars * 2
		boss.bonus_spd = stars * 2
		boss.bonus_res = stars * 2
	boss.calculate_stats()
	## Phase 1 techniques
	for tid: String in boss_def.phase1_technique_ids:
		var tech: TechniqueDef = _dl.get_technique(tid)
		if tech != null:
			boss.techniques.append(tech)
	return boss


# ============================================================
#  COMBAT
# ============================================================

func _run_combat(
	enemies: Array[GlyphInstance],
	is_boss: bool,
	template: RiftTemplate,
	boss_def: BossDef = null
) -> bool:
	## Filter squad to alive glyphs
	var squad: Array[GlyphInstance] = []
	for g: GlyphInstance in _roster.active_squad:
		if g.current_hp > 0 and not g.is_knocked_out:
			squad.append(g)
	if squad.is_empty():
		print("  No healthy glyphs available!")
		return false

	print("")
	print("  ---- COMBAT %s ----" % ("(BOSS)" if is_boss else ""))
	print("  Your squad:")
	for g: GlyphInstance in squad:
		print("    %s [%s T%d] HP: %d/%d" % [
			g.species.name, g.species.affinity, g.species.tier,
			g.current_hp, g.max_hp])
	print("  Enemies:")
	for e: GlyphInstance in enemies:
		print("    %s [%s T%d] HP: %d/%d" % [
			e.species.name, e.species.affinity, e.species.tier,
			e.current_hp, e.max_hp])

	## Connect display signals
	var _cbs: Array[Callable] = []
	_connect_combat_display(_cbs)

	## Start battle
	_engine.start_battle(squad, enemies, boss_def)
	_engine.set_formation()

	## Main combat loop — engine auto-advances enemy turns
	## For player turns, we pause here and wait for input
	while _engine.phase == _engine.BattlePhase.TURN_ACTIVE:
		if _engine.current_actor == null:
			break
		if _engine.current_actor.side == "player":
			_player_combat_turn()
		else:
			## This shouldn't happen since engine auto-resolves enemy turns
			## But just in case, force advance
			break

	## Disconnect display signals
	_disconnect_combat_display(_cbs)

	var won: bool = _engine.phase == _engine.BattlePhase.VICTORY
	if won:
		print("  VICTORY!")
		## Show mastery progress
		_show_mastery_progress(squad)
		## Capture roll
		if not is_boss:
			_attempt_capture(enemies, template)
	else:
		print("  DEFEAT!")
		_capture_bonus = 0.0

	## GDD 8.12: KO'd glyphs revive at 30% max HP after every battle
	_revive_kos()

	return won


func _player_combat_turn() -> void:
	var actor: GlyphInstance = _engine.current_actor
	print("")
	print("  >> %s's turn (HP: %d/%d) <<" % [actor.species.name, actor.current_hp, actor.max_hp])

	## List available techniques
	var available: Array[TechniqueDef] = []
	for tech: TechniqueDef in actor.techniques:
		if tech.category == "interrupt":
			continue
		if not actor.is_technique_ready(tech):
			continue
		if tech.range_type == "melee" and actor.row_position == "back":
			continue
		available.append(tech)

	for i: int in range(available.size()):
		var t: TechniqueDef = available[i]
		var cd_text: String = " (CD:%d)" % t.cooldown if t.cooldown > 0 else ""
		print("    %d. %s [%s %s pw:%d]%s" % [
			i + 1, t.name, t.affinity, t.range_type, t.power, cd_text])
	print("    G. Guard")
	print("")

	var choice: String = _prompt("  Action: ")

	if choice.to_lower() == "g":
		_engine.submit_action({"action": "guard"})
		return

	var tech_idx: int = int(choice) - 1
	if tech_idx < 0 or tech_idx >= available.size():
		## Default to first technique
		tech_idx = 0

	var technique: TechniqueDef = available[tech_idx]

	## Pick target
	if technique.category == "support":
		## Target ally
		var allies: Array[GlyphInstance] = []
		for g: GlyphInstance in _engine.player_squad:
			if not g.is_knocked_out:
				allies.append(g)
		if allies.size() == 1:
			_engine.submit_action({"action": "attack", "technique": technique, "target": allies[0]})
			return
		print("  Target ally:")
		for i: int in range(allies.size()):
			print("    %d. %s (HP: %d/%d)" % [i + 1, allies[i].species.name, allies[i].current_hp, allies[i].max_hp])
		var target_choice: String = _prompt("  Target: ")
		var t_idx: int = int(target_choice) - 1
		if t_idx < 0 or t_idx >= allies.size():
			t_idx = 0
		_engine.submit_action({"action": "attack", "technique": technique, "target": allies[t_idx]})
	else:
		## Target enemy
		var alive_enemies: Array[GlyphInstance] = []
		for e: GlyphInstance in _engine.enemy_squad:
			if not e.is_knocked_out:
				alive_enemies.append(e)
		if alive_enemies.size() == 1:
			_engine.submit_action({"action": "attack", "technique": technique, "target": alive_enemies[0]})
			return
		print("  Target enemy:")
		for i: int in range(alive_enemies.size()):
			print("    %d. %s (HP: %d/%d)" % [i + 1, alive_enemies[i].species.name, alive_enemies[i].current_hp, alive_enemies[i].max_hp])
		var target_choice: String = _prompt("  Target: ")
		var t_idx: int = int(target_choice) - 1
		if t_idx < 0 or t_idx >= alive_enemies.size():
			t_idx = 0
		_engine.submit_action({"action": "attack", "technique": technique, "target": alive_enemies[t_idx]})


func _connect_combat_display(cbs: Array[Callable]) -> void:
	var cb_tech: Callable = func(user: GlyphInstance, tech: TechniqueDef, target: GlyphInstance, dmg: int) -> void:
		if dmg > 0:
			print("    %s uses %s on %s for %d damage!" % [user.species.name, tech.name, target.species.name, dmg])
		else:
			print("    %s uses %s on %s." % [user.species.name, tech.name, target.species.name])
	_engine.technique_used.connect(cb_tech)
	cbs.append(cb_tech)

	var cb_ko: Callable = func(glyph: GlyphInstance, _attacker: GlyphInstance) -> void:
		print("    %s is knocked out!" % glyph.species.name)
	_engine.glyph_ko.connect(cb_ko)
	cbs.append(cb_ko)

	var cb_phase: Callable = func(boss: GlyphInstance) -> void:
		print("    !! %s enters PHASE 2 !!" % boss.species.name)
	_engine.phase_transition.connect(cb_phase)
	cbs.append(cb_phase)

	var cb_round: Callable = func(r: int) -> void:
		print("  — Round %d —" % r)
	_engine.round_started.connect(cb_round)
	cbs.append(cb_round)

	var cb_guard: Callable = func(g: GlyphInstance) -> void:
		print("    %s guards." % g.species.name)
	_engine.guard_activated.connect(cb_guard)
	cbs.append(cb_guard)

	var cb_status: Callable = func(target: GlyphInstance, status_id: String) -> void:
		print("    %s is afflicted with %s!" % [target.species.name, status_id])
	_engine.status_applied.connect(cb_status)
	cbs.append(cb_status)

	var cb_burn: Callable = func(g: GlyphInstance, dmg: int) -> void:
		print("    %s takes %d burn damage!" % [g.species.name, dmg])
	_engine.burn_damage.connect(cb_burn)
	cbs.append(cb_burn)

	var cb_interrupt: Callable = func(defender: GlyphInstance, tech: TechniqueDef, _attacker: GlyphInstance) -> void:
		print("    %s triggers %s!" % [defender.species.name, tech.name])
	_engine.interrupt_triggered.connect(cb_interrupt)
	cbs.append(cb_interrupt)


func _disconnect_combat_display(cbs: Array[Callable]) -> void:
	var signals_to_disconnect: Array[Signal] = [
		_engine.technique_used,
		_engine.glyph_ko,
		_engine.phase_transition,
		_engine.round_started,
		_engine.guard_activated,
		_engine.status_applied,
		_engine.burn_damage,
		_engine.interrupt_triggered,
	]
	for i: int in range(mini(cbs.size(), signals_to_disconnect.size())):
		if signals_to_disconnect[i].is_connected(cbs[i]):
			signals_to_disconnect[i].disconnect(cbs[i])


func _use_field_repair(dungeon: DungeonState) -> void:
	## GDD 4.2: Field Repair — 10 energy, restores 50% HP to one glyph
	var cost: int = _crawler.get_ability_cost("field_repair")
	if _crawler.energy < cost:
		print("  Not enough energy! (need %d, have %d)" % [cost, _crawler.energy])
		return
	var target: GlyphInstance = _pick_glyph_target("repair")
	if target == null:
		print("  Cancelled.")
		return
	dungeon.use_crawler_ability("field_repair")
	var heal: int = maxi(1, int(float(target.max_hp) * 0.5))
	target.current_hp = mini(target.current_hp + heal, target.max_hp)
	if target.is_knocked_out:
		target.is_knocked_out = false
	print("  Field Repair: %s healed for %d HP! (HP: %d/%d)" % [
		target.species.name, heal, target.current_hp, target.max_hp])


func _handle_battle_loss() -> void:
	## GDD 8.13: Push back to previous room, crawler takes 15 hull damage
	print("  Your squad was defeated! Emergency retreat...")
	_crawler.take_hull_damage(15)
	print("  Crawler takes 15 hull damage (Hull: %d/%d)." % [_crawler.hull_hp, _crawler.max_hull_hp])
	if _crawler.hull_hp <= 0:
		_extracted = true
		return
	## Push back to previous room
	var dungeon: DungeonState = _game.current_dungeon
	if dungeon != null and _prev_room_id != "":
		dungeon.current_room_id = _prev_room_id
		print("  Pushed back to room %s." % _prev_room_id)


func _revive_kos() -> void:
	## GDD 8.12: After every battle, KO'd glyphs revive at 30% max HP
	for g: GlyphInstance in _roster.active_squad:
		if g.is_knocked_out:
			g.is_knocked_out = false
			g.current_hp = maxi(1, int(float(g.max_hp) * 0.3))
			print("    %s revived at %d HP." % [g.species.name, g.current_hp])


func _show_mastery_progress(squad: Array[GlyphInstance]) -> void:
	print("  --- Mastery Progress ---")
	for g: GlyphInstance in squad:
		if g.is_mastered:
			print("    %s: MASTERED" % g.species.name)
			continue
		if g.mastery_objectives.is_empty():
			continue
		var completed: int = 0
		for obj: Dictionary in g.mastery_objectives:
			if obj.get("completed", false):
				completed += 1
		print("    %s: %d/%d objectives" % [g.species.name, completed, g.mastery_objectives.size()])
		for obj: Dictionary in g.mastery_objectives:
			var mark: String = "x" if obj.get("completed", false) else " "
			print("      [%s] %s" % [mark, obj.get("description", obj["type"])])


func _attempt_capture(enemies: Array[GlyphInstance], template: RiftTemplate) -> void:
	## Pick a random surviving enemy species to capture
	var capturable: Array[GlyphInstance] = []
	for e: GlyphInstance in enemies:
		capturable.append(e)
	if capturable.is_empty():
		return

	var target: GlyphInstance = capturable[randi() % capturable.size()]

	var chance: float = CaptureCalculator.calculate_chance(
		enemies.size(), _engine.turn_count)
	chance = minf(CaptureCalculator.MAX_CHANCE, chance + _capture_bonus)
	_capture_bonus = 0.0
	var roll: float = randf()
	var captured: bool = roll <= chance

	print("  Capture attempt on %s (%.0f%% chance)..." % [target.species.name, chance * 100.0])

	if captured:
		print("  CAPTURED %s!" % target.species.name)
		var new_glyph: GlyphInstance = GlyphInstance.create_from_species(target.species, _dl)
		new_glyph.mastery_objectives = MasteryTracker.build_mastery_track(target.species, _dl.mastery_pools)
		var max_roster: int = _crawler.slots + _crawler.cargo_slots
		if _roster.get_glyph_count() >= max_roster:
			## GDD: Cargo full — swap or leave
			print("  Roster full! (%d/%d)" % [_roster.get_glyph_count(), max_roster])
			print("  Swap with an existing glyph, or leave the capture?")
			for i: int in range(_roster.all_glyphs.size()):
				var g: GlyphInstance = _roster.all_glyphs[i]
				var in_squad: String = " *" if _roster.active_squad.has(g) else ""
				print("    %d. Release %s [%s T%d]%s" % [
					i + 1, g.species.name, g.species.affinity, g.species.tier, in_squad])
			print("    0. Leave (abandon capture)")
			var swap_choice: String = _prompt("  Swap: ")
			var swap_idx: int = int(swap_choice) - 1
			if swap_idx < 0 or swap_idx >= _roster.all_glyphs.size():
				print("  Capture abandoned.")
				return
			var released: GlyphInstance = _roster.all_glyphs[swap_idx]
			print("  Released %s." % released.species.name)
			_roster.remove_glyph(released)
		_roster.add_glyph(new_glyph)
		_codex.discover_species(target.species.id)
	else:
		print("  %s escaped! (rolled %.2f > %.2f)" % [target.species.name, roll, chance])


# ============================================================
#  MANAGE SQUAD
# ============================================================

func _manage_squad() -> void:
	while true:
		print("")
		print("--- Squad Management ---")
		print("  Active squad:")
		for i: int in range(_roster.active_squad.size()):
			var g: GlyphInstance = _roster.active_squad[i]
			var mastered_tag: String = " [MASTERED]" if g.is_mastered else ""
			print("    %d. %s [%s T%d] HP: %d/%d GP: %d%s" % [
				i + 1, g.species.name, g.species.affinity, g.species.tier,
				g.current_hp, g.max_hp, g.get_gp_cost(), mastered_tag])
		print("")
		print("  All glyphs: %d | Capacity: %d/%d GP" % [
			_roster.get_glyph_count(),
			_get_squad_gp(), _crawler.capacity])
		print("")
		print("  1. Set active squad")
		print("  2. Heal all glyphs")
		print("  3. View all glyphs")
		print("  0. Back")
		print("")
		var choice: String = _prompt("Choose: ")
		match choice:
			"1":
				_set_active_squad()
			"2":
				_heal_all()
			"3":
				_view_all_glyphs()
			"0":
				return
			_:
				print("Invalid choice.")


func _set_active_squad() -> void:
	print("")
	print("  Available glyphs:")
	for i: int in range(_roster.all_glyphs.size()):
		var g: GlyphInstance = _roster.all_glyphs[i]
		var in_squad: String = " *" if _roster.active_squad.has(g) else ""
		print("    %d. %s [%s T%d] HP: %d/%d GP: %d%s" % [
			i + 1, g.species.name, g.species.affinity, g.species.tier,
			g.current_hp, g.max_hp, g.get_gp_cost(), in_squad])
	print("")
	print("  Enter up to %d glyph numbers separated by spaces:" % _crawler.slots)
	var input: String = _prompt("  Squad: ")
	var parts: PackedStringArray = input.split(" ", false)
	var new_squad: Array[GlyphInstance] = []
	var total_gp: int = 0
	for part: String in parts:
		var idx: int = int(part) - 1
		if idx >= 0 and idx < _roster.all_glyphs.size():
			var g: GlyphInstance = _roster.all_glyphs[idx]
			if new_squad.size() < _crawler.slots:
				if total_gp + g.get_gp_cost() <= _crawler.capacity:
					new_squad.append(g)
					total_gp += g.get_gp_cost()
				else:
					print("  %s exceeds GP capacity." % g.species.name)
	if new_squad.size() > 0:
		_roster.set_active_squad(new_squad)
		print("  Squad updated! (%d GP / %d capacity)" % [total_gp, _crawler.capacity])
	else:
		print("  No valid glyphs selected.")


func _heal_all() -> void:
	for g: GlyphInstance in _roster.all_glyphs:
		g.current_hp = g.max_hp
		g.is_knocked_out = false
		g.active_statuses.clear()
		g.cooldowns.clear()
	print("  All glyphs healed!")


func _view_all_glyphs() -> void:
	print("")
	print("  --- All Glyphs ---")
	for i: int in range(_roster.all_glyphs.size()):
		var g: GlyphInstance = _roster.all_glyphs[i]
		var mastered_tag: String = " [MASTERED]" if g.is_mastered else ""
		var in_squad: String = " *" if _roster.active_squad.has(g) else ""
		print("    %d. %s [%s T%d] HP: %d/%d ATK:%d DEF:%d SPD:%d RES:%d GP:%d%s%s" % [
			i + 1, g.species.name, g.species.affinity, g.species.tier,
			g.current_hp, g.max_hp, g.atk, g.def_stat, g.spd, g.res,
			g.get_gp_cost(), mastered_tag, in_squad])


func _get_squad_gp() -> int:
	var total: int = 0
	for g: GlyphInstance in _roster.active_squad:
		total += g.get_gp_cost()
	return total


# ============================================================
#  FUSE GLYPHS
# ============================================================

func _fuse_glyphs() -> void:
	var mastered: Array[GlyphInstance] = _roster.get_mastered_glyphs()
	if mastered.size() < 2:
		print("  Need at least 2 mastered glyphs to fuse. Have: %d" % mastered.size())
		return

	print("")
	print("--- Fusion ---")
	print("  Mastered glyphs:")
	for i: int in range(mastered.size()):
		var g: GlyphInstance = mastered[i]
		print("    %d. %s [%s T%d]" % [i + 1, g.species.name, g.species.affinity, g.species.tier])

	print("")
	var a_choice: String = _prompt("  Select first parent (number): ")
	var a_idx: int = int(a_choice) - 1
	if a_idx < 0 or a_idx >= mastered.size():
		print("  Invalid selection.")
		return
	var parent_a: GlyphInstance = mastered[a_idx]

	var b_choice: String = _prompt("  Select second parent (number): ")
	var b_idx: int = int(b_choice) - 1
	if b_idx < 0 or b_idx >= mastered.size() or b_idx == a_idx:
		print("  Invalid selection.")
		return
	var parent_b: GlyphInstance = mastered[b_idx]

	var check: Dictionary = _fusion.can_fuse(parent_a, parent_b)
	if not check["valid"]:
		print("  Cannot fuse: %s" % check["reason"])
		return

	var preview: Dictionary = _fusion.preview_fusion(parent_a, parent_b)
	print("")
	print("  Fusion result: %s (T%d %s)" % [
		preview["result_species_name"], preview["result_tier"], preview["result_affinity"]])
	print("  Stat bonuses: HP+%d ATK+%d DEF+%d SPD+%d RES+%d" % [
		preview["inheritance_bonuses"]["hp"],
		preview["inheritance_bonuses"]["atk"],
		preview["inheritance_bonuses"]["def"],
		preview["inheritance_bonuses"]["spd"],
		preview["inheritance_bonuses"]["res"]])

	## Technique inheritance
	var slots: int = preview["num_technique_slots"]
	var inherited_ids: Array[String] = []
	if slots > 0:
		var inheritable_a: Array[TechniqueDef] = preview["inheritable_techniques_a"]
		var inheritable_b: Array[TechniqueDef] = preview["inheritable_techniques_b"]
		var all_inheritable: Array[TechniqueDef] = []
		all_inheritable.append_array(inheritable_a)
		all_inheritable.append_array(inheritable_b)

		if not all_inheritable.is_empty():
			print("  Inheritable techniques (%d slots):" % slots)
			for i: int in range(all_inheritable.size()):
				var t: TechniqueDef = all_inheritable[i]
				print("    %d. %s [%s pw:%d]" % [i + 1, t.name, t.affinity, t.power])
			print("  Enter technique numbers to inherit (space-separated):")
			var tech_input: String = _prompt("  Inherit: ")
			var tech_parts: PackedStringArray = tech_input.split(" ", false)
			for part: String in tech_parts:
				var t_idx: int = int(part) - 1
				if t_idx >= 0 and t_idx < all_inheritable.size() and inherited_ids.size() < slots:
					inherited_ids.append(all_inheritable[t_idx].id)

	print("")
	var confirm: String = _prompt("  Confirm fusion? (y/n): ")
	if confirm.to_lower() != "y":
		print("  Fusion cancelled.")
		return

	var result: GlyphInstance = _fusion.execute_fusion(parent_a, parent_b, inherited_ids)
	print("  Fused into %s! [%s T%d]" % [result.species.name, result.species.affinity, result.species.tier])

	## Update squad if parents were in it
	var new_squad: Array[GlyphInstance] = []
	for g: GlyphInstance in _roster.active_squad:
		if _roster.has_glyph(g):
			new_squad.append(g)
	if not new_squad.has(result) and new_squad.size() < _crawler.slots:
		new_squad.append(result)
	_roster.set_active_squad(new_squad)


# ============================================================
#  VIEW CODEX
# ============================================================

func _view_codex() -> void:
	print("")
	print("--- Codex ---")
	print("  Discovered: %d/15 (%.0f%%)" % [
		_codex.get_discovery_count(),
		_codex.get_discovery_percentage() * 100.0])
	print("  Fusions: %d" % _codex.get_fusion_count())
	print("  Rifts cleared: %d" % _codex.cleared_rift_count())
	print("")
	print("  Discovered species:")
	for sid: String in _codex.discovered_species:
		var sp: GlyphSpecies = _dl.get_species(sid)
		print("    %s [%s T%d] HP:%d ATK:%d DEF:%d SPD:%d RES:%d" % [
			sp.name, sp.affinity, sp.tier,
			sp.base_hp, sp.base_atk, sp.base_def, sp.base_spd, sp.base_res])
	print("")
	print("  Cleared rifts:")
	for rid: String in _codex.rifts_cleared:
		var t: RiftTemplate = _dl.get_rift_template(rid)
		var name_str: String = t.name if t != null else rid
		print("    %s" % name_str)


# ============================================================
#  VIEW CRAWLER
# ============================================================

func _view_crawler() -> void:
	print("")
	print("--- Crawler ---")
	print("  Hull: %d/%d" % [_crawler.hull_hp, _crawler.max_hull_hp])
	print("  Energy: %d/%d" % [_crawler.energy, _crawler.max_energy])
	print("  Capacity: %d GP" % _crawler.capacity)
	print("  Slots: %d" % _crawler.slots)
	print("  Cargo: %d" % _crawler.cargo_slots)
	print("  Chassis: %s" % _crawler.active_chassis)
	print("  Items: %d/%d" % [_crawler.items.size(), CrawlerState.MAX_ITEMS])
	for item: ItemDef in _crawler.items:
		print("    - %s: %s" % [item.name, item.description])


# ============================================================
#  USE ITEM
# ============================================================

func _use_item() -> void:
	if _crawler.items.is_empty():
		print("  No items in cargo.")
		return

	print("")
	print("  --- Items ---")
	for i: int in range(_crawler.items.size()):
		var item: ItemDef = _crawler.items[i]
		print("    %d. %s — %s" % [i + 1, item.name, item.description])
	print("    0. Cancel")
	print("")

	var choice: String = _prompt("  Use item: ")
	var idx: int = int(choice) - 1
	if idx < 0 or idx >= _crawler.items.size():
		return

	var item: ItemDef = _crawler.items[idx]
	_apply_item(item)


func _apply_item(item: ItemDef) -> void:
	match item.effect_type:
		"repair_hull":
			var heal: int = int(item.effect_value)
			_crawler.hull_hp = mini(_crawler.hull_hp + heal, _crawler.max_hull_hp)
			_crawler.use_item(item)
			print("  Used %s — Hull restored by %d (now %d/%d)." % [
				item.name, heal, _crawler.hull_hp, _crawler.max_hull_hp])
		"restore_energy":
			var restore: int = int(item.effect_value)
			_crawler.energy = mini(_crawler.energy + restore, _crawler.max_energy)
			_crawler.use_item(item)
			print("  Used %s — Energy restored by %d (now %d/%d)." % [
				item.name, restore, _crawler.energy, _crawler.max_energy])
		"heal_glyph":
			var target: GlyphInstance = _pick_glyph_target("heal")
			if target == null:
				print("  Cancelled.")
				return
			target.current_hp = target.max_hp
			target.is_knocked_out = false
			_crawler.use_item(item)
			print("  Used %s — %s fully healed! (HP: %d/%d)" % [
				item.name, target.species.name, target.current_hp, target.max_hp])
		"status_immunity":
			var target: GlyphInstance = _pick_glyph_target("grant immunity to")
			if target == null:
				print("  Cancelled.")
				return
			for status_id: String in ["burn", "stun", "slow", "weaken", "corrode"]:
				target.status_immunities[status_id] = 99
			_crawler.use_item(item)
			print("  Used %s — %s is immune to status effects next battle!" % [
				item.name, target.species.name])
		"capture_bonus":
			_capture_bonus += item.effect_value / 100.0
			_crawler.use_item(item)
			print("  Used %s — Capture chance +%.0f%% for next battle!" % [
				item.name, item.effect_value])
		_:
			print("  Cannot use %s here." % item.name)


func _pick_glyph_target(action: String) -> GlyphInstance:
	var glyphs: Array[GlyphInstance] = []
	for g: GlyphInstance in _roster.active_squad:
		glyphs.append(g)
	if glyphs.is_empty():
		return null
	print("  Select glyph to %s:" % action)
	for i: int in range(glyphs.size()):
		var g: GlyphInstance = glyphs[i]
		print("    %d. %s (HP: %d/%d)" % [i + 1, g.species.name, g.current_hp, g.max_hp])
	print("    0. Cancel")
	var choice: String = _prompt("  Target: ")
	var idx: int = int(choice) - 1
	if idx < 0 or idx >= glyphs.size():
		return null
	return glyphs[idx]


# ============================================================
#  HELPERS
# ============================================================

func _prompt(text: String) -> String:
	printt(text)
	return OS.read_string_from_stdin().strip_edges()
