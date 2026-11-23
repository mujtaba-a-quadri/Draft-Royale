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

## Fuel for the Fire (Run.fueled_now()): four cards, and the only ways out are
## Skip or Take 2, which then asks for a card to remove from the deck.
## phase "pick" (the offered cards) or "remove" (the deck, to drop one).
var fueled := false
var picked: Array = []
var phase := "pick"
var take_hover := false
var remove_hover := -1
var back_hover := false
## the relic this win brought (Run.last.relic), shown over the cards, or ""
var relic_id := ""
const RELIC_DB := preload("res://scripts/relic_db.gd")
const DECK_CARD := Vector2(124.0, 168.0)
const DECK_GAP := 12.0


func setup(p_arena: Node, p_choices: Array) -> void:
	arena = p_arena
	choices = p_choices.duplicate()


func _ready() -> void:
	# anchors AND offsets: anchors alone left the control 0 x 0, so the mouse
	# never reached it and only the keys worked
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	# the run is only reachable once this is in the tree (setup comes before)
	var run = get_node_or_null("/root/Run")
	if run != null:
		fueled = bool(run.fueled_now())
		relic_id = String(run.last.get("relic", ""))


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
	var over_any: bool = hover >= 0 or skip_hover or (take_hover and can_take_two()) or remove_hover >= 0 or back_hover
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over_any and ready_for_input() \
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
	# with Take 2 beside it, the pair is centred
	var shift: float = -(SKIP_SIZE.x * 0.5 + 16.0) if fueled else 0.0
	return Rect2(vs.x * 0.5 - SKIP_SIZE.x * 0.5 + shift, card_rect(0).end.y + 44.0, SKIP_SIZE.x, SKIP_SIZE.y)


## Fueled only: the Take 2 button, right of Skip.
func take_rect() -> Rect2:
	var s := skip_rect()
	return Rect2(s.end.x + 32.0, s.position.y, SKIP_SIZE.x, SKIP_SIZE.y)


func can_take_two() -> bool:
	return fueled and picked.size() == 2


## The remove step: the deck as small faces, in rows, centred.
func deck_cols() -> int:
	return 9


func deck_rect(i: int) -> Rect2:
	var vs := get_viewport_rect().size
	var run = get_node_or_null("/root/Run")
	var n: int = run.deck.size() if run != null else 0
	var cols := mini(deck_cols(), maxi(1, n))
	var total: float = float(cols) * DECK_CARD.x + float(cols - 1) * DECK_GAP
	var x0: float = (vs.x - total) * 0.5
	var row: int = int(float(i) / float(cols))
	return Rect2(x0 + float(i % cols) * (DECK_CARD.x + DECK_GAP), 250.0 + float(row) * (DECK_CARD.y + DECK_GAP),
		DECK_CARD.x, DECK_CARD.y)


func back_rect() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(vs.x * 0.5 - SKIP_SIZE.x * 0.5, vs.y - 120.0, SKIP_SIZE.x, SKIP_SIZE.y)


func _deck_at(p: Vector2) -> int:
	var run = get_node_or_null("/root/Run")
	if run == null:
		return -1
	for i in run.deck.size():
		if deck_rect(i).has_point(p):
			return i
	return -1


func _card_at(p: Vector2) -> int:
	for i in choices.size():
		if card_rect(i).has_point(p):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		if phase == "remove":
			hover = -1
			skip_hover = false
			take_hover = false
			remove_hover = _deck_at(event.position)
			back_hover = back_rect().has_point(event.position)
			return
		hover = _card_at(event.position)
		skip_hover = skip_rect().has_point(event.position)
		take_hover = fueled and take_rect().has_point(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not ready_for_input():
			return
		if phase == "remove":
			var d := _deck_at(event.position)
			if d >= 0:
				remove_card(d)
			elif back_rect().has_point(event.position):
				phase = "pick"
			return
		var i := _card_at(event.position)
		if i >= 0:
			if fueled:
				toggle(i)
			else:
				pick(i)
		elif skip_rect().has_point(event.position):
			skip()
		elif fueled and take_rect().has_point(event.position) and can_take_two():
			phase = "remove"


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# the screen owns the keyboard while it is up: Enter must not skip by accident
	get_viewport().set_input_as_handled()
	if not ready_for_input():
		return
	if phase == "remove":
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE:
			phase = "pick"
		return
	if event.keycode >= KEY_1 and event.keycode < KEY_1 + choices.size():
		if fueled:
			toggle(int(event.keycode - KEY_1))
		else:
			pick(int(event.keycode - KEY_1))
	elif event.keycode == KEY_S:
		skip()
	elif fueled and can_take_two() and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_T):
		phase = "remove"


## Fueled: a card in or out of the two being taken (never more than two).
func toggle(i: int) -> void:
	if done or i < 0 or i >= choices.size():
		return
	if picked.has(i):
		picked.erase(i)
	elif picked.size() < 2:
		picked.append(i)


