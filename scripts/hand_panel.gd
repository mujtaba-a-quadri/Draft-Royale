class_name HandPanel
extends Control

## A player's hand. One DDHandCard node per hand slot owns that card's rect,
## its hover / drag / return state and its tween; the panel owns the layout
## policy (where a slot sits) and everything around the hand — backing, NEXT,
## the full-hand discard warning and the debug shelf.
##
## Pressing a card arms it for the arena and lifts its node out of the strip. The
## node follows the cursor from then on whether or not the button is still held —
## a click and a press-and-drag are the same gesture — and it snaps to the grid
## over the board. Releases are handled globally, because once the lifted card
## leaves the strip this Control stops receiving mouse events.

const GAP := 5.0
const HAND_LEFT := 249.0
const NEXT_CX := 1351.0
const NEXT_W := 100.0

## A hovered card is solid until troops stand behind it, then see-through (its
## art also drops while they are behind the art window: hand_card.gd).
const HOVER_ALPHA := 1.0
const HOVER_OCCLUDED_ALPHA := 0.4

## Opponent hand: one column of up to four cards, then a second column to its
## right — the first shrinks in width to make room for it.
const COL_MIN := 8.0
const COL_TOP := 34.0
const COL_GAP := 6.0
const COL_ROWS := 4
const COL_BOTTOM := 8.0

var player := 0
var arena: Node2D = null
var compact := false
var clock := 0.0
var toggle_rect := Rect2()
var ability_rect := Rect2()
var cards: Array = []
var drag_card: DDHandCard = null

## Opening deal. The hand itself is dealt instantly (the simulation never waits
## on this); the panel just holds the cards back and lets them fly in one per
## beat, in time with the draws in the deal sound. Both panels run the same
## clock, so the two hands fill together.
##   own hand      right to left, each card out of the NEXT box
##   opponent hand top to bottom, each card in from above the column
const DEAL_BEAT_FALLBACK := 0.24
var deal_started := false
var deal_hidden: Array = []
var deal_beat := 0.0
var deal_clock := 0.0
var deal_shown := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	_build_cards()


## One pooled node per possible hand slot. Slots are re-bound to a card kind
## instead of nodes being created and freed, so a slot keeps its node — and the
## tween it owns — across draws and deploys.
func _build_cards() -> void:
	if not cards.is_empty():
		return
	var slots: int = int(arena.HAND_MAX) if arena != null else 8
	for i in slots:
		var c := DDHandCard.new()
		c.setup(self, player, i)
		add_child(c)
		cards.append(c)


func shelf_mode() -> bool:
	return arena != null and arena.debug_shelf and player == 0


## Horizontal room between the last gold coin on our side and the NEXT slot.
func span_width() -> float:
	return NEXT_CX - NEXT_W * 0.5 - 12.0 - HAND_LEFT


func card_w() -> float:
	return DDCard.hand_size(span_width(), maxi(hand().size(), 1)).x


func card_h() -> float:
	return DDCard.hand_size(span_width(), maxi(hand().size(), 1)).y


func hand() -> Array:
	return arena.hands[player] if arena != null else []


## Slot rect for hand index i. The strip sizes its cards to the hand; the
## opponent column stacks them down the right edge instead.
func card_rect(i: int) -> Rect2:
	if compact:
		return column_rect(i)
	return Rect2(HAND_LEFT + float(i) * (card_w() + GAP), size.y - card_h() - 6.0, card_w(), card_h())


func column_rect(i: int) -> Rect2:
	var n: int = hand().size()
	var cols: int = 1 if n <= COL_ROWS else 2
	var col: int = int(float(i) / float(COL_ROWS))
	var row: int = i % COL_ROWS
	# every card in a column is the same size, sized so the whole column fits
	var rows: int = mini(maxi(n, 1), COL_ROWS)
	var avail_w: float = (size.x - COL_MIN * 2.0 - float(cols - 1) * COL_GAP) / float(cols)
	var avail_h: float = size.y - COL_TOP - COL_BOTTOM
	var ch: float = minf(avail_w * 1.45, (avail_h - float(rows - 1) * COL_GAP) / float(rows))
	return Rect2(COL_MIN + float(col) * (avail_w + COL_GAP),
		COL_TOP + float(row) * (ch + COL_GAP), avail_w, ch)


