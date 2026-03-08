extends SceneTree

## Aggregates all test suites into a single run.
## Usage: ~/bin/godot --headless --script res://tests/test_runner.gd

const SUITES: Array[String] = [
	"res://tests/test_data_loader.gd",
	"res://tests/test_combat.gd",
	"res://tests/test_mastery_fusion.gd",
	"res://tests/test_dungeon.gd",
	"res://tests/test_battle_ui.gd",
	"res://tests/test_dungeon_ui.gd",
	"res://tests/test_bastion_ui.gd",
	"res://tests/test_session9.gd",
	"res://tests/test_save_load.gd",
	"res://tests/test_title_screen.gd",
	"res://tests/test_glyph_art.gd",
	"res://tests/test_milestones.gd",
	"res://tests/test_playtest_fixes.gd",
]


func _init() -> void:
	await process_frame

	var godot_path: String = OS.get_executable_path()
	var total_passed: int = 0
	var total_failed: int = 0
	var failed_suites: Array[String] = []

	print("")
	print("========================================")
	print("  GLYPHRIFT — Full Test Runner")
	print("========================================")
	print("")

	for suite: String in SUITES:
		var suite_name: String = suite.get_file().replace(".gd", "")
		var args: Array = ["--headless", "--script", suite]
		var output: Array = []
		var exit_code: int = OS.execute(godot_path, args, output, true)

		## Parse results from output
		var out_text: String = "".join(output)
		var passed: int = 0
		var failed: int = 0
		var found_results: bool = false

		for line: String in out_text.split("\n"):
			## Match "RESULTS: N passed, N failed" or "Results: N/N passed"
			if "passed" in line and ("RESULTS" in line or "Results" in line):
				found_results = true
				if "failed" in line:
					## Format: "RESULTS: 83 passed, 0 failed"
					var parts: PackedStringArray = line.strip_edges().split(" ")
					for i: int in range(parts.size()):
						if parts[i] == "passed,":
							passed = int(parts[i - 1])
						elif parts[i] == "failed":
							failed = int(parts[i - 1])
				elif "/" in line:
					## Format: "Results: 82/82 passed"
					var slash_part: String = ""
					for word: String in line.split(" "):
						if "/" in word:
							slash_part = word
							break
					if slash_part != "":
						var nums: PackedStringArray = slash_part.split("/")
						passed = int(nums[0])

		if not found_results:
			## Couldn't parse — treat as failure
			failed = 1
			print("  [?] %-30s — could not parse output" % suite_name)
		elif failed > 0:
			print("  [FAIL] %-27s — %d passed, %d FAILED" % [suite_name, passed, failed])
		else:
			print("  [OK]   %-27s — %d passed" % [suite_name, passed])

		total_passed += passed
		total_failed += failed
		if failed > 0 or exit_code != 0:
			failed_suites.append(suite_name)

	print("")
	print("========================================")
	print("  TOTAL: %d passed, %d failed (%d suites)" % [total_passed, total_failed, SUITES.size()])
	print("========================================")
	if failed_suites.is_empty():
		print("  ALL SUITES PASSED")
	else:
		print("  FAILED SUITES: %s" % ", ".join(failed_suites))
	print("")

	quit()
