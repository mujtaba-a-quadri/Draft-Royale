extends Node

## Renders the title screen into mockups/title/: at rest, with each quadrant
## hovered (lifted), and with the collection open. A preview scene, not game code.
## Run:  godot --path . res://scenes/title_mock.tscn

const OUT_DIR := "res://mockups/title"
const SIZE := Vector2i(1600, 1000)
const TITLE := preload("res://scenes/title.tscn")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await get_tree().process_frame
	for shot in [["rest", -1, false], ["hover_match", 0, false], ["hover_run", 1, false],
			["hover_collection", 2, false], ["hover_options", 3, false], ["options", -1, false], ["collection", -1, true],
			["collection_scrolled", -1, true]]:
		await _shot(String(shot[0]), int(shot[1]), bool(shot[2]))
	get_tree().quit()


func _shot(name: String, hover: int, open_collection: bool) -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var t: Control = TITLE.instantiate()
	vp.add_child(t)
	await get_tree().process_frame
	t.size = Vector2(SIZE)
	if open_collection:
		t._open_collection()
		if name.ends_with("scrolled"):
			# part way down: the eased scroll glides there over the frames below
			t.collection.scroll_by(650.0)
	if name == "options":
		t._open_options()
	t.hover = hover
	# let the lift settle
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png("%s/title_%s.png" % [OUT_DIR, name])
	print("[title] ", name)
	vp.queue_free()
