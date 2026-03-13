extends SceneTree

var pass_count: int = 0
var fail_count: int = 0


func _init() -> void:
	await process_frame
	_run_tests()
	quit()


func _run_tests() -> void:
	print("")
	print("========================================")
	print("  GLYPHRIFT — GlyphAnimator Tests")
	print("========================================")
	print("")

	_test_setup_with_sheet()
	_test_setup_fallback()
	_test_anim_config()
	_test_play_instant_mode()
	_test_play_idle_loops()
	_test_play_attack_no_loop()
	_test_play_ko_holds_last()
	_test_animation_finished_signal()
	_test_set_species()
	_test_play_unknown_anim()
	_test_fallback_emits_finished()

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


func _cleanup_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()


# ==========================================================================
# Tests
# ==========================================================================

func _test_setup_with_sheet() -> void:
	print("--- GlyphAnimator: Setup With Sheet ---")
	var animator: GlyphAnimator = GlyphAnimator.new()
	animator.custom_minimum_size = Vector2(60, 60)
	animator.instant_mode = true
	root.add_child(animator)

	animator.setup("zapplet")

	_assert(animator.has_animations, "has_animations true when sheet exists")
	_assert(animator._sprite != null, "AnimatedSprite2D created")
	_assert(animator._sprite_frames != null, "SpriteFrames created")
	_assert(animator._fallback_texture == null, "No fallback texture when sheet exists")
	_assert(animator.get_current_animation() == "idle", "Default animation is idle")

	_cleanup_node(animator)


func _test_setup_fallback() -> void:
	print("--- GlyphAnimator: Setup Fallback ---")
	var animator: GlyphAnimator = GlyphAnimator.new()
	animator.custom_minimum_size = Vector2(60, 60)
	animator.instant_mode = true
	root.add_child(animator)

	animator.setup("nonexistent_species_xyz")

	_assert(not animator.has_animations, "has_animations false when no sheet")
	_assert(animator._sprite == null, "No AnimatedSprite2D for fallback")
	_assert(animator._sprite_frames == null, "No SpriteFrames for fallback")

	_cleanup_node(animator)


func _test_anim_config() -> void:
	print("--- GlyphAnimator: Animation Config ---")
	var animator: GlyphAnimator = GlyphAnimator.new()
	animator.custom_minimum_size = Vector2(60, 60)
	animator.instant_mode = true
	root.add_child(animator)

	animator.setup("zapplet")

	var sf: SpriteFrames = animator._sprite_frames
	_assert(sf != null, "SpriteFrames exists")

	## idle: 4 frames, 4 FPS, loops
	_assert(sf.has_animation("idle"), "idle animation exists")
	_assert(sf.get_frame_count("idle") == 4, "idle has 4 frames")
	_assert(sf.get_animation_speed("idle") == 4.0, "idle at 4 FPS")
	_assert(sf.get_animation_loop("idle"), "idle loops")

	## attack: 4 frames, 8 FPS, no loop
	_assert(sf.has_animation("attack"), "attack animation exists")
	_assert(sf.get_frame_count("attack") == 4, "attack has 4 frames")
	_assert(sf.get_animation_speed("attack") == 8.0, "attack at 8 FPS")
	_assert(not sf.get_animation_loop("attack"), "attack does not loop")

	## hurt: 2 frames, 6 FPS, no loop
	_assert(sf.has_animation("hurt"), "hurt animation exists")
	_assert(sf.get_frame_count("hurt") == 2, "hurt has 2 frames")
	_assert(sf.get_animation_speed("hurt") == 6.0, "hurt at 6 FPS")
	_assert(not sf.get_animation_loop("hurt"), "hurt does not loop")

	## ko: 3 frames, 4 FPS, no loop
	_assert(sf.has_animation("ko"), "ko animation exists")
	_assert(sf.get_frame_count("ko") == 3, "ko has 3 frames")
	_assert(sf.get_animation_speed("ko") == 4.0, "ko at 4 FPS")
	_assert(not sf.get_animation_loop("ko"), "ko does not loop")

	_cleanup_node(animator)


func _test_play_instant_mode() -> void:
	print("--- GlyphAnimator: Instant Mode ---")
	var animator: GlyphAnimator = GlyphAnimator.new()
	animator.custom_minimum_size = Vector2(60, 60)
	animator.instant_mode = true
	root.add_child(animator)

	animator.setup("zapplet")

	## Play attack in instant mode — should skip to last frame
	animator.play("attack")
	_assert(animator._sprite.frame == 3, "instant_mode skips to last frame (attack)")
	_assert(animator.get_current_animation() == "attack", "current anim set to attack")

	## Play hurt in instant mode
	animator.play("hurt")
	_assert(animator._sprite.frame == 1, "instant_mode skips to last frame (hurt)")

	## Play ko in instant mode
	animator.play("ko")
	_assert(animator._sprite.frame == 2, "instant_mode skips to last frame (ko)")

	_cleanup_node(animator)


