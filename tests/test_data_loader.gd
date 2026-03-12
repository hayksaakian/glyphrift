extends SceneTree

## Manual DataLoader reference (autoloads aren't available in --script mode)
var _data_loader: Node = null


func _init() -> void:
	## Manually instantiate and initialize DataLoader since autoloads
	## are not registered when running via --script
	var script: GDScript = load("res://core/data_loader.gd") as GDScript
	_data_loader = script.new() as Node
	_data_loader.name = "DataLoader"
	root.add_child(_data_loader)
	## Wait a frame for _ready() to fire
	await process_frame
	_run_tests()
	quit()


func _run_tests() -> void:
	print("")
	print("========================================")
	print("  GLYPHRIFT — Data Layer Validation")
	print("========================================")
	print("")

	var pass_count: int = 0
	var fail_count: int = 0

	# --- Species ---
	var species_count: int = _data_loader.species.size()
	## 18 species: 8 T1 (6 elemental + 2 neutral) + 4 T2 (3 elemental + 1 neutral) + 3 T3 + 3 T4
	if species_count == 18:
		print("[PASS] Species loaded: %d (expected 18)" % species_count)
		pass_count += 1
	else:
		print("[FAIL] Species loaded: %d (expected 18)" % species_count)
		fail_count += 1

	# Verify each tier has correct count
	var tier_counts: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
	for sp: GlyphSpecies in _data_loader.species.values():
		tier_counts[sp.tier] += 1
	var expected_tiers: Dictionary = {1: 8, 2: 4, 3: 3, 4: 3}
	var tiers_ok: bool = true
	for tier: int in expected_tiers:
		if tier_counts[tier] != expected_tiers[tier]:
			print("[FAIL] Tier %d species count: %d (expected %d)" % [tier, tier_counts[tier], expected_tiers[tier]])
			fail_count += 1
			tiers_ok = false
	if tiers_ok:
		print("[PASS] Tier distribution: T1=%d T2=%d T3=%d T4=%d" % [tier_counts[1], tier_counts[2], tier_counts[3], tier_counts[4]])
		pass_count += 1

	# Verify affinity distribution
	var affinity_counts: Dictionary = {"electric": 0, "ground": 0, "water": 0, "neutral": 0}
	for sp: GlyphSpecies in _data_loader.species.values():
		affinity_counts[sp.affinity] += 1
	var affinities_ok: bool = true
	for aff: String in affinity_counts:
		var min_expected: int = 3 if aff == "neutral" else 4
		if affinity_counts[aff] < min_expected:
			print("[FAIL] Affinity '%s' has only %d species (expected %d+)" % [aff, affinity_counts[aff], min_expected])
			fail_count += 1
			affinities_ok = false
	if affinities_ok:
		print("[PASS] Affinity distribution: Electric=%d Ground=%d Water=%d Neutral=%d" % [affinity_counts["electric"], affinity_counts["ground"], affinity_counts["water"], affinity_counts["neutral"]])
		pass_count += 1

	# Verify all species have technique_ids that exist
	var tech_ref_ok: bool = true
	for sp: GlyphSpecies in _data_loader.species.values():
		for tid: String in sp.technique_ids:
			if not _data_loader.techniques.has(tid):
				print("[FAIL] Species '%s' references unknown technique '%s'" % [sp.id, tid])
				fail_count += 1
				tech_ref_ok = false
	if tech_ref_ok:
		print("[PASS] All species technique references are valid")
		pass_count += 1

	# Verify all species have 2 fixed mastery objectives
	var mastery_ok: bool = true
	for sp: GlyphSpecies in _data_loader.species.values():
		if sp.fixed_mastery_objectives.size() != 2:
			print("[FAIL] Species '%s' (T%d) has %d fixed mastery objectives (expected 2)" % [sp.id, sp.tier, sp.fixed_mastery_objectives.size()])
			fail_count += 1
			mastery_ok = false
	if mastery_ok:
		print("[PASS] All species have correct mastery objective counts")
		pass_count += 1

	# --- Techniques ---
	var technique_count: int = _data_loader.techniques.size()
	if technique_count >= 27:
		print("[PASS] Techniques loaded: %d (expected 27+)" % technique_count)
		pass_count += 1
	else:
		print("[FAIL] Techniques loaded: %d (expected 27+)" % technique_count)
		fail_count += 1

	# Verify technique categories
	var cat_counts: Dictionary = {"offensive": 0, "status": 0, "support": 0, "interrupt": 0}
	for tech: TechniqueDef in _data_loader.techniques.values():
		if cat_counts.has(tech.category):
			cat_counts[tech.category] += 1
	print("       Categories: offensive=%d status=%d support=%d interrupt=%d" % [cat_counts["offensive"], cat_counts["status"], cat_counts["support"], cat_counts["interrupt"]])

	# --- Fusion Table ---
	## Count unique pairs (each pair stored both ways, plus same-species stored once)
	var unique_pairs: Dictionary = {}
	for key: String in _data_loader.fusion_table:
		var parts: PackedStringArray = key.split("|")
		var sorted_key: String = ""
		if parts[0] <= parts[1]:
			sorted_key = parts[0] + "|" + parts[1]
		else:
			sorted_key = parts[1] + "|" + parts[0]
		unique_pairs[sorted_key] = _data_loader.fusion_table[key]
	var fusion_pair_count: int = unique_pairs.size()
	if fusion_pair_count >= 33:
		print("[PASS] Fusion pairs loaded: %d unique (expected 33+)" % fusion_pair_count)
		pass_count += 1
	else:
		print("[FAIL] Fusion pairs loaded: %d unique (expected 33+)" % fusion_pair_count)
		fail_count += 1

	# Verify order independence
	var fusion_order_ok: bool = true
	var result_1: String = _data_loader.lookup_fusion("zapplet", "sparkfin")
	var result_2: String = _data_loader.lookup_fusion("sparkfin", "zapplet")
	if result_1 != result_2:
		print("[FAIL] Fusion lookup is not order-independent: '%s' vs '%s'" % [result_1, result_2])
		fail_count += 1
		fusion_order_ok = false
	if result_1 != "thunderclaw":
		print("[FAIL] Zapplet + Sparkfin should produce Thunderclaw, got '%s'" % result_1)
		fail_count += 1
		fusion_order_ok = false
	if fusion_order_ok:
		print("[PASS] Fusion lookup is order-independent (Zapplet+Sparkfin → Thunderclaw)")
		pass_count += 1

	# Spot-check more fusions from GDD
	var fusion_checks: Array[Dictionary] = [
		{"a": "zapplet", "b": "stonepaw", "expected": "vortail"},
		{"a": "stonepaw", "b": "mossling", "expected": "ironbark"},
		{"a": "thunderclaw", "b": "ironbark", "expected": "riftmaw"},
		{"a": "stormfang", "b": "riftmaw", "expected": "voltarion"},
		{"a": "zapplet", "b": "zapplet", "expected": "thunderclaw"},
		{"a": "riftmaw", "b": "riftmaw", "expected": "nullweaver"},
	]
	var spot_ok: bool = true
	for check: Dictionary in fusion_checks:
		var result: String = _data_loader.lookup_fusion(check["a"], check["b"])
		if result != check["expected"]:
			print("[FAIL] %s + %s → '%s' (expected '%s')" % [check["a"], check["b"], result, check["expected"]])
			fail_count += 1
			spot_ok = false
	if spot_ok:
		print("[PASS] All %d fusion spot-checks passed" % fusion_checks.size())
		pass_count += 1

	# --- Mastery Pools ---
	var pool_ok: bool = true
	for tier: int in [1, 2, 3]:
		var pool: Array = _data_loader.mastery_pools.get(tier, [])
		if pool.size() != 5:
			print("[FAIL] Mastery pool for T%d has %d entries (expected 5)" % [tier, pool.size()])
			fail_count += 1
			pool_ok = false
	if pool_ok:
		print("[PASS] Mastery pools: T1=%d T2=%d T3=%d objectives" % [
			_data_loader.mastery_pools[1].size(),
			_data_loader.mastery_pools[2].size(),
			_data_loader.mastery_pools[3].size()
		])
		pass_count += 1

	# --- Items ---
	var item_count: int = _data_loader.items.size()
	if item_count == 9:
		print("[PASS] Items loaded: %d (expected 9)" % item_count)
		pass_count += 1
	else:
		print("[FAIL] Items loaded: %d (expected 9)" % item_count)
		fail_count += 1

	# --- Rift Templates ---
	var template_count: int = _data_loader.rift_templates.size()
	if template_count == 9:
		print("[PASS] Rift templates loaded: %d (expected 9)" % template_count)
		pass_count += 1
	else:
		print("[FAIL] Rift templates loaded: %d (expected 9)" % template_count)
		fail_count += 1

	# Verify floor counts per tier
	var template_ok: bool = true
	for template: RiftTemplate in _data_loader.rift_templates:
		var expected_floors: int = 0
		match template.tier:
			"minor":
				expected_floors = 3 if template.rift_id == "tutorial_01" else 4
			"standard":
				expected_floors = 5
			"major":
				expected_floors = 6
			"apex":
				expected_floors = 6
		if template.floors.size() != expected_floors:
			print("[FAIL] Template '%s' (%s) has %d floors (expected %d)" % [template.rift_id, template.tier, template.floors.size(), expected_floors])
			fail_count += 1
			template_ok = false
	if template_ok:
		print("[PASS] All rift templates have correct floor counts")
		pass_count += 1

	# --- Bosses ---
	var boss_count: int = _data_loader.bosses.size()
	if boss_count == 9:
		print("[PASS] Bosses loaded: %d (expected 9)" % boss_count)
		pass_count += 1
	else:
		print("[FAIL] Bosses loaded: %d (expected 9)" % boss_count)
		fail_count += 1

	# Verify boss species references exist
	var boss_ref_ok: bool = true
	for rift_id: String in _data_loader.bosses:
		var boss: BossDef = _data_loader.bosses[rift_id]
		if not _data_loader.species.has(boss.species_id):
			print("[FAIL] Boss for '%s' references unknown species '%s'" % [rift_id, boss.species_id])
			fail_count += 1
			boss_ref_ok = false
		for tid: String in boss.phase1_technique_ids:
			if not _data_loader.techniques.has(tid):
				print("[FAIL] Boss '%s' phase 1 references unknown technique '%s'" % [rift_id, tid])
				fail_count += 1
				boss_ref_ok = false
		for tid: String in boss.phase2_technique_ids:
			if not _data_loader.techniques.has(tid):
				print("[FAIL] Boss '%s' phase 2 references unknown technique '%s'" % [rift_id, tid])
				fail_count += 1
				boss_ref_ok = false
	if boss_ref_ok:
		print("[PASS] All boss species and technique references are valid")
		pass_count += 1

	# --- Codex Entries ---
	var codex_count: int = _data_loader.codex_entries.size()
	## Should have entries for all non-T4 or all species. We have 15 entries (all except maybe some)
	if codex_count >= 18:
		print("[PASS] Codex entries loaded: %d (expected 18+)" % codex_count)
		pass_count += 1
	else:
		print("[FAIL] Codex entries loaded: %d (expected 18+)" % codex_count)
		fail_count += 1

	# --- NPC Dialogue ---
	var npc_count: int = _data_loader.npc_dialogue.size()
	if npc_count == 3:
		print("[PASS] NPC dialogue loaded: %d NPCs (expected 3)" % npc_count)
		pass_count += 1
	else:
		print("[FAIL] NPC dialogue loaded: %d NPCs (expected 3)" % npc_count)
		fail_count += 1

	# --- Crawler Upgrades ---
	var upgrade_count: int = _data_loader.crawler_upgrades.size()
	if upgrade_count == 8:
		print("[PASS] Crawler upgrades loaded: %d (expected 8)" % upgrade_count)
		pass_count += 1
	else:
		print("[FAIL] Crawler upgrades loaded: %d (expected 8)" % upgrade_count)
		fail_count += 1

	# --- Specific Species Stat Validation ---
	print("")
	print("--- Spot-checking species stats ---")
	var zapplet: GlyphSpecies = _data_loader.get_species("zapplet")
	var zapplet_ok: bool = (
		zapplet.base_hp == 12 and zapplet.base_atk == 10 and zapplet.base_def == 8
		and zapplet.base_spd == 14 and zapplet.base_res == 9 and zapplet.gp_cost == 2
		and zapplet.tier == 1 and zapplet.affinity == "electric"
	)
	if zapplet_ok:
		print("[PASS] Zapplet stats match GDD")
		pass_count += 1
	else:
		print("[FAIL] Zapplet stats do not match GDD")
		fail_count += 1

	var nullweaver: GlyphSpecies = _data_loader.get_species("nullweaver")
	var nw_ok: bool = (
		nullweaver.base_hp == 45 and nullweaver.base_atk == 52 and nullweaver.base_def == 34
		and nullweaver.base_spd == 48 and nullweaver.base_res == 40 and nullweaver.gp_cost == 8
		and nullweaver.tier == 4 and nullweaver.affinity == "water"
	)
	if nw_ok:
		print("[PASS] Nullweaver stats match GDD")
		pass_count += 1
	else:
		print("[FAIL] Nullweaver stats do not match GDD")
		fail_count += 1

	# --- Neutral Species ---
	print("")
	print("--- Neutral species and fusion wildcard ---")

	var vesper: GlyphSpecies = _data_loader.get_species("vesper")
	var vesper_ok: bool = (
		vesper.base_hp == 13 and vesper.base_atk == 11 and vesper.base_def == 10
		and vesper.base_spd == 10 and vesper.base_res == 9 and vesper.gp_cost == 2
		and vesper.tier == 1 and vesper.affinity == "neutral"
	)
	if vesper_ok:
		print("[PASS] Vesper stats match design")
		pass_count += 1
	else:
		print("[FAIL] Vesper stats do not match design")
		fail_count += 1

	var equinox_sp: GlyphSpecies = _data_loader.get_species("equinox")
	var equinox_ok: bool = (
		equinox_sp.base_hp == 10 and equinox_sp.base_atk == 9 and equinox_sp.base_def == 8
		and equinox_sp.base_spd == 13 and equinox_sp.base_res == 11 and equinox_sp.gp_cost == 2
		and equinox_sp.tier == 1 and equinox_sp.affinity == "neutral"
	)
	if equinox_ok:
		print("[PASS] Equinox stats match design")
		pass_count += 1
	else:
		print("[FAIL] Equinox stats do not match design")
		fail_count += 1

	var solstice_sp: GlyphSpecies = _data_loader.get_species("solstice")
	var sol_ok: bool = (
		solstice_sp.base_hp == 22 and solstice_sp.base_atk == 17 and solstice_sp.base_def == 18
		and solstice_sp.base_spd == 16 and solstice_sp.base_res == 17 and solstice_sp.gp_cost == 3
		and solstice_sp.tier == 2 and solstice_sp.affinity == "neutral"
	)
	if sol_ok:
		print("[PASS] Solstice stats match design")
		pass_count += 1
	else:
		print("[FAIL] Solstice stats do not match design")
		fail_count += 1

	# Neutral-to-neutral fusion (explicit table entry)
	var neutral_fusion: String = _data_loader.lookup_fusion("vesper", "equinox")
	if neutral_fusion == "solstice":
		print("[PASS] Vesper + Equinox → Solstice")
		pass_count += 1
	else:
		print("[FAIL] Vesper + Equinox → '%s' (expected 'solstice')" % neutral_fusion)
		fail_count += 1

	# Neutral wildcard fusion: neutral + elemental → same as elemental + elemental
	var wildcard_1: String = _data_loader.lookup_fusion("vesper", "zapplet")
	if wildcard_1 == "thunderclaw":
		print("[PASS] Neutral wildcard: Vesper + Zapplet → Thunderclaw")
		pass_count += 1
	else:
		print("[FAIL] Neutral wildcard: Vesper + Zapplet → '%s' (expected 'thunderclaw')" % wildcard_1)
		fail_count += 1

	var wildcard_2: String = _data_loader.lookup_fusion("equinox", "stonepaw")
	if wildcard_2 == "ironbark":
		print("[PASS] Neutral wildcard: Equinox + Stonepaw → Ironbark")
		pass_count += 1
	else:
		print("[FAIL] Neutral wildcard: Equinox + Stonepaw → '%s' (expected 'ironbark')" % wildcard_2)
		fail_count += 1

	# Verify new techniques exist
	var soothe_tech: TechniqueDef = _data_loader.get_technique("soothe")
	var soothe_ok: bool = (
		soothe_tech.category == "support" and soothe_tech.affinity == "neutral"
		and soothe_tech.support_effect == "heal_percent" and soothe_tech.support_value > 0.29
		and soothe_tech.cooldown == 2
	)
	if soothe_ok:
		print("[PASS] Soothe technique loaded correctly")
		pass_count += 1
	else:
		print("[FAIL] Soothe technique has incorrect properties")
		fail_count += 1

	var ward_pulse_tech: TechniqueDef = _data_loader.get_technique("ward_pulse")
	var wp_ok: bool = (
		ward_pulse_tech.category == "support" and ward_pulse_tech.affinity == "neutral"
		and ward_pulse_tech.support_effect == "shield_all" and ward_pulse_tech.range_type == "aoe"
		and ward_pulse_tech.cooldown == 3
	)
	if wp_ok:
		print("[PASS] Ward Pulse technique loaded correctly")
		pass_count += 1
	else:
		print("[FAIL] Ward Pulse technique has incorrect properties")
		fail_count += 1

	# --- Summary ---
	print("")
	print("========================================")
	print("  RESULTS: %d passed, %d failed" % [pass_count, fail_count])
	print("========================================")
	if fail_count == 0:
		print("  ALL TESTS PASSED")
	else:
		print("  SOME TESTS FAILED — review output above")
	print("")