## The NEXT card's box. The "next up" progress line will trace this rect,
## starting and ending at its top-left corner.
func next_rect() -> Rect2:
	return Rect2(NEXT_CX - NEXT_W * 0.5, 96.0, NEXT_W, 88.0)


## Panel accent: the colour of the team this hand belongs to.
func accent_color() -> Color:
	return arena.team_color(player) if arena != null else Color(0.36, 0.62, 0.95)


func hit_card(p: Vector2) -> int:
	var n: int = hand().size()
	for c in cards:
		if not c.visible or c.state == DDHandCard.S.DRAG:
			continue
		if c.index < 0 or c.index >= n:
			continue
		if c.home.has_point(p):
			return c.index
	return -1


## Select a card the way a click does — used by the 1-8 keyboard shortcuts.
func select_index(i: int) -> void:
	# a card that has not been dealt onto the table yet cannot be picked up
	var h: Array = hand()
	if i >= 0 and i < h.size() and deal_hidden.has(arena.hand_id(player, i)):
		return
	_press_card(i)


## Queue the opening hand for the deal: every card starts held back, in the order
## it will be shown. One beat is one draw in the deal sound.
func _begin_deal() -> void:
	deal_started = true
	var h: Array = hand()
	deal_hidden = []
	for k in h.size():
		# own hand fills from the right; the opponent's column from the top
		deal_hidden.append(arena.hand_id(player, k if compact else h.size() - 1 - k))
	deal_beat = DEAL_BEAT_FALLBACK
	var sfx = arena.get("sfx")
	if sfx != null and is_instance_valid(sfx) and float(sfx.slice_seconds) > 0.0:
		deal_beat = float(sfx.slice_seconds)
	deal_clock = 0.0
	deal_shown = 0


## Let the next card go on each beat. It flies in through the same arrival path
## Pen uses, so it lands in its slot rather than popping into it.
func _tick_deal(delta: float) -> void:
	if deal_hidden.is_empty():
		return
	deal_clock += delta
	while not deal_hidden.is_empty() and deal_clock >= float(deal_shown) * deal_beat:
		var id := int(deal_hidden.pop_front())
		deal_shown += 1
		if arena.hand_index_of(player, id) < 0:
			continue
		var from: Vector2 = Vector2(size.x * 0.5, -30.0) if compact else next_rect().get_center()
		pending_arrivals[id] = global_position + from


func _process(delta: float) -> void:
	clock += delta
	if arena == null:
		return
	if not deal_started:
		_begin_deal()
	_tick_deal(delta)
	_sync_drag()
	_layout_cards()
	queue_redraw()


## Bind every hand slot to a card node for this frame, then let the cards place
## themselves. Nodes are matched to slots **by card copy** (arena.hand_ids), not
## by pool position or kind: when a full hand discards its leftmost card every
## index shifts, a hand can hold two of the same card, and the card the player is
## holding must stay the card they are holding.
func _layout_cards() -> void:
	var h: Array = hand()
	var shelf := shelf_mode()
	var faces: bool = int(arena.view_mode) == 1
	var pool: Array = cards.duplicate()
	var bound := {}
	var ids: Array = []
	for i in h.size():
		ids.append(arena.hand_id(player, i))
	# exact matches first, so a lifted card keeps its own node and its slot
	for i in mini(h.size(), cards.size()):
		for cand in pool:
			if int(cand.card_id) == int(ids[i]):
				bound[i] = cand
				pool.erase(cand)
				break
	# then any free node for the kinds that just arrived
	for i in mini(h.size(), cards.size()):
		if bound.has(i):
			continue
		for cand in pool:
			if cand.state == DDHandCard.S.DRAG or cand.state == DDHandCard.S.RETURN:
				continue
			bound[i] = cand
			pool.erase(cand)
			break
	for i in bound.keys():
		var c: DDHandCard = bound[i]
		var r := card_rect(int(i))
		if compact and r.end.y > size.y:
			c.visible = false
			continue
		c.index = int(i)
		c.set_slot(r)
		c.grow = not compact
		c.set_card(String(h[i]), compact and not faces, int(ids[i]))
		c.visible = not shelf
		if deal_hidden.has(int(ids[i])):
			# still in the deck as far as the eye is concerned
			c.visible = false
			continue
		if c.visible and pending_arrivals.has(int(ids[i])):
			var from: Vector2 = pending_arrivals[int(ids[i])]
			pending_arrivals.erase(int(ids[i]))
			c.fly_in_from(from)
	# whatever is left over is either flying home or not in the hand at all
	for c in pool:
		c.visible = c.state == DDHandCard.S.RETURN


