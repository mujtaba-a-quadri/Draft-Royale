class_name DDHandCard
extends Control

## One card in a hand. It owns its rect, its hover / lift / return state, the
## tween that animates those transitions, and everything it draws about them.
## A hand panel only binds it to a slot and routes mouse input.
##
## A card is either sitting in its slot or lifted:
##
## * in the slot it is full colour when the player can pay for it, and washed
##   dark grey and see-through with a light grey fill rising from the bottom for
##   every part of its cost the player already holds;
## * lifted — by a press-and-drag, or by a plain click — it follows the cursor,
##   and over the board it snaps to the grid as a transparent ghost of itself;
## * however it ends (deployed, cancelled, put back) it flies into its slot
##   instead of snapping there.

enum S { IDLE, HOVER, DRAG, RETURN }

## Hover grows the card in place and lifts it above the strip.
const GROW := 1.25
const HOVER_SHIFT := Vector2(-0.12, -0.95)
const HOVER_LIFT := 26.0
## How much of the old rise a hovered card keeps. 0.5 = it lifts half as far.
const HOVER_LIFT_SCALE := 0.5
const EDGE := 8.0

## Over the board a lifted card shrinks to this and snaps to the grid, so the
## placement preview reads as the card itself landing on a tile.
const GHOST_SIZE := Vector2(104.0, 128.0)
## Faint and without art, so the placement preview underneath stays readable.
const GHOST_ALPHA := 0.2

## A card the player cannot pay for yet: washed out, with a fill that climbs the
## card as the gold comes in.
const UNPLAYABLE_ALPHA := 0.55
const UNPLAYABLE_WASH := Color(0.08, 0.08, 0.11, 0.66)
const FILL := Color(0.82, 0.84, 0.90, 0.5)
const FILL_EDGE := Color(0.96, 0.97, 1.0, 0.85)
## A cost the player cannot pay yet is red; it flashes when they try anyway.
const COST_RED := Color(0.88, 0.2, 0.16)
const COST_FLASH := Color(1.0, 0.93, 0.45)

## Seconds a lifted card takes to fly back into its slot.
const RETURN_TIME := 0.34

## Lifted cards draw over the arena's own deploy ghost (z_index 16).
const LIFT_Z := 20

var panel: Control = null
var player := 0
var index := -1
var kind := ""
## which copy of `kind` this node is showing (arena.hand_ids); duplicates in a
## hand share a kind but never an id
var card_id := -1
var back := false
var grow := true
var home := Rect2()
var state: int = S.IDLE
var on_board := false
var rejected := false
## The art window is drawn empty: a hovered card with troops behind its art, and
## the ghost over the board.
var art_hidden := false:
	set(value):
		if value != art_hidden:
			art_hidden = value
			queue_redraw()
var alpha := 1.0:
	set(value):
		var c := clampf(value, 0.0, 1.0)
		if absf(c - alpha) < 0.001:
			return
		alpha = c
		queue_redraw()

var _lift_size := Vector2.ZERO
var _meter := -1
var _t := 0.0
var _tween: Tween = null


func setup(p_panel: Control, p_player: int, p_index: int) -> void:
	name = "HandCard%d" % p_index
	panel = p_panel
	player = p_player
	index = p_index
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	visible = false
	set_process(true)


## Bind a card kind to this slot, and whether it shows its face or its back.
func set_card(p_kind: String, p_back: bool, p_id: int = -1) -> void:
	card_id = p_id
	if p_kind == kind and p_back == back:
		return
	kind = p_kind
	back = p_back
	_meter = -1
	queue_redraw()


## Where the panel wants the card to sit while it is not lifted.
func set_slot(r: Rect2) -> void:
	if r == home:
		return
	home = r
	if state == S.IDLE:
		_set_rect(home)
	queue_redraw()


func hover_rect() -> Rect2:
	var box: Vector2 = home.size * GROW
	var at: Vector2 = home.position + home.size * HOVER_SHIFT
	var room: Vector2 = panel.size if panel != null else home.end
	at.x = clampf(at.x, EDGE, room.x - box.x - EDGE)
	var risen: float = -box.y + HOVER_LIFT
	# lift only part of the way out of the strip
	at.y = home.position.y - (home.position.y - risen) * HOVER_LIFT_SCALE
	return Rect2(at, box)


