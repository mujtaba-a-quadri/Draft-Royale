extends Node2D

## The match-phase announcement (single gold, double gold, sudden death): big
## letters in the middle of the board that pop in, hold and fade. They are drawn
## over the troops but under the buildings and towers: while a call is up, every
## building and tower is lifted above it (z LIFT_Z) and put back afterwards.
## Built by arena._call_phase(); no class_name, preloaded there.

const TEXT_Z := 6
const LIFT_Z := 7
const IN_TIME := 0.25
const HOLD_TIME := 1.7
const OUT_TIME := 0.6
const TITLE_SIZE := 92
const SUB_SIZE := 26

var arena: Node2D = null
var title := ""
var sub := ""
var tint := Color(1, 1, 1)
var t := -1.0
## nodes we lifted, and the z each had before
var lifted := {}


func _ready() -> void:
	z_index = TEXT_Z


func show_call(p_title: String, p_sub: String, p_tint: Color) -> void:
	title = p_title
	sub = p_sub
	tint = p_tint
	t = 0.0
	queue_redraw()


func _total() -> float:
	return IN_TIME + HOLD_TIME + OUT_TIME


func _process(delta: float) -> void:
	if t < 0.0:
		return
	t += delta
	if t >= _total():
		t = -1.0
		_drop_all()
		queue_redraw()
		return
	_lift_all()
	queue_redraw()


## Buildings and towers above the letters while they show (new ones included).
func _lift_all() -> void:
	if arena == null:
		return
	var nodes: Array = []
	for u in arena.units:
		if is_instance_valid(u) and not u.dead and u.has_method("is_building") and u.is_building():
			nodes.append(u)
	for tw in arena.towers:
		# only real towers: a boss standing in for one keeps its own layers
		if is_instance_valid(tw) and tw is DDTower:
			nodes.append(tw)
	for n in nodes:
		var id: int = n.get_instance_id()
		if not lifted.has(id):
			lifted[id] = [n, n.z_index]
			n.z_index = LIFT_Z


func _drop_all() -> void:
	for id in lifted.keys():
		var pair: Array = lifted[id]
		if is_instance_valid(pair[0]):
			pair[0].z_index = int(pair[1])
	lifted.clear()


func _exit_tree() -> void:
	_drop_all()


func _draw() -> void:
	if t < 0.0 or arena == null:
		return
	var a := 1.0
	var pop := 1.0
	if t < IN_TIME:
		var f: float = t / IN_TIME
		a = f
		pop = lerpf(1.35, 1.0, ease(f, 0.4))
	elif t > IN_TIME + HOLD_TIME:
		a = 1.0 - (t - IN_TIME - HOLD_TIME) / OUT_TIME
	var font := ThemeDB.fallback_font
	var c: Vector2 = arena.board_rect().get_center()
	draw_set_transform(c, 0.0, Vector2(pop, pop))
	var w := 1400.0
	var ink := Color(0.06, 0.05, 0.09, 0.9 * a)
	draw_string_outline(font, Vector2(-w * 0.5, 18.0), title, HORIZONTAL_ALIGNMENT_CENTER, w, TITLE_SIZE, 14, ink)
	draw_string(font, Vector2(-w * 0.5, 18.0), title, HORIZONTAL_ALIGNMENT_CENTER, w, TITLE_SIZE,
		Color(tint.r, tint.g, tint.b, a))
	if sub != "":
		draw_string_outline(font, Vector2(-w * 0.5, 66.0), sub, HORIZONTAL_ALIGNMENT_CENTER, w, SUB_SIZE, 8, ink)
		draw_string(font, Vector2(-w * 0.5, 66.0), sub, HORIZONTAL_ALIGNMENT_CENTER, w, SUB_SIZE,
			Color(1.0, 0.97, 0.9, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
