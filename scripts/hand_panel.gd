class_name HandPanel
extends Control

## One player's hand. Width adapts to the panel so the same scene works in the
## solo layout (cards on the left third) and the dual hotseat layout.

const CARD_TOP := 112.0
const CARD_H := 132.0
const CARD_PITCH := 144.0
const SIDE := 14.0

var player := 0
var arena: Node2D = null
var hover := -1
var clock := 0.0
var toggle_rect := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()


func _team_color() -> Color:
	return Arena.BLUE if player == 0 else Arena.RED


func card_w() -> float:
	return size.x - SIDE * 2.0


func ability_rect() -> Rect2:
	return Rect2(size.x - 178.0, 8.0, 164.0, 46.0)


func _card_rect(i: int) -> Rect2:
	return Rect2(SIDE, CARD_TOP + float(i) * CARD_PITCH, card_w(), CARD_H)


func _draw() -> void:
	if arena == null:
		return
	var font := ThemeDB.fallback_font
	var accent := _team_color()
	var full := Rect2(Vector2.ZERO, size)
	draw_rect(full, Color(0.1, 0.1, 0.14, 0.96), true)
	draw_rect(full, DDArt.OUTLINE, false, 3.0)
	draw_rect(Rect2(0, 0, size.x, 6.0), accent, true)

	draw_string(font, Vector2(24, 40), "PLAYER %d" % (player + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, accent.lightened(0.25))
	draw_string(font, Vector2(24, 62), "BOTTOM HALF" if player == 0 else "TOP HALF", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.72, 0.72, 0.8))

	var g: float = arena.gold[player]
	var gmax: float = arena.gold_max
	DDArt.coin(self, Vector2(32, 84), 11.0)
	draw_string(font, Vector2(50, 91), "%d / %d GOLD" % [int(floor(g)), int(gmax)], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.98, 0.85, 0.45))
	var pip_w := (card_w() - 16.0) / gmax
	for i in int(gmax):
		var px := SIDE + 16.0 + float(i) * pip_w
		var filled := g >= float(i + 1) - 0.001
		draw_rect(Rect2(px, 98, pip_w - 2.0, 4.0), Color(0.98, 0.8, 0.35, 0.95) if filled else Color(1, 1, 1, 0.1), true)

	# hero ability button
	var ar := ability_rect()
	var ready: bool = arena.ability_valid(player)
	var status: String = arena.ability_status(player)
	var accent2 := Color(0.4, 0.85, 0.45) if ready else Color(0.38, 0.38, 0.46)
	draw_rect(ar, Color(0.14, 0.14, 0.19, 1.0), true)
	draw_rect(ar, accent2, false, 2.0)
	draw_string(font, Vector2(ar.position.x + 10.0, ar.position.y + 18.0), arena.ability_name(player), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent2.lightened(0.35))
	draw_string(font, Vector2(ar.position.x + 10.0, ar.position.y + 37.0), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.95, 1.0))
	DDArt.coin(self, Vector2(ar.end.x - 24.0, ar.position.y + 23.0), 12.0)
	draw_string(font, Vector2(ar.end.x - 32.0, ar.position.y + 28.0), "%d" % Arena.ABILITY_COST, HORIZONTAL_ALIGNMENT_CENTER, 16, 14, Color(0.2, 0.13, 0.02))
	var cd: float = float(arena.ability_cd[player])
	if cd > 0.0:
		var frac := 1.0 - cd / Arena.ABILITY_COOLDOWN
		draw_rect(Rect2(ar.position.x, ar.end.y - 4.0, ar.size.x * frac, 3.0), accent2, true)

	var hand: Array = arena.hands[player]
	for i in hand.size():
		_draw_card(font, i, String(hand[i]))

	var nxt := Rect2(SIDE, CARD_TOP + float(hand.size()) * CARD_PITCH + 6.0, card_w(), 60.0)
	draw_rect(nxt, Color(0.14, 0.14, 0.19, 1.0), true)
	draw_rect(nxt, DDArt.OUTLINE, false, 2.0)
	draw_string(font, Vector2(nxt.position.x + 14.0, nxt.position.y + 21.0), "NEXT IN HAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.65, 0.65, 0.75))
	var queue: Array = arena.queues[player]
	if queue.size() > 0:
		var nk := String(queue[0])
		draw_string(font, Vector2(nxt.position.x + 14.0, nxt.position.y + 47.0),
			"%s  ·  %d gold" % [DDCard.pretty(nk), DDCard.cost(nk)], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.95))
		DDArt.icon(self, nk, Vector2(nxt.end.x - 44.0, nxt.position.y + 30.0), 17.0, clock)
	else:
		draw_string(font, Vector2(nxt.position.x + 14.0, nxt.position.y + 47.0), "empty", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.6, 0.6, 0.7))

	toggle_rect = Rect2(SIDE, size.y - 44.0, card_w(), 32.0)
	draw_rect(toggle_rect, Color(0.16, 0.16, 0.22, 1.0), true)
	draw_rect(toggle_rect, Color(0.5, 0.5, 0.62, 0.8), false, 2.0)
	draw_string(font, Vector2(toggle_rect.position.x + 12.0, toggle_rect.position.y + 22.0),
		"TAB — SHOW BOTH HANDS" if arena.view_mode == 0 else "TAB — SOLO VIEW",
		HORIZONTAL_ALIGNMENT_CENTER, card_w() - 24.0, 14, Color(0.85, 0.86, 0.95))