## Lift the card out of the strip. From here it follows the cursor whether or not
## the mouse button is still held, so a click and a drag are the same gesture.
func begin_drag() -> void:
	_kill_tween()
	state = S.DRAG
	on_board = false
	_lift_size = home.size if home.size.x > 0.0 else size
	z_index = LIFT_Z
	if panel != null:
		_set_rect(Rect2(panel.get_local_mouse_position() - _lift_size * 0.5, _lift_size))
	queue_redraw()


## Done with the card: fly it back into its slot rather than snapping it there.
func end_drag() -> void:
	if state != S.DRAG:
		return
	on_board = false
	state = S.RETURN
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", home.position, RETURN_TIME)
	_tween.parallel().tween_property(self, "size", home.size, RETURN_TIME)
	_tween.parallel().tween_property(self, "alpha", 1.0, RETURN_TIME)
	_tween.finished.connect(_on_returned)


## A card arriving into the hand: it starts out where the play happened and flies
## into its slot, the same way a cancelled card flies home — just slower, and with
## a little longer to travel when it comes from across the board.
func fly_in_from(world: Vector2) -> void:
	if panel == null:
		return
	_kill_tween()
	state = S.RETURN
	z_index = LIFT_Z
	var travel: float = world.distance_to(panel.global_position + home.get_center())
	var dur: float = clampf(0.34 + travel / 2600.0, RETURN_TIME, 0.62)
	_set_rect(Rect2(world - panel.global_position - home.size * 0.5, home.size))
	alpha = 0.85
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", home.position, dur)
	_tween.parallel().tween_property(self, "size", home.size, dur)
	_tween.parallel().tween_property(self, "alpha", 1.0, dur)
	_tween.finished.connect(_on_returned)
	queue_redraw()


## The card that was just played vanishes into the play instead of flying home —
## whatever replaces it is the thing that does the flying.
func retire_play() -> void:
	_kill_tween()
	state = S.IDLE
	z_index = 0
	visible = false
	queue_redraw()


func _on_returned() -> void:
	state = S.IDLE
	z_index = 0
	_set_rect(home)
	alpha = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if panel == null or not visible:
		return
	_t += delta
	var flash := _panel_bool("is_rejected", index)
	if flash != rejected:
		rejected = flash
		queue_redraw()
	elif rejected:
		queue_redraw()
	var m: Vector2 = panel.get_local_mouse_position()
	if state == S.DRAG:
		_tick_drag(m)
		_refresh_meter()
		return
	if state == S.RETURN:
		queue_redraw()
		return
	if grow and home.has_point(m):
		state = S.HOVER
		var r := hover_rect()
		_set_rect(r)
		var g := Rect2(panel.global_position + r.position, r.size)
		alpha = _panel_float("hover_alpha_for", g, 1.0)
		var a := DDCardFace.art_rect(kind, g)
		art_hidden = _panel_bool("units_under", a)
	else:
		state = S.IDLE
		_set_rect(home)
		alpha = 1.0
		art_hidden = false
	_refresh_meter()


## Over the board the card becomes a transparent ghost of itself snapped to the
## tile it would land on; anywhere else it rides the cursor at full size.
func _tick_drag(m: Vector2) -> void:
	if _panel_bool("is_over_board", m):
		var at: Vector2 = _panel_vec("snap_world", m, m) - panel.global_position
		_set_rect(Rect2(at - GHOST_SIZE * 0.5, GHOST_SIZE))
		alpha = GHOST_ALPHA
		art_hidden = true
		return
	_set_rect(Rect2(m - _lift_size * 0.5, _lift_size))
	alpha = 1.0
	art_hidden = false


## Redraw only when the gold meter visibly moved, not every frame. Floor, not
## round: 64 must mean "paid for", or a card that is a sliver short snaps to the
## top of the scale and then never repaints when the last coin lands.
func _refresh_meter() -> void:
	var q := int(floor(_panel_float("gold_fraction", kind, 1.0) * 64.0))
	if q == _meter:
		return
	_meter = q
	queue_redraw()


func _set_rect(r: Rect2) -> void:
	if position == r.position and size == r.size:
		return
	position = r.position
	size = r.size
	queue_redraw()


## The card's rules about the board and the player's gold live in the panel,
## which is the only thing holding the arena. The card asks through these hooks
## rather than taking a typed reference, which would make the two scripts depend
## on each other.
func _panel_float(method: String, arg, fallback: float) -> float:
	if panel == null or not panel.has_method(method):
		return fallback
	return float(panel.call(method, arg))