# --------------------------------------------------------- board-facing hooks

func is_over_board(local: Vector2) -> bool:
	return arena != null and arena.board_rect().has_point(global_position + local)


## Where a lifted card previews. The arena owns the aiming rules — including the
## Firebolt's troop lock, which follows a troop instead of snapping to tiles.
func snap_world(local: Vector2) -> Vector2:
	var world: Vector2 = global_position + local
	return arena.aim_point(world) if arena != null else world


## Can this player pay for the card right now?
func can_afford(kind: String) -> bool:
	return arena != null and kind != "" and float(arena.gold[player]) >= float(DDCard.cost(kind))


## How much of the card's cost the player already holds (0..1).
func gold_fraction(kind: String) -> float:
	if arena == null or kind == "":
		return 1.0
	return clampf(float(arena.gold[player]) / float(maxi(DDCard.cost(kind), 1)), 0.0, 1.0)


## Any living troop under this global rect (a hovered card's art window).
func units_under(rect: Rect2) -> bool:
	return arena != null and arena.any_units_under(rect)


## Alpha a hovered card takes: solid, or see-through with troops behind it.
func hover_alpha_for(rect: Rect2) -> float:
	if arena != null and arena.any_units_under(rect):
		return HOVER_OCCLUDED_ALPHA
	return HOVER_ALPHA


# -------------------------------------------------------------------- drawing

