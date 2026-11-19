extends Control

## The pause screen: the whole tree is paused under it (match clock, troops,
## bots, the hand), and this node alone keeps running (PROCESS_MODE_ALWAYS) so
## it can take Esc, the Resume button and the volume slider. Built and freed by
## arena.gd (set_paused); no class_name, preloaded there.

const DIM := Color(0.03, 0.03, 0.06, 0.62)
const PANEL_BG := Color(0.1, 0.1, 0.14, 0.97)
const PANEL_EDGE := Color(0.62, 0.66, 0.74)
const INK := Color(0.92, 0.93, 0.96)
const SUB := Color(0.62, 0.66, 0.74)
const PANEL_SIZE := Vector2(360.0, 290.0)
const TITLE_SCENE := "res://scenes/title.tscn"

var arena: Node = null
var resume_button: Button = null
var volume: HSlider = null


func setup(a: Node) -> void:
	arena = a


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p := _panel_rect()
	resume_button = Button.new()
	resume_button.text = "Resume"
	resume_button.focus_mode = Control.FOCUS_NONE
	resume_button.position = p.position + Vector2(80.0, 82.0)
	resume_button.size = Vector2(200.0, 44.0)
	resume_button.add_theme_font_size_override("font_size", 20)
	resume_button.pressed.connect(_resume)
	add_child(resume_button)
	volume = HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = DDSfx.get_volume()
	volume.focus_mode = Control.FOCUS_NONE
	volume.position = p.position + Vector2(110.0, 150.0)
	volume.size = Vector2(210.0, 20.0)
	volume.value_changed.connect(_on_volume)
	add_child(volume)
	# leave the match (or the run) for the title screen
	var quit_button := Button.new()
	quit_button.text = "Title screen"
	quit_button.focus_mode = Control.FOCUS_NONE
	quit_button.position = p.position + Vector2(100.0, 192.0)
	quit_button.size = Vector2(160.0, 36.0)
	quit_button.add_theme_font_size_override("font_size", 16)
	quit_button.pressed.connect(_to_title)
	add_child(quit_button)


## Back to the title: the run (if any) is abandoned, and the tree unpaused
## before the scene changes so nothing carries the pause across.
func _to_title() -> void:
	get_tree().paused = false
	if Run.active:
		Run.stop()
	Run.menu_choice = ""
	get_tree().change_scene_to_file(TITLE_SCENE)


func _panel_rect() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2((vs - PANEL_SIZE) * 0.5, PANEL_SIZE)


func _on_volume(v: float) -> void:
	DDSfx.set_volume(v)
	# keep the HUD slider in step without it saving a second time
	if arena != null and arena.get("volume_slider") != null:
		arena.volume_slider.set_value_no_signal(v)


func _resume() -> void:
	if arena != null:
		arena.set_paused(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_resume()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DIM, true)
	var p := _panel_rect()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	draw_style_box(sb, p)
	var font := ThemeDB.fallback_font
	draw_string(font, p.position + Vector2(0.0, 52.0), "PAUSED", HORIZONTAL_ALIGNMENT_CENTER, p.size.x, 32, INK)
	draw_string(font, p.position + Vector2(36.0, 166.0), "VOLUME", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SUB)
	draw_string(font, p.position + Vector2(0.0, 266.0), "Esc to resume", HORIZONTAL_ALIGNMENT_CENTER, p.size.x, 13, SUB)