func _panel_int(method: String, arg, fallback: int) -> int:
	if panel == null or not panel.has_method(method):
		return fallback
	return int(panel.call(method, arg))


func _panel_bool(method: String, arg) -> bool:
	if panel == null or not panel.has_method(method):
		return false
	return bool(panel.call(method, arg))


func _panel_vec(method: String, arg, fallback: Vector2) -> Vector2:
	if panel == null or not panel.has_method(method):
		return fallback
	return Vector2(panel.call(method, arg))


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _draw() -> void:
	if kind == "" or size.x < 26.0:
		return
	var r := Rect2(Vector2.ZERO, size)
	if back:
		_draw_back(r)
		return
	var paid := _panel_float("gold_fraction", kind, 1.0)
	var cost_col := Color(0, 0, 0, 0)
	if paid < 1.0:
		cost_col = COST_RED
		if rejected:
			cost_col = COST_RED.lerp(COST_FLASH, absf(sin(_t * 16.0)))
	# over the board the art is blanked so the placement preview reads clearly;
	# a hovered card drops it only while troops stand behind the art window
	var hide_art: bool = art_hidden and state != S.IDLE and state != S.RETURN
	if paid >= 1.0:
		DDCardFace.draw(self, kind, r, alpha, cost_col, hide_art)
		_draw_used_charge(r)
		return
	# unplayable: dark, see-through, filling from the bottom with the gold held.
	# The two fades never stack — a hovered or ghosted card keeps the stronger one.
	var paper := minf(alpha, UNPLAYABLE_ALPHA)
	DDCardFace.draw(self, kind, r, paper, cost_col, hide_art)
	draw_rect(r, UNPLAYABLE_WASH, true)
	var fh: float = r.size.y * paid
	if fh > 0.5:
		var band := Rect2(r.position.x, r.end.y - fh, r.size.x, fh)
		draw_rect(band, FILL, true)
		draw_line(Vector2(band.position.x, band.position.y), Vector2(band.end.x, band.position.y),
			FILL_EDGE, 2.0)
	draw_rect(r, Color(0.12, 0.11, 0.15, 0.85), false, 2.0)
	if rejected:
		# "you cannot place that": a red pulse around the whole card
		draw_rect(r, Color(1.0, 0.3, 0.24, 0.35 + 0.55 * absf(sin(_t * 16.0))), false, 3.0)
	_draw_used_charge(r)


## A multi-use card that has spent a charge (Firebolt after its first throw) is
## shaded over the half already used: the triangle below the diagonal running from
## the bottom left corner to the top right one.
func _draw_used_charge(r: Rect2) -> void:
	var total := int(DDCard.get_card(kind).get("uses", 1))
	if total <= 1:
		return
	var left := _panel_int("charges_left", card_id, total)
	if left >= total or left <= 0:
		return
	draw_colored_polygon(PackedVector2Array([
		Vector2(r.position.x, r.end.y),
		Vector2(r.end.x, r.end.y),
		Vector2(r.end.x, r.position.y),
	]), Color(0.05, 0.04, 0.07, 0.34))
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y),
		Color(0.02, 0.02, 0.03, 0.5), 1.5, true)


func _draw_back(r: Rect2) -> void:
	draw_rect(r, Color(0.1, 0.08, 0.09))
	draw_rect(r.grow(-3.0), Color(0.92, 0.74, 0.2), false, 2.0)
	draw_rect(r.grow(-7.0), Color(0.85, 0.15, 0.15), false, 1.5)
	for i in 5:
		var y := r.position.y + r.size.y * (0.16 + float(i) * 0.14)
		var col := Color(0.9, 0.72, 0.18) if i % 2 == 0 else Color(0.12, 0.1, 0.1)
		draw_rect(Rect2(r.position.x + r.size.x * 0.16, y, r.size.x * 0.68, r.size.y * 0.07), col)
	var c := r.get_center()
	draw_circle(c, r.size.x * 0.24, Color(0.12, 0.1, 0.1))
	draw_circle(c, r.size.x * 0.24, Color(0.92, 0.74, 0.2), false, 2.0)
	for i in 8:
		var ang := TAU * float(i) / 8.0
		draw_line(c, c + Vector2(cos(ang), sin(ang)) * r.size.x * 0.2, Color(0.85, 0.15, 0.15), 2.0, true)