func _draw() -> void:
	if arena == null:
		return
	var font := ThemeDB.fallback_font
	var accent := accent_color()
	# backing
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.14, 0.94), true)
	draw_rect(Rect2(0, 0, size.x, 5.0), accent, true)
	if shelf_mode():
		# the all-cards overlay draws itself
		return
	toggle_rect = Rect2()
	if compact:
		# the opponent column is nothing but cards: their nodes draw themselves
		return
	draw_string(font, Vector2(20, 152), "PLAYER %d" % (player + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		accent.lightened(0.3))
	_draw_next(font)
	# full hand: the leftmost card is about to be discarded on the next draw
	if hand().size() >= arena.HAND_MAX:
		_draw_discard_warning(font)


## NEXT slot at the right end of the strip; the draw timer is the edge trace.
func _draw_next(font: Font) -> void:
	if arena.queues[player].is_empty():
		return
	var r := next_rect()
	draw_string(font, Vector2(r.position.x, 90.0), "NEXT", HORIZONTAL_ALIGNMENT_CENTER, NEXT_W, 11,
		Color(0.62, 0.64, 0.74))
	DDCardFace.draw(self, String(arena.queues[player][0]), r, 0.9)
	var frac: float = 1.0 - clampf(float(arena.draw_timer[player]) / float(arena.draw_interval()), 0.0, 1.0)
	# the edge trace is the draw timer: no bar underneath it any more
	_next_progress_line(frac, hand().size() >= arena.HAND_MAX)


## A line tracing the NEXT card's edge, starting and ending at its top-left
## corner, drawn up to the draw timer. It is your colour normally and the
## opponent's once the hand is full — the next draw throws a card away.
func _next_progress_line(frac: float, full: bool) -> void:
	var r := next_rect()
	var col: Color = arena.team_color(1 - player) if full else accent_color()
	var corners := [
		Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position,
	]
	var left: float = clampf(frac, 0.0, 1.0) * 2.0 * (r.size.x + r.size.y)
	var pts := PackedVector2Array([r.position])
	var prev: Vector2 = r.position
	for c in corners:
		if left <= 0.0:
			break
		var seg: float = prev.distance_to(c)
		if left >= seg:
			pts.append(c)
			left -= seg
		else:
			pts.append(prev.lerp(c, left / seg))
			left = 0.0
		prev = c
	if pts.size() < 2:
		return
	draw_polyline(pts, Color(0.05, 0.05, 0.07, 0.55), 5.0, true)
	draw_polyline(pts, col, 2.5, true)


## Red arrow pointing at the card that a draw would throw away.
func _draw_discard_warning(font: Font) -> void:
	var r := card_rect(0)
	var y := r.position.y + r.size.y * 0.5
	var pulse := 0.55 + 0.45 * absf(sin(clock * 5.0))
	var col := Color(1.0, 0.3, 0.3, 0.5 + 0.5 * pulse)
	# arrow points left, away from the card: triangle head on the far left,
	# dark grey body carrying the word
	var head := Vector2(r.position.x - 118.0, y)
	draw_colored_polygon(PackedVector2Array([
		head, head + Vector2(22.0, -16.0), head + Vector2(22.0, 16.0),
	]), col)
	var body := Rect2(head + Vector2(20.0, -9.0), Vector2(92.0, 18.0))
	draw_rect(body, Color(0.18, 0.18, 0.22, 0.95), true)
	draw_rect(body, Color(1.0, 0.35, 0.35, 0.9), false, 1.5)
	draw_string(font, body.position + Vector2(0, 14), "DISCARD", HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 13,
		Color(0.82, 0.82, 0.86, 0.75 + 0.25 * pulse))


## The opponent does not show a hand: their gold reads as ten coins instead.
## Full coins are solid, empty ones grey, and the one currently filling is drawn
## larger with a timer arc that only turns solid gold when it is whole.
func _draw_gold_pips(font: Font) -> void:
	var g: float = float(arena.gold[1])
	var maxp := int(arena.gold_max)
	var r := 9.0
	var step := 32.0
	var x0 := 16.0
	var cy := size.y * 0.5
	draw_string(font, Vector2(x0, cy + 5.0), "OPP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.6, 0.6))
	for i in maxp:
		var cx := x0 + 44.0 + float(i) * step
		var c := Vector2(cx, cy)
		var filled: float = clampf(g - float(i), 0.0, 1.0)
		if filled >= 1.0:
			draw_circle(c, r, Color(0.98, 0.78, 0.22))
			draw_circle(c + Vector2(-2.5, -2.5), r * 0.42, Color(1.0, 0.93, 0.6, 0.85))
			draw_arc(c, r, 0.0, TAU, 18, Color(0.55, 0.38, 0.05), 1.5, true)
		elif filled > 0.0:
			# in progress: bigger, greyed, filling with a near-white yellow
			draw_circle(c, r + 3.0, Color(0.32, 0.32, 0.36, 0.95))
			draw_arc(c, r + 3.0, -PI * 0.5, -PI * 0.5 + TAU * filled, 20, Color(1.0, 1.0, 0.82), 3.0, true)
			draw_arc(c, r + 3.0, 0.0, TAU, 20, Color(0.5, 0.5, 0.55), 1.2, true)
		else:
			draw_circle(c, r, Color(0.3, 0.3, 0.34))
			draw_arc(c, r, 0.0, TAU, 18, Color(0.45, 0.45, 0.5), 1.2, true)
	draw_string(font, Vector2(x0 + 44.0 + float(maxp) * step, cy + 5.0), "%d" % int(floor(g)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.98, 0.85, 0.45))


func _draw_ability(font: Font) -> void:
	var label: String = arena.ability_name(player)
	var ready: bool = arena.ability_ready(player)
	var cd: float = arena.ability_cd[player]
	draw_rect(ability_rect, Color(0.15, 0.15, 0.2, 1.0), true)
	draw_rect(ability_rect, Color(0.4, 0.85, 0.5, 0.9) if ready else Color(0.45, 0.45, 0.55, 0.8), false, 2.0)
	draw_string(font, ability_rect.position + Vector2(10, 24), label, HORIZONTAL_ALIGNMENT_LEFT,
		ability_rect.size.x - 20.0, 15, Color(0.92, 0.94, 1.0))
	var status := "READY · %d gold" % arena.ABILITY_COST if ready else "%.0fs" % ceilf(cd)
	draw_string(font, ability_rect.position + Vector2(10, 46), status, HORIZONTAL_ALIGNMENT_LEFT,
		ability_rect.size.x - 20.0, 12, Color(0.7, 0.85, 0.72) if ready else Color(0.7, 0.7, 0.8))
	if not ready:
		var f := clampf(cd / arena.ABILITY_COOLDOWN, 0.0, 1.0)
		draw_rect(Rect2(ability_rect.position + Vector2(2, ability_rect.size.y - 8),
			Vector2((ability_rect.size.x - 4.0) * (1.0 - f), 6.0)), Color(0.45, 0.8, 1.0, 0.8), true)


# ---------------------------------------------------------------------- input

## Releases are handled globally: once the lifted card leaves the strip the panel
## no longer receives mouse events, but the drop still has to land. A release
## that is not over the board leaves the card lifted and armed, which is what
## makes a plain click keep following the cursor just like a held drag.
func _input(event: InputEvent) -> void:
	if arena == null or drag_card == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var world := get_global_mouse_position()
		if arena.board_rect().has_point(world):
			arena.try_deploy_at(world)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if arena == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_drag()
			accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			if shelf_mode():
				# the all-cards grid owns that overlay; keep the strip inert
				accept_event()
				return
			if toggle_rect.has_point(event.position):
				arena.set_view_mode(1 - int(arena.view_mode))
				accept_event()
				return
			if ability_rect.has_point(event.position):
				arena.use_ability(player)
				accept_event()
				return
			var i := hit_card(event.position)
			if i >= 0:
				_press_card(i)
				accept_event()
				return
			arena.clear_selection()
			accept_event()
		else:
			accept_event()
	elif event is InputEventMouseMotion:
		pass


## A press lifts the card whether or not the player can pay for it — a card you
## cannot afford can still be picked up, it just cannot be carried into the arena.
## Pressing the card that is already out puts it back, and because the lift is
## driven by the lifted card rather than by the mouse button, holding the press
## and releasing it change nothing: a click followed by a move is a drag.
func _press_card(i: int) -> void:
	if arena.match_over:
		return
	var h: Array = hand()
	if i < 0 or i >= h.size():
		return
	if drag_card != null and int(drag_card.card_id) == arena.hand_id(player, i):
		arena.clear_selection()
		_end_drag()
		return
	arena.clear_selection()
	arena.pick_card(player, i)
	_begin_drag(i)


func _begin_drag(i: int) -> void:
	_end_drag()
	for c in cards:
		if c.index == i and c.visible:
			drag_card = c
			c.begin_drag()
			return


## Keep the lifted card honest: it heads home when the arena drops the selection
## (deploy, Esc, right click, an empty click) and when it is carried back off the
## board. A card the player cannot pay for is still held and still aimed — the
## arena decides what a placement costs at the moment it would land.
func _sync_drag() -> void:
	if drag_card == null:
		return
	if not _armed(drag_card):
		_end_drag()
		return
	if is_over_board(get_local_mouse_position()):
		drag_card.on_board = true
	elif drag_card.on_board:
		cancel_drag()


## Throw the armed card away; it flies back into the hand.
func cancel_drag() -> void:
	arena.clear_selection()
	_end_drag()


## The card is done with the cursor; it flies into whatever slot it has now.
func _end_drag() -> void:
	if drag_card == null:
		return
	drag_card.end_drag()
	drag_card = null


## Selection is tracked by card copy, not by slot index or kind: a hand can hold
## two of a card, and a discard can shuffle the slots under the player's feet.
func _armed(card: DDHandCard) -> bool:
	if arena.debug_kind != "" or arena.selected_player != player:
		return false
	return arena.selection_id() == int(card.card_id)


## Casts left on this copy (2 for a fresh Firebolt, 1 after the first throw).
func charges_left(id: int) -> int:
	if arena == null:
		return 1
	var i: int = arena.hand_index_of(player, id)
	if i < 0:
		return 1
	return arena.charges_of(player, String(hand()[i]), id)


## True while this slot's cost should be flashing (the player just tried to place
## something they cannot pay for).


func is_rejected(i: int) -> bool:
	if arena == null:
		return false
	if int(arena.reject["player"]) != player or int(arena.reject["index"]) != i:
		return false
	return float(arena.reject["timer"]) > 0.0


# (the debug shelf is a DDCardGrid overlay owned by the arena)


# ------------------------------------------------------------ card arrivals

## Cards that have to fly into the hand rather than simply appearing (Pen, when
## Penny is played). Keyed by card id, consumed by the next layout pass.
var pending_arrivals := {}


## `id` is the card arriving, `played_id` the copy it replaces.
func note_arrival(id: int, world: Vector2, played_id: int = -1) -> void:
	pending_arrivals[id] = world
	# the card being replaced does not fly home as well
	if drag_card != null:
		drag_card.retire_play()
		drag_card = null
	for c in cards:
		if int(c.card_id) == played_id and c.state == DDHandCard.S.RETURN:
			c.retire_play()
