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
## where the mouse is, for the icon tooltips
var mouse := Vector2(-1.0, -1.0)
## 0..1 per card and for Skip: how far each has grown toward its hovered size
var lift: Array = []
var skip_lift := 0.0
## how much bigger a hovered card / Skip button gets, and how fast
const CARD_GROW := 0.06
const SKIP_GROW := 0.1
const LIFT_RATE := 12.0
## the icon under the mouse on the last frame drawn (for tests), or {}
var tip_hit: Dictionary = {}
## every icon drawn on the last frame (for tests)
var last_hits: Array = []


func setup(p_arena: Node, p_choices: Array) -> void:
	arena = p_arena
	choices = p_choices.duplicate()


func _ready() -> void:
	# anchors AND offsets: anchors alone left the control 0 x 0, so the mouse
	# never reached it and only the keys worked
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _process(delta: float) -> void:
	t += delta
	if lift.size() != choices.size():
		lift.resize(choices.size())
		lift.fill(0.0)
	var k := clampf(delta * LIFT_RATE, 0.0, 1.0)
	for i in choices.size():
		var want := 1.0 if (i == hover and not done) else 0.0
		lift[i] = lerpf(float(lift[i]), want, k)
	skip_lift = lerpf(skip_lift, 1.0 if (skip_hover and not done) else 0.0, k)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (hover >= 0 or skip_hover) and ready_for_input() \
		else Control.CURSOR_ARROW
	queue_redraw()


## A card's rect as drawn: grown about its centre while hovered.
func drawn_card_rect(i: int) -> Rect2:
	var r := card_rect(i)
	var g: float = float(lift[i]) if i < lift.size() else 0.0
	return r.grow_individual(r.size.x * CARD_GROW * 0.5 * g, r.size.y * CARD_GROW * 0.5 * g + 12.0 * g,
		r.size.x * CARD_GROW * 0.5 * g, r.size.y * CARD_GROW * 0.5 * g - 12.0 * g)


func drawn_skip_rect() -> Rect2:
	var r := skip_rect()
	return r.grow_individual(r.size.x * SKIP_GROW * 0.5 * skip_lift, r.size.y * SKIP_GROW * 0.5 * skip_lift,
		r.size.x * SKIP_GROW * 0.5 * skip_lift, r.size.y * SKIP_GROW * 0.5 * skip_lift)


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
		mouse = event.position
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
	# the cards; the hovered one lifts and grows a little. Every icon each one
	# draws is logged so the one under the mouse can explain itself.
	var hits: Array = []
	for i in choices.size():
		var r := drawn_card_rect(i)
		var rise: float = sin(clampf((t - APPEAR_DELAY - 0.08 * float(i)) / 0.35, 0.0, 1.0) * PI * 0.5)
		r.position.y += (1.0 - rise) * 40.0
		var g: float = float(lift[i]) if i < lift.size() else 0.0
		if g > 0.01:
			draw_rect(r.grow(6.0), Color(1.0, 0.9, 0.55, 0.6 * a * g), false, 4.0)
		DDCardFace.hit_log = hits
		DDCardFace.draw_full(self, String(choices[i]), r, a * rise)
		DDCardFace.hit_log = null
		draw_string(font, Vector2(r.position.x, r.end.y + 26.0), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x, 18, Color(0.8, 0.78, 0.7, 0.8 * a))
	# Skip: grows and brightens under the mouse, with a glow round it
	var sr := drawn_skip_rect()
	var sc := Color(0.24, 0.62, 0.66).lerp(Color(0.38, 0.82, 0.86), skip_lift)
	if skip_lift > 0.01:
		draw_rect(sr.grow(5.0), Color(0.6, 1.0, 1.0, 0.5 * a * skip_lift), false, 4.0)
	draw_rect(sr, Color(sc.r, sc.g, sc.b, a), true)
	draw_rect(sr, Color(0.08, 0.2, 0.22, a), false, 3.0)
	var ssz := int(26.0 * (1.0 + SKIP_GROW * skip_lift))
	draw_string(font, Vector2(sr.position.x, sr.get_center().y + float(ssz) * 0.36), "Skip", HORIZONTAL_ALIGNMENT_CENTER,
		sr.size.x, ssz, Color(1, 1, 1, a))
	# the tooltip for the icon under the mouse
	last_hits = hits
	tip_hit = {}
	if a >= 1.0 and not done:
		for h in hits:
			if mouse.distance_to(h["c"]) <= float(h["r"]) + 2.0:
				tip_hit = h
		if not tip_hit.is_empty():
			_draw_tip(font, DDCardFace.tip_for(tip_hit), tip_hit["c"], float(tip_hit["r"]))


## A dark box with the icon's name and what it means, above the icon (below it
## if there is no room), kept on screen.
func _draw_tip(font: Font, tip: Array, at: Vector2, r: float) -> void:
	var vs := get_viewport_rect().size
	var title := String(tip[0])
	var body := String(tip[1])
	var w: float = clampf(maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x,
		font.get_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x) + 20.0, 120.0, 300.0)
	var body_h: float = font.get_multiline_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, 13).y
	var h: float = 34.0 + body_h
	var box := Rect2(at.x - w * 0.5, at.y - r - 10.0 - h, w, h)
	if box.position.y < 4.0:
		box.position.y = at.y + r + 10.0
	box.position.x = clampf(box.position.x, 4.0, vs.x - w - 4.0)
	draw_rect(box, Color(0.08, 0.07, 0.11, 0.95), true)
	draw_rect(box, Color(1.0, 0.88, 0.5, 0.9), false, 2.0)
	draw_string(font, box.position + Vector2(10.0, 22.0), title, HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, 16,
		Color(1.0, 0.9, 0.6))
	draw_multiline_string(font, box.position + Vector2(10.0, 42.0), body, HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, 13, -1,
		Color(0.9, 0.9, 0.92))