func _draw_card(font: Font, i: int, kind: String) -> void:
	var r := _card_rect(i)
	var data: Dictionary = DDCard.get_card(kind)
	var accent: Color = data["accent"]
	var cost := int(data["cost"])
	var affordable: bool = arena.gold[player] >= float(cost)
	var selected: bool = arena.selected_player == player and arena.selected_index == i

	draw_rect(r, Color(0.17, 0.17, 0.23, 1.0), true)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 5.0)), accent, true)
	draw_rect(r, DDArt.OUTLINE, false, 2.0)

	var badge := r.position + Vector2(38.0, 40.0)
	DDArt.coin(self, badge, 20.0)
	draw_string(font, Vector2(badge.x - 14, badge.y + 8), str(cost), HORIZONTAL_ALIGNMENT_CENTER, 28, 23, Color(0.2, 0.13, 0.02))

	DDArt.icon(self, kind, Vector2(r.end.x - 56.0, r.position.y + 96.0), 26.0, clock)

	draw_string(font, r.position + Vector2(70.0, 34.0), String(data["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.97, 0.97, 1.0))
	draw_multiline_string(font, r.position + Vector2(70.0, 55.0), String(data["blurb"]),
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 150.0, 12, 2, Color(0.72, 0.73, 0.8))
	var ctype := String(data["type"])
	var tag := "SPELL · play anywhere" if ctype == "spell" else ("STATIONARY" if bool(data["stationary"]) else "TROOP")
	draw_string(font, r.position + Vector2(70.0, 96.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent)

	if not affordable:
		draw_rect(r, Color(0.02, 0.02, 0.04, 0.55), true)
		draw_string(font, r.position + Vector2(70.0, 118.0), "need %d gold" % cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.58, 0.52))

	if arena.bot_hover_index(player) == i:
		var pulse := 0.55 + 0.45 * absf(sin(clock * 5.0))
		draw_rect(r.grow(3.0), Color(0.55, 0.85, 1.0, pulse), false, 4.0)
		draw_rect(r.grow(7.0), Color(0.55, 0.85, 1.0, 0.25), false, 2.0)
		draw_string(font, Vector2(r.position.x + 8.0, r.end.y - 10.0), "thinking...", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.65, 0.88, 1.0))
	if hover == i and affordable:
		draw_rect(r, Color(1, 1, 1, 0.45), false, 2.0)
	if selected:
		draw_rect(r.grow(3.0), accent, false, 4.0)
		draw_rect(r.grow(7.0), Color(accent, 0.3), false, 2.0)
		draw_string(font, Vector2(r.end.x - 196.0, r.end.y - 10.0), "CLICK THE BOARD TO PLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent.lightened(0.45))


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = event.position
	if toggle_rect.has_point(p):
		arena.set_view_mode(1 - arena.view_mode)
		accept_event()
		return
	if ability_rect().has_point(p):
		arena.use_ability(player)
		accept_event()
		return
	for i in arena.hands[player].size():
		if _card_rect(i).has_point(p):
			arena.pick_card(player, i)
			accept_event()
			return
	arena.pick_card(player, -1)
	accept_event()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var p := get_local_mouse_position()
		var hand: Array = arena.hands[player] if arena != null else []
		var found := -1
		for i in hand.size():
			if _card_rect(i).has_point(p):
				found = i
				break
		hover = found