func _test_play_idle_loops() -> void:
	print("--- GlyphAnimator: Idle Loops ---")
	var animator: GlyphAnimator = GlyphAnimator.new()
	animator.custom_minimum_size = Vector2(60, 60)
	animator.instant_mode = true
	root.add_child(animator)

	animator.setup("zapplet")

	## idle in instant_mode skips to last frame
	animator.play("idle")
	_assert(animator._sprite.frame == 3, "idle instant_mode goes to last frame")
	_assert(animator.get_current_animation() == "idle", "current anim is idle")

	_cleanup_node(animator)


func _test_play_attack_no_loop() -> void:
	print("--- GlyphAnimator: Attack No Loop ---")
	var animator: GlyphAnimator = GlyphAnimator.new()
	animator.custom_minimum_size = Vector2(60, 60)
	animator.instant_mode = true
	root.add_child(animator)

	animator.setup("zapplet")

	animator.play("attack")
	_assert(animator.get_current_animation() == "attack", "current anim is attack")

	_cleanup_node(animator)


func _test_play_ko_holds_last() -> void:
	print("--- GlyphAnimator: KO Holds Last ---")
	var animator: GlyphAnimator = GlyphAnimator.new()
	animator.custom_minimum_size = Vector2(60, 60)
	animator.instant_mode = true
	root.add_child(animator)

	animator.setup("zapplet")

	animator.play("ko")
	_assert(animator._sprite.frame == 2, "KO on last frame (frame 2)")
	_assert(animator.get_current_animation() == "ko", "current anim is ko")

	_cleanup_node(animator)


func _test_animation_finished_signal() -> void:
	print("--- GlyphAnimator: animation_finished Signal ---")
	var animator: GlyphAnimator = GlyphAnimator.new()
	animator.custom_minimum_size = Vector2(60, 60)
	animator.instant_mode = true
	root.add_child(animator)

	animator.setup("zapplet")

	var result: Dictionary = {"count": 0}
	animator.animation_finished.connect(func() -> void:
		result["count"] += 1
	)

	## idle emits finished (looping → immediate emit)
	animator.play("idle")
	_assert(result["count"] >= 1, "idle emits animation_finished")

	result["count"] = 0
	animator.play("attack")
	_assert(result["count"] == 1, "attack instant_mode emits animation_finished")

	result["count"] = 0
	animator.play("ko")
	_assert(result["count"] == 1, "ko instant_mode emits animation_finished")

	_cleanup_node(animator)


func _test_set_species() -> void:
	print("--- GlyphAnimator: set_species ---")
	var animator: GlyphAnimator = GlyphAnimator.new()
	animator.custom_minimum_size = Vector2(60, 60)
	animator.instant_mode = true
	root.add_child(animator)

	animator.setup("zapplet")
	_assert(animator.has_animations, "zapplet has animations")

	## Switch to a species without a sheet
	animator.set_species("nonexistent_species_xyz")
	_assert(not animator.has_animations, "nonexistent species falls back")
	_assert(animator._sprite == null, "sprite cleared on species change")

	## Switch back to zapplet
	animator.set_species("zapplet")
	_assert(animator.has_animations, "zapplet animations restored")

	_cleanup_node(animator)


func _test_play_unknown_anim() -> void:
	print("--- GlyphAnimator: Unknown Animation ---")
	var animator: GlyphAnimator = GlyphAnimator.new()
	animator.custom_minimum_size = Vector2(60, 60)
	animator.instant_mode = true
	root.add_child(animator)

	animator.setup("zapplet")

	var result: Dictionary = {"count": 0}
	animator.animation_finished.connect(func() -> void:
		result["count"] += 1
	)

	## Unknown anim should emit finished immediately
	animator.play("nonexistent_anim")
	_assert(result["count"] == 1, "unknown anim emits animation_finished")

	_cleanup_node(animator)


func _test_fallback_emits_finished() -> void:
	print("--- GlyphAnimator: Fallback Emits Finished ---")
	var animator: GlyphAnimator = GlyphAnimator.new()
	animator.custom_minimum_size = Vector2(60, 60)
	animator.instant_mode = true
	root.add_child(animator)

	animator.setup("nonexistent_species_xyz")

	var result: Dictionary = {"count": 0}
	animator.animation_finished.connect(func() -> void:
		result["count"] += 1
	)

	## Play on fallback should emit finished immediately
	animator.play("attack")
	_assert(result["count"] == 1, "fallback play emits animation_finished")

	_cleanup_node(animator)
