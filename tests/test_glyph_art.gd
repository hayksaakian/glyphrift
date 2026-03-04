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
	print("  GLYPHRIFT — GlyphArt Tests")
	print("========================================")
	print("")

	_test_portrait_missing()
	_test_silhouette_missing()
	_test_cache_consistency()
	_test_clear_cache()
	_test_apply_texture_fallback()
	_test_apply_texture_below_min_size()
	_test_apply_texture_idempotent()

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

func _test_portrait_missing() -> void:
	print("--- GlyphArt: Missing Portrait ---")
	GlyphArt.clear_cache()
	var tex: Texture2D = GlyphArt.get_portrait("nonexistent_species_xyz")
	_assert(tex == null, "get_portrait returns null for missing file")


func _test_silhouette_missing() -> void:
	print("--- GlyphArt: Missing Silhouette ---")
	GlyphArt.clear_cache()
	var tex: Texture2D = GlyphArt.get_silhouette("nonexistent_species_xyz")
	_assert(tex == null, "get_silhouette returns null for missing file")


func _test_cache_consistency() -> void:
	print("--- GlyphArt: Cache Consistency ---")
	GlyphArt.clear_cache()
	var tex1: Texture2D = GlyphArt.get_portrait("zapplet")
	var tex2: Texture2D = GlyphArt.get_portrait("zapplet")
	## Both should be null (no file), but the point is they're consistent
	_assert(tex1 == tex2, "Repeated calls return same result")
	## Cache should have the entry now
	_assert(GlyphArt._portrait_cache.has("zapplet"), "Cache stores the lookup")


func _test_clear_cache() -> void:
	print("--- GlyphArt: Clear Cache ---")
	## Populate cache
	GlyphArt.get_portrait("zapplet")
	GlyphArt.get_silhouette("zapplet")
	_assert(not GlyphArt._portrait_cache.is_empty(), "Portrait cache not empty before clear")
	_assert(not GlyphArt._silhouette_cache.is_empty(), "Silhouette cache not empty before clear")

	GlyphArt.clear_cache()
	_assert(GlyphArt._portrait_cache.is_empty(), "Portrait cache empty after clear")
	_assert(GlyphArt._silhouette_cache.is_empty(), "Silhouette cache empty after clear")


func _test_apply_texture_fallback() -> void:
	print("--- GlyphArt: Apply Texture Fallback ---")
	GlyphArt.clear_cache()

	## Build a minimal art container matching the project pattern
	var container: Control = Control.new()
	container.custom_minimum_size = Vector2(60, 60)
	root.add_child(container)

	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color.RED
	container.add_child(rect)

	var label: Label = Label.new()
	label.text = "Z"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(label)

	## Apply with no PNG file — should fallback
	GlyphArt.apply_texture(container, rect, label, "zapplet", 60)

	_assert(rect.visible, "ColorRect stays visible on fallback")
	_assert(label.visible, "Label stays visible on fallback")
	var tex_node: TextureRect = container.get_node_or_null("GlyphTexture") as TextureRect
	_assert(tex_node == null or not tex_node.visible, "No visible TextureRect on fallback")

	_cleanup_node(container)


func _test_apply_texture_below_min_size() -> void:
	print("--- GlyphArt: Below Min Size ---")
	GlyphArt.clear_cache()

	var container: Control = Control.new()
	container.custom_minimum_size = Vector2(20, 20)
	root.add_child(container)

	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(rect)

	var label: Label = Label.new()
	label.text = "Z"
	container.add_child(label)

	## Apply with size below MIN_TEXTURE_SIZE (32) — always uses placeholder
	GlyphArt.apply_texture(container, rect, label, "zapplet", 20)

	_assert(rect.visible, "ColorRect visible for small icon")
	_assert(label.visible, "Label visible for small icon")

	_cleanup_node(container)


func _test_apply_texture_idempotent() -> void:
	print("--- GlyphArt: Idempotent Apply ---")
	GlyphArt.clear_cache()

	var container: Control = Control.new()
	container.custom_minimum_size = Vector2(60, 60)
	root.add_child(container)

	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(rect)

	var label: Label = Label.new()
	label.text = "Z"
	container.add_child(label)

	## Call apply_texture multiple times — should not create duplicate children
	GlyphArt.apply_texture(container, rect, label, "zapplet", 60)
	GlyphArt.apply_texture(container, rect, label, "zapplet", 60)
	GlyphArt.apply_texture(container, rect, label, "zapplet", 60)

	var tex_count: int = 0
	for child: Node in container.get_children():
		if child.name == "GlyphTexture":
			tex_count += 1

	_assert(tex_count <= 1, "No duplicate GlyphTexture nodes after multiple applies")

	_cleanup_node(container)
