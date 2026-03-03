extends Control

## Quick screenshot of initial dungeon map to verify type labels.

var _data_loader: Node = null

func _ready() -> void:
	_data_loader = get_node("/root/DataLoader")

	var crawler: CrawlerState = CrawlerState.new()
	crawler.name = "Crawler"
	get_tree().root.call_deferred("add_child", crawler)
	await get_tree().process_frame
	await get_tree().process_frame

	var ds: DungeonState = DungeonState.new()
	ds.crawler = crawler
	## Use minor_01 — has more rooms to see variety
	var template: RiftTemplate = _data_loader.get_rift_template("minor_01")
	ds.initialize(template)

	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	add_child(scene)
	scene.start_rift(ds)

	## Use scan to reveal adjacent rooms so we see labels
	ds.use_crawler_ability("scan")

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("/tmp/glyphrift_labels.png")
	print("Screenshot: /tmp/glyphrift_labels.png")
	get_tree().quit()