## Fueled, the last step: deck card `d` goes, the two picked come in.
func remove_card(d: int) -> void:
	if done or not can_take_two():
		return
	var run = get_node_or_null("/root/Run")
	if run == null or d < 0 or d >= run.deck.size():
		return
	if not run.take_two(String(choices[int(picked[0])]), String(choices[int(picked[1])]), String(run.deck[d])):
		return
	done = true
	_finish()


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
	if phase == "remove":
		_draw_remove(font, vs, a)
		return
	if relic_id != "":
		_draw_relic_notice(font, vs, a)
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
	draw_string(font, ribbon.position + Vector2(0, 39.0), "Fuel for the Fire" if fueled else "Choose a Card",
		HORIZONTAL_ALIGNMENT_CENTER, bw, 30, Color(0.24, 0.16, 0.08, a))
	var run = get_node_or_null("/root/Run")
	if run != null:
		var sub := "one goes into your deck (%d cards)  ·  or skip" % run.deck.size()
		if fueled:
			sub = "take 2 and remove 1 from your deck  ·  or skip (the next one stays like this)"
		elif run.relics.has("fuel"):
			sub += "  (skipping lights Fuel for the Fire)"
		draw_string(font, Vector2(0, ribbon.end.y + 24.0), sub, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 16,
			Color(0.85, 0.82, 0.74, a))
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
		if picked.has(i):
			# one of the two being taken: a green frame and a tick
			draw_rect(r.grow(8.0), Color(0.45, 0.95, 0.55, a), false, 5.0)
			var tc := Vector2(r.end.x - 4.0, r.position.y + 4.0)
			draw_circle(tc, 18.0, Color(0.2, 0.62, 0.3, a))
			draw_arc(tc, 18.0, 0.0, TAU, 24, Color(1, 1, 1, a), 2.0, true)
			draw_polyline(PackedVector2Array([tc + Vector2(-8, 0), tc + Vector2(-2, 7), tc + Vector2(9, -7)]),
				Color(1, 1, 1, a), 3.5, true)
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
	if fueled:
		# Take 2: lit only once two cards are picked
		var tr := take_rect()
		var ready2 := can_take_two()
		var tcol := Color(0.86, 0.5, 0.18) if ready2 else Color(0.32, 0.3, 0.3)
		if ready2 and take_hover:
			tcol = tcol.lightened(0.15)
			draw_rect(tr.grow(5.0), Color(1.0, 0.8, 0.5, 0.5 * a), false, 4.0)
		draw_rect(tr, Color(tcol.r, tcol.g, tcol.b, a), true)
		draw_rect(tr, Color(0.2, 0.1, 0.05, a), false, 3.0)
		draw_string(font, Vector2(tr.position.x, tr.get_center().y + 9.0), "Take 2 (%d/2)" % picked.size(),
			HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 26, Color(1, 1, 1, a if ready2 else 0.55 * a))
	# the tooltip for the icon under the mouse
	last_hits = hits
	tip_hit = {}
	if a >= 1.0 and not done:
		for h in hits:
			if mouse.distance_to(h["c"]) <= float(h["r"]) + 2.0:
				tip_hit = h
		if not tip_hit.is_empty():
			_draw_tip(font, DDCardFace.tip_for(tip_hit), tip_hit["c"], float(tip_hit["r"]))


## "Relic gained": the medallion, its name and what it does, across the top.
func _draw_relic_notice(font: Font, vs: Vector2, a: float) -> void:
	var box := Rect2(vs.x * 0.5 - 330.0, 18.0, 660.0, 74.0)
	draw_rect(box, Color(0.1, 0.08, 0.05, 0.92 * a), true)
	draw_rect(box, Color(1.0, 0.82, 0.4, a), false, 2.5)
	DDArt.relic_medal(self, relic_id, box.position + Vector2(44.0, 37.0), 27.0, 0.0, -1, 0.0, t)
	draw_string(font, box.position + Vector2(86.0, 28.0), "RELIC GAINED:  %s" % RELIC_DB.relic_name(relic_id),
		HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 100.0, 18, Color(1.0, 0.88, 0.55, a))
	draw_string(font, box.position + Vector2(86.0, 54.0), String(RELIC_DB.get_relic(relic_id).get("text", "")),
		HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 100.0, 14, Color(0.92, 0.9, 0.85, a))


## Fueled, step 2: the whole deck, click the card to remove; Back returns.
func _draw_remove(font: Font, vs: Vector2, a: float) -> void:
	var run = get_node_or_null("/root/Run")
	if run == null:
		return
	draw_string(font, Vector2(0, 150.0), "Remove a card from your deck", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 30,
		Color(1.0, 0.86, 0.55, a))
	var taking := "%s  +  %s" % [DDCard.pretty(String(choices[int(picked[0])])), DDCard.pretty(String(choices[int(picked[1])]))]
	draw_string(font, Vector2(0, 186.0), "taking  %s   ·   click the card to lose" % taking, HORIZONTAL_ALIGNMENT_CENTER,
		vs.x, 16, Color(0.85, 0.82, 0.74, a))
	for i in run.deck.size():
		var r := deck_rect(i)
		if i == remove_hover:
			r = r.grow(5.0)
		DDCardFace.draw(self, String(run.deck[i]), r, a)
		if i == remove_hover:
			draw_rect(r.grow(3.0), Color(1.0, 0.35, 0.3, a), false, 4.0)
			draw_line(r.position + Vector2(14, 14), r.end - Vector2(14, 14), Color(1.0, 0.3, 0.25, 0.85 * a), 5.0, true)
			draw_line(Vector2(r.end.x - 14, r.position.y + 14), Vector2(r.position.x + 14, r.end.y - 14),
				Color(1.0, 0.3, 0.25, 0.85 * a), 5.0, true)
	var br := back_rect()
	draw_rect(br, Color(0.3, 0.32, 0.38, a) if not back_hover else Color(0.4, 0.43, 0.5, a), true)
	draw_rect(br, Color(0.1, 0.1, 0.14, a), false, 3.0)
	draw_string(font, Vector2(br.position.x, br.get_center().y + 9.0), "Back", HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 26,
		Color(1, 1, 1, a))


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
