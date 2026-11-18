extends Control

## "Choose a Card": after a won fight in a run, three full cards (face plus
## description) and a Skip button over the dimmed board. Click a card (or press
## 1-3) to add it to the run's deck, Skip (or S) to take nothing; either way the
## run goes on to its next fight. No class_name: preloaded by arena.gd, which
## puts it on its own CanvasLayer above the board and the hand.

const CARD_W := 300.0
const CARD_H := 460.0
const GAP := 56.0
## the result screen shows on its own for this long before the cards come in
const APPEAR_DELAY := 0.9
const FADE := 0.3
const SKIP_SIZE := Vector2(220.0, 58.0)

var arena: Node = null
var choices: Array = []
var hover := -1
var skip_hover := false
var t := 0.0
var done := false


func setup(p_arena: Node, p_choices: Array) -> void:
	arena = p_arena
	choices = p_choices.duplicate()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func ready_for_input() -> bool:
	return not done and t >= APPEAR_DELAY + FADE * 0.5


func card_rect(i: int) -> Rect2:
	var vs := get_viewport_rect().size
	var total: float = float(choices.size()) * CARD_W + float(choices.size() - 1) * GAP
	var x0: float = (vs.x - total) * 0.5
	return Rect2(x0 + float(i) * (CARD_W + GAP), vs.y * 0.5 - CARD_H * 0.5 - 30.0, CARD_W, CARD_H)


func skip_rect() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(vs.x * 0.5 - SKIP_SIZE.x * 0.5, card_rect(0).end.y + 44.0, SKIP_SIZE.x, SKIP_SIZE.y)


func _card_at(p: Vector2) -> int:
	for i in choices.size():
		if card_rect(i).has_point(p):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = _card_at(event.position)
		skip_hover = skip_rect().has_point(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not ready_for_input():
			return
		var i := _card_at(event.position)
		if i >= 0:
			pick(i)
		elif skip_rect().has_point(event.position):
			skip()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# the screen owns the keyboard while it is up: Enter must not skip by accident
	get_viewport().set_input_as_handled()
	if not ready_for_input():
		return
	if event.keycode >= KEY_1 and event.keycode < KEY_1 + choices.size():
		pick(int(event.keycode - KEY_1))
	elif event.keycode == KEY_S:
		skip()


func pick(i: int) -> void:
	if done or i < 0 or i >= choices.size():
		return
	done = true
	var run = get_node_or_null("/root/Run")
	if run != null:
		run.take_reward(String(choices[i]))
	_finish()


func skip() -> void:
	if done:
		return
	done = true
	var run = get_node_or_null("/root/Run")
	if run != null:
		run.skip_reward()
	_finish()


func _finish() -> void:
	if arena != null and is_instance_valid(arena) and arena.has_method("continue_run"):
		arena.continue_run()


func _draw() -> void:
	var a: float = clampf((t - APPEAR_DELAY) / FADE, 0.0, 1.0)
	if a <= 0.0:
		return
	var vs := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.04, 0.04, 0.07, 0.78 * a))
	# the banner: a ribbon with its ends folded back
	var bw := 420.0
	var by: float = card_rect(0).position.y - 92.0
	var ribbon := Rect2(vs.x * 0.5 - bw * 0.5, by, bw, 56.0)
	var tail := Color(0.62, 0.52, 0.36, a)
	for s in [-1.0, 1.0]:
		var ex: float = ribbon.position.x if s < 0.0 else ribbon.end.x
		draw_colored_polygon(PackedVector2Array([Vector2(ex, by + 10.0), Vector2(ex + s * 54.0, by + 10.0),
			Vector2(ex + s * 38.0, by + 38.0), Vector2(ex + s * 54.0, by + 66.0), Vector2(ex, by + 66.0)]), tail.darkened(0.25))
	draw_rect(ribbon, Color(0.86, 0.76, 0.56, a), true)
	draw_rect(ribbon, Color(0.32, 0.24, 0.14, a), false, 3.0)
	draw_string(font, ribbon.position + Vector2(0, 39.0), "Choose a Card", HORIZONTAL_ALIGNMENT_CENTER,
		bw, 30, Color(0.24, 0.16, 0.08, a))
	var run = get_node_or_null("/root/Run")
	if run != null:
		draw_string(font, Vector2(0, ribbon.end.y + 24.0), "one goes into your deck (%d cards)  ·  or skip" % run.deck.size(),
			HORIZONTAL_ALIGNMENT_CENTER, vs.x, 16, Color(0.85, 0.82, 0.74, a))
	# the cards; the hovered one lifts and grows a little
	for i in choices.size():
		var r := card_rect(i)
		var rise: float = sin(clampf((t - APPEAR_DELAY - 0.08 * float(i)) / 0.35, 0.0, 1.0) * PI * 0.5)
		r.position.y += (1.0 - rise) * 40.0
		if i == hover and not done:
			r = r.grow(10.0)
			r.position.y -= 10.0
			draw_rect(r.grow(6.0), Color(1.0, 0.9, 0.55, 0.55 * a), false, 4.0)
		DDCardFace.draw_full(self, String(choices[i]), r, a * rise)
		draw_string(font, Vector2(r.position.x, r.end.y + 26.0), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x, 18, Color(0.8, 0.78, 0.7, 0.8 * a))
	# Skip
	var sr := skip_rect()
	var sc := Color(0.24, 0.62, 0.66, a) if not skip_hover else Color(0.32, 0.74, 0.78, a)
	draw_rect(sr, sc, true)
	draw_rect(sr, Color(0.08, 0.2, 0.22, a), false, 3.0)
	draw_string(font, sr.position + Vector2(0, 38.0), "Skip", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 26,
		Color(1, 1, 1, a))
