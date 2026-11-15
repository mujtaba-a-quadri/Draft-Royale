class_name HandPanel
extends Control

## Bottom hand strip. Cards are compact TCG faces; hovering enlarges one,
## dragging pulls it out at normal size, and dropping it on the board deploys.
## While the cursor is over the board the dragged card fades out so the board's
## own deploy preview takes over.

const SIDE := 16.0
const GAP := 12.0

var player := 0
var arena: Node2D = null
var compact := false
var clock := 0.0
var hover := -1
var dragging := -1
var drag_pos := Vector2.ZERO
var shelf_hover := -1
var toggle_rect := Rect2()
var ability_rect := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false


func shelf_mode() -> bool:
	return arena != null and arena.debug_shelf and player == 0


func card_w() -> float:
	if compact:
		return 96.0
	return 190.0


func card_h() -> float:
	if compact:
		return 62.0
	return 168.0


func hand() -> Array:
	return arena.hands[player] if arena != null else []


func card_rect(i: int) -> Rect2:
	var n: int = hand().size()
	var cw := card_w()
	var ch := card_h()
	var total: float = float(n) * cw + float(maxi(n - 1, 0)) * GAP
	var x0: float = (size.x - total) * 0.5 + 150.0
	return Rect2(x0 + float(i) * (cw + GAP), size.y - ch - 6.0, cw, ch)


func hit_card(p: Vector2) -> int:
	var h: Array = hand()
	for i in h.size():
		if card_rect(i).has_point(p):
			return i
	return -1


func _process(delta: float) -> void:
	clock += delta
	if arena != null:
		var m := get_local_mouse_position()
		hover = hit_card(m) if not shelf_mode() else hover
		if dragging >= 0:
			drag_pos = m
	queue_redraw()


func _draw() -> void:
	if arena == null:
		return
	var font := ThemeDB.fallback_font
	var accent: Color = Color(0.36, 0.62, 0.95) if player == 0 else Color(0.92, 0.4, 0.42)
	# backing
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.14, 0.94), true)
	draw_rect(Rect2(0, 0, size.x, 5.0), accent, true)
	if shelf_mode():
		_draw_shelf(font)
		return
	var h: Array = hand()
	# gold + labels on the left
	if not compact:
		DDArt.coin(self, Vector2(34, 30), 12.0)
		draw_string(font, Vector2(54, 37), "%d / %d" % [int(arena.gold[player]), int(arena.gold_max)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.98, 0.85, 0.45))
		draw_string(font, Vector2(20, 66), "PLAYER %d" % (player + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			accent.lightened(0.3))
		# next card, small
		if arena.queues[player].size() > 0:
			var nk := String(arena.queues[player][0])
			draw_string(font, Vector2(20, 96), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.62, 0.64, 0.74))
			DDCardFace.draw(self, nk, Rect2(18, 102, 92, 81), 0.9)
	# cards
	for i in h.size():
		if i == dragging:
			continue
		var r := card_rect(i)
		if i == hover:
			var grow := r.size * 1.3
			var pos := r.position + Vector2(-r.size.x * 0.15, -r.size.y * 0.3)
			pos.x = clampf(pos.x, 8.0, size.x - grow.x - 8.0)
			pos.y = maxf(pos.y, 4.0)
			DDCardFace.draw(self, String(h[i]), Rect2(pos, grow), 1.0)
		else:
			DDCardFace.draw(self, String(h[i]), r, 1.0)
	# dragged card follows the cursor, fading over the board
	if dragging >= 0 and dragging < h.size():
		var m := get_global_mouse_position()
		var over_board: bool = arena.board_rect().has_point(m)
		var a := 0.22 if over_board else 1.0
		var r2 := Rect2(drag_pos - Vector2(card_w(), card_h()) * 0.5, Vector2(card_w(), card_h()))
		DDCardFace.draw(self, String(h[dragging]), r2, a)
	if compact:
		return
	# buttons
	toggle_rect = Rect2(size.x - 232.0, 14.0, 216.0, 34.0)
	draw_rect(toggle_rect, Color(0.16, 0.16, 0.22, 1.0), true)
	draw_rect(toggle_rect, Color(0.5, 0.5, 0.62, 0.8), false, 2.0)
	draw_string(font, toggle_rect.position + Vector2(12, 23), "TAB — BOTH HANDS", HORIZONTAL_ALIGNMENT_CENTER,
		toggle_rect.size.x - 24.0, 14, Color(0.85, 0.86, 0.95))
	ability_rect = Rect2(size.x - 232.0, 56.0, 216.0, 74.0)
	_draw_ability(font)


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


## Releases are handled globally: once the drag leaves the strip the panel no
## longer receives mouse events, but the drop still has to land.
func _input(event: InputEvent) -> void:
	if arena == null or dragging < 0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var m := get_global_mouse_position()
		if arena.board_rect().has_point(m):
			arena.try_deploy_at(m)
		dragging = -1
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if arena == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			arena.clear_selection()
			accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var p: Vector2 = event.position
		if event.pressed:
			if shelf_mode():
				var idx := _shelf_hit(p)
				if idx >= 0:
					arena.pick_debug_card(String(DDCard.ORDER[idx]))
				accept_event()
				return
			if toggle_rect.has_point(p):
				arena.set_view_mode(1 - arena.view_mode)
				accept_event()
				return
			if ability_rect.has_point(p):
				arena.use_ability(player)
				accept_event()
				return
			var i := hit_card(p)
			if i >= 0:
				dragging = i
				drag_pos = get_local_mouse_position()
				arena.pick_card(player, i)
				accept_event()
				return
			arena.clear_selection()
			accept_event()
		else:
			if dragging >= 0:
				var over_board: bool = arena.board_rect().has_point(get_global_mouse_position())
				if over_board:
					arena.try_deploy_at(get_global_mouse_position())
				dragging = -1
				accept_event()
	elif event is InputEventMouseMotion:
		drag_pos = get_local_mouse_position()
		if shelf_mode():
			shelf_hover = _shelf_hit(get_local_mouse_position())


# ---------------------------------------------------------------- debug shelf

const SHELF_COLS := 4
const SHELF_TOP := 12.0
const SHELF_H := 96.0


func _shelf_cell(i: int) -> Rect2:
	var w := (size.x - SIDE * 2.0) / float(SHELF_COLS)
	var col := i % SHELF_COLS
	var row := i / SHELF_COLS
	return Rect2(SIDE + float(col) * w, SHELF_TOP + float(row) * SHELF_H, w - 8.0, SHELF_H - 8.0)


func _shelf_hit(p: Vector2) -> int:
	for i in DDCard.ORDER.size():
		if _shelf_cell(i).has_point(p):
			return i
	return -1


func _draw_shelf(font: Font) -> void:
	var kinds: Array = DDCard.ORDER
	draw_string(font, Vector2(SIDE, 30), "DEBUG — ALL CARDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(0.9, 0.92, 1.0))
	for i in kinds.size():
		var r := _shelf_cell(i)
		DDCardFace.draw(self, String(kinds[i]), r, 1.0 if shelf_hover == i else 0.92)
		if arena.debug_kind == String(kinds[i]):
			draw_rect(r, Color(1, 1, 1, 0.85), false, 3.0)
