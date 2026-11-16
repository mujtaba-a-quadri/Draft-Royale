class_name Arena
extends Node2D

## Board shape: 30 rows tall. Rows 1..10 (top) and 19..28 (bottom) are 16 tiles
## wide; the middle band of 8 rows (11..18) bulges out to 18 tiles. The band is
## neutral no-man's land: you may only deploy inside it on tiles your ground
## troops have claimed within the last CLAIM_TIME seconds.

## Board shape and orientation live in DDBoard (scripts/board.gd) so units, bots
## and panels can share them; these aliases keep every TILE / ORIGIN / GRID_W
## reference in this file (and every caller's arena.TILE) working.
const TILE := DDBoard.TILE
const ORIGIN := DDBoard.ORIGIN
const GRID_W := DDBoard.GRID_W
const GRID_H := DDBoard.GRID_H
const OUTER_COL_MIN := DDBoard.OUTER_COL_MIN
const OUTER_COL_MAX := DDBoard.OUTER_COL_MAX
const BAND_TOP := DDBoard.BAND_TOP
const BAND_BOTTOM := DDBoard.BAND_BOTTOM
const RIVER_TOP := 14
const RIVER_BOTTOM := 15
const BRIDGE_COL_A := 5.0
const BRIDGE_COL_B := 13.0
const CLAIM_TIME := 4.0
const TOWER_BUFFER := 3.5
const ABILITY_COST := 2
const ABILITY_COOLDOWN := 15.0
## 150 second matches. The last 60 are the closing window: double gold, half
## ability cooldowns, draws one second faster.
const MATCH_TIME := 150.0
const OVERTIME := 60.0
const OVERTIME_GOLD := 2.0
const OVERTIME_DRAW_CUT := 1.0
const TENTACLE_HP := 20.0
const TENTACLE_DMG := 20.0
const TENTACLE_TIME := 4.0
const GOBLIN_DMG := 30.0

## Orientation. LANDSCAPE = true  â†’ your half on the LEFT, enemy on the RIGHT,
##                                   hand along the bottom of the screen.
##              LANDSCAPE = false â†’ the original portrait board: your half at the
##                                   BOTTOM, enemy at the top, hands on the sides.
## Everything else (simulation, art, effects) is orientation-agnostic â€” flip this
## one flag and the board turns, provided the HUD is laid out to match.
const LANDSCAPE := DDBoard.LANDSCAPE

##const GRASS_A := Color(0.45, 0.72, 0.38)
##const GRASS_B := Color(0.38, 0.62, 0.32)



const GRASS_A := Color(0.149, 0.42, 0.58, 1.0)
const GRASS_B := Color(0.33, 0.46, 0.24)
const BAND_A := GRASS_A
const BAND_B := Color(0.33, 0.46, 0.24)
const WATER := Color(0.678, 0.332, 0.139, 1.0)
const WATER_HI := Color(0.176, 0.007, 0.001, 1.0)
const WOOD := Color(0.62, 0.45, 0.3)
const Left_Color := Color(0.306, 0.517, 0.151, 1.0)
const Right_Color := Color(0.575, 0.153, 0.345, 1.0)

## Team colours are data, not literals: these two entries are the only reason
## you are blue and your opponent is red. Override them from a menu, a relic, a
## match type â€” or --colors=#ff8800,#22ccaa on the command line.
var team_colors: Array = [Left_Color, Right_Color]:
	set(value):
		team_colors = value
		# the control tint is a cached layer: repaint it for a colour change too
		if control_layer != null:
			control_layer.queue_redraw()

## Every unit, tower and tile tint is drawn in its team colour; unit outlines are
## a darker shade of it instead of black.
const TEAM_INK_DARKEN := 0.45

## Team colours are data, not literals: these two entries are the only reason
## you are blue and your opponent is red. Override them from a menu, a relic, a
## match type â€” or --colors=#ff8800,#22ccaa on the command line.
var team_colors: Array = [BLUE, RED]:
	set(value):
		team_colors = value
		# the control tint is a cached layer: repaint it for a colour change too
		if control_layer != null:
			control_layer.queue_redraw()

## Every unit, tower and tile tint is drawn in its team colour; unit outlines are
## a darker shade of it instead of black.
const TEAM_INK_DARKEN := 0.45

var towers: Array = []
var units: Array = []
var gold := [5.0, 5.0]
var gold_max := 10.0
var gold_rate := 1.0 / 2.4
## Remaining casts for cards that carry more than one (player -> kind -> casts). A
## card is only listed here once it has been used; an absent entry means "full".
var charges := [{}, {}]

## Seconds left in the match, and whether the closing window is live.
var match_time_left := MATCH_TIME
var overtime := false
const HAND_MAX := 8
const DRAW_INTERVAL := 8.0
var draw_timer := [DRAW_INTERVAL, DRAW_INTERVAL]
var hands := [[], []]
var queues := [[], []]
var selected_player := -1
var selected_index := -1

## A placement the player clicked on but cannot pay for yet (they were less than
## one coin short). Nothing is spent until it actually plays itself.
var staged := {"player": -1, "index": -1, "kind": "", "at": Vector2.ZERO}

## Re-entrancy guard for reflective damage (hedgehog quills poking back).
var damage_guard := 0

## Card whose cost is flashing after a placement the player cannot afford.
var reject := {"player": -1, "index": -1, "timer": 0.0}
const REJECT_TIME := 0.7
var match_over := false
var winner := -1
var clock := 0.0
var banner_text := ""
var banner_timer := 0.0
var shake_amount := 0.0
var shake_offset := Vector2.ZERO
var panels: Array = []
## The all-cards overlay (a reusable filtered, scrolling card grid).
var shelf_grid: DDCardGrid = null
var view_mode := 0
var bots: Array = [null, null]
var bot_players := [false, true]
var debug_shelf := false
var debug_kind := ""
var ability := ["tentacle", "shiesty"]
var ability_cd := [ABILITY_COOLDOWN, ABILITY_COOLDOWN]
var stat_shiesty_escaped := 0
var stat_shiesty_caught := 0
var control := [[], []]
var control_layer: Node2D = null
var preview: Node2D = null
var unit_tiles := {}
var reservations := {}


func _ready() -> void:
	for t in 2:
		var arr: Array = []
		arr.resize(GRID_W * GRID_H)
		arr.fill(false)
		control[t] = arr
	var forced := ""
	for a in OS.get_cmdline_user_args():
		if a == "--bots=both":
			bot_players = [true, true]
		elif a == "--bots=off":
			bot_players = [false, false]
		elif a.begins_with("--ability="):
			forced = a.substr(10)
		elif a.begins_with("--colors="):
			var parts := String(a.substr(9)).split(",")
			if parts.size() == 2:
				team_colors = [
<<<<<<< Updated upstream
					Color.from_string(String(parts[0]).strip_edges(), BLUE),
					Color.from_string(String(parts[1]).strip_edges(), RED),
=======
					Color.from_string(String(parts[0]).strip_edges(), Left_Color),
					Color.from_string(String(parts[1]).strip_edges(), Right_Color),
>>>>>>> Stashed changes
				]
	if forced == "tentacle":
		ability = ["tentacle", "shiesty"]
	elif forced == "shiesty" or forced == "goblin":
		ability = ["shiesty", "tentacle"]
	else:
		var arng := RandomNumberGenerator.new()
		arng.randomize()
		ability = ["tentacle", "shiesty"] if arng.randf() < 0.5 else ["shiesty", "tentacle"]
	_build_board_state()
	_build_control_layer()
	_build_preview()
	_build_decks()
	_build_hud()
	_build_shelf()
	_setup_bots()
	_dev_hook()
	queue_redraw()


func _setup_bots() -> void:
	bots = [null, null]
	for p in 2:
		if not bool(bot_players[p]):
			continue
		var b = DDBot.new()
		b.setup(self, p, 9001 + p * 7)
		add_child(b)
		bots[p] = b


func toggle_bot(p: int) -> void:
	bot_players[p] = not bool(bot_players[p])
	if bots[p] == null and bool(bot_players[p]):
		_setup_bots()
	elif bots[p] != null:
		bots[p].enabled = bool(bot_players[p])
	banner_flash("Bot %s for player %d" % ["ON" if bool(bot_players[p]) else "OFF", p + 1])


func bot_hover_index(p: int) -> int:
	if view_mode != 1:
		return -1
	if p < 0 or p >= bots.size():
		return -1
	var b = bots[p]
	if b == null or not is_instance_valid(b) or not b.enabled:
		return -1
	return int(b.hover_index)


func bot_target(p: int) -> Vector2:
	if view_mode != 1:
		return Vector2.INF
	if p < 0 or p >= bots.size():
		return Vector2.INF
	var b = bots[p]
	if b == null or not is_instance_valid(b) or not b.enabled or not b.armed:
		return Vector2.INF
	return b.pending_pos


# --------------------------------------------------------------------- teams

## The colour of a side. Everything that reads "blue" or "red" asks here.
func team_color(team: int) -> Color:
	return team_colors[clampi(team, 0, team_colors.size() - 1)]


## Unit and tower outlines: a darker shade of the owner's colour, not black.
func team_ink(team: int) -> Color:
	return team_color(team).darkened(TEAM_INK_DARKEN)


func _dev_hook() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--botsim="):
			var sim := DDBotSim.new()
			sim.setup(self, int(a.substr(9)))
			sim.name = "BotSim"
			add_child(sim)
			return
		if a.begins_with("--shots=") or a == "--demo" or a.begins_with("--scenario="):
			var dev: Node = load("res://scripts/dev_capture.gd").new()
			dev.arena = self
			dev.name = "DevCapture"
			add_child(dev)
			return


func _build_board_state() -> void:
	towers.clear()
	units.clear()
	for t in [
		[1, 9.0, 3.0, true], [1, 4.0, 7.0, false], [1, 14.0, 7.0, false],
		[0, 9.0, 27.0, true], [0, 4.0, 23.0, false], [0, 14.0, 23.0, false],
	]:
		var tw := DDTower.new()
		tw.setup(int(t[0]), self, bool(t[3]))
		tw.position = tile_center(float(t[1]), float(t[2]))
		towers.append(tw)
		add_child(tw)


func _build_preview() -> void:
	var p = DDDeployPreview.new()
	p.arena = self
	p.z_index = 16
	p.visible = false
	add_child(p)
	preview = p


func _build_control_layer() -> void:
	var layer := DDControlLayer.new()
	layer.arena = self
	layer.z_index = 2
	add_child(layer)
	control_layer = layer


## seed_value >= 0 makes the shuffle reproducible (the bot harness A/B needs it);
## the default keeps matches randomised for real play.
func _build_decks(seed_value: int = -1) -> void:
	charges = [{}, {}]
	for p in 2:
		var deck: Array = DDCard.ORDER.duplicate()
		var rng := RandomNumberGenerator.new()
		if seed_value >= 0:
			rng.seed = seed_value + p * 7919
		else:
			rng.randomize()
		for i in range(deck.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = deck[i]
			deck[i] = deck[j]
			deck[j] = tmp
		hands[p] = deck.slice(0, 4)
		queues[p] = deck.slice(4)
		gold[p] = 5.0


func _build_hud() -> void:
	for p in 2:
		var panel := HandPanel.new()
		panel.name = "HandPanel%d" % p
		panel.player = p
		panel.arena = self
		if p == 0:
			panel.compact = false
			panel.size = Vector2(1600.0, 196.0)
			panel.position = Vector2(0.0, 804.0)
		else:
			panel.compact = true
			# Tab view: the opponent's hand is a column down the right edge
			panel.size = Vector2(214.0, 700.0)
			panel.position = Vector2(1382.0, 56.0)
		add_child(panel)
		panels.append(panel)
	panels[1].visible = true


## The debug all-cards overlay. It is a DDCardGrid so the collection screen and
## the deck view can be built out of the same component.
func _build_shelf() -> void:
	shelf_grid = DDCardGrid.new()
	shelf_grid.name = "ShelfGrid"
	shelf_grid.position = Vector2(150.0, 636.0)
	shelf_grid.size = Vector2(1300.0, 360.0)
	shelf_grid.set_kinds(DDCard.all_kinds())
	shelf_grid.visible = false
	shelf_grid.card_pressed.connect(_on_shelf_card)
	add_child(shelf_grid)


func _on_shelf_card(kind: String) -> void:
	pick_debug_card(kind)


func _sync_shelf_selection() -> void:
	if shelf_grid != null:
		shelf_grid.selected_kind = debug_kind


## Called by the hand panel when a dragged card is dropped on the board.
## One coin per tile, laid along the bottom-left edge for blue and mirrored for
## red. Full coins are solid, spent ones grey, and the one filling right now is
## drawn larger with a near-white arc that only turns gold when it completes.
func _draw_gold_pieces() -> void:
	var maxp := int(gold_max)
	var r := TILE * 0.3
	for team in 2:
		for i in maxp:
			# blue runs along the bottom-left UI strip, red mirrored across the
			# vertical so it sits on their side of the board
			var ty := 29.5 - float(i) if team == 0 else 0.5 + float(i)
			var at: Vector2 = tile_center(17.5, ty)
			var filled: float = clampf(float(gold[team]) - float(i), 0.0, 1.0)
			if filled >= 1.0:
				draw_circle(at, r, Color(0.98, 0.78, 0.22))
				draw_circle(at + Vector2(-r * 0.3, -r * 0.3), r * 0.4, Color(1.0, 0.94, 0.62, 0.9))
				draw_arc(at, r, 0.0, TAU, 20, Color(0.55, 0.38, 0.05), 1.6, true)
			elif filled > 0.0:
				draw_circle(at, r * 1.35, Color(0.3, 0.3, 0.34, 0.95))
				draw_arc(at, r * 1.35, -PI * 0.5, -PI * 0.5 + TAU * filled, 22, Color(1.0, 1.0, 0.84), 3.2, true)
				draw_arc(at, r * 1.35, 0.0, TAU, 22, Color(0.52, 0.52, 0.58), 1.2, true)
			else:
				draw_circle(at, r, Color(0.28, 0.28, 0.32))
				draw_arc(at, r, 0.0, TAU, 18, Color(0.44, 0.44, 0.5), 1.2, true)


## Cards tick in every DRAW_INTERVAL seconds; drawing with a full hand throws
## away the leftmost card (the one furthest from where new cards arrive).
func draw_card(team: int) -> bool:
	if queues[team].is_empty():
		return false
	if hands[team].size() >= HAND_MAX:
		var dropped: String = hands[team][0]
		hands[team].remove_at(0)
		queues[team].append(dropped)
		# the hand shifted left by one: follow the same card, not the same index
		if selected_player == team:
			if selected_index == 0:
				# the card being held is the one thrown away
				clear_selection()
			elif selected_index > 0:
				selected_index -= 1
		if int(staged["player"]) == team:
			if int(staged["index"]) == 0:
				clear_staged()
			elif int(staged["index"]) > 0:
				staged["index"] = int(staged["index"]) - 1
	var k: String = queues[team].pop_front()
	hands[team].append(k)
	_reset_charges(team, k)
	return true


func _tick_draw(delta: float) -> void:
	if match_over:
		return
	for p in 2:
		draw_timer[p] = float(draw_timer[p]) - delta
		if float(draw_timer[p]) <= 0.0:
			draw_timer[p] = draw_interval()
			draw_card(p)


## True when any living unit stands inside this screen-space rect. Used to let
## the enlarged hover card fade so it does not hide the board (occlusion).
func any_units_under(rect: Rect2) -> bool:
	for u in units:
		if not is_instance_valid(u) or u.dead:
			continue
		if rect.has_point(u.position):
			return true
	return false


## The enemy troop a unit-locking card (the Firebolt) has locked onto under the
## cursor. Towers are never locked â€” those still use the tile.
func aim_lock(world: Vector2) -> Node:
	var kind := selection_kind()
	if kind == "" or not bool(DDCard.get_card(kind).get("unit_lock", false)):
		return null
	var e := _hovered_entity(world)
	if e == null or e.is_tower():
		return null
	if int(e.get("team")) == selection_owner():
		return null
	return e


## Point an armed card's preview and its placement aim at: a locked troop's live
## position (so it follows the troop smoothly), otherwise the snapped tile.
func aim_point(world: Vector2) -> Vector2:
	var locked := aim_lock(world)
	if locked != null:
		return locked.position
	var kind := selection_kind()
	if kind == "":
		return world
	var t := tile_of(world)
	var fp: Array = DDCard.get_card(kind).get("footprint", [1, 1])
	if int(fp[0]) > 1 or int(fp[1]) > 1:
		return footprint_layout(t, fp)["center"]
	return tile_center(float(t.x) + 0.5, float(t.y) + 0.5)


## Every placement lands here: the board click, the dragged release and a queued
## placement all go through the same affordability rules.
func try_deploy_at(world: Vector2) -> void:
	if match_over or selection_kind() == "":
		return
	if not board_rect().has_point(world):
		return
	if debug_kind != "":
		deploy_debug(world)
		return
	if selected_player < 0 or selected_index < 0:
		return
	var kind := selection_kind()
	# a unit-locking card casts on the troop it is aimed at, not on the tile
	var at: Vector2 = aim_point(world) if bool(DDCard.get_card(kind).get("unit_lock", false)) else world
	var missing: float = float(DDCard.cost(kind)) - float(gold[selected_player])
	if missing <= 0.0:
		deploy(selected_player, selected_index, at)
	elif missing < 1.0:
		# less than a coin away: hold the placement and play it on arrival
		stage_placement(selected_player, selected_index, at)
	else:
		# nothing is spent on a placement that cannot happen: flash the cost
		reject_placement(selected_player, selected_index)


## Hold a placement for the moment the gold arrives. The card keeps its slot in
## the hand, so nothing is spent and it can still be swapped out.
func stage_placement(player: int, index: int, world: Vector2) -> void:
	if player < 0 or index < 0 or index >= hands[player].size():
		return
	var kind := String(hands[player][index])
	staged = {"player": player, "index": index, "kind": kind, "at": world}
	banner_flash("Queued %s â€” %.1f gold short" % [DDCard.pretty(kind),
		float(DDCard.cost(kind)) - float(gold[player])])


func clear_staged() -> void:
	staged = {"player": -1, "index": -1, "kind": "", "at": Vector2.ZERO}


func staged_index(player: int) -> int:
	return int(staged["index"]) if int(staged["player"]) == player else -1


## Fire the queued placement once it is paid for. Picking another card, losing
## the selection or the card moving in the hand all cancel it.
func _tick_staged() -> void:
	var p := int(staged["player"])
	if p < 0:
		return
	var i := int(staged["index"])
	var kind := String(staged["kind"])
	if selected_player != p or selected_index != i:
		clear_staged()
		return
	if i < 0 or i >= hands[p].size() or String(hands[p][i]) != kind:
		clear_staged()
		return
	if float(gold[p]) < float(DDCard.cost(kind)):
		return
	var at: Vector2 = staged["at"]
	clear_staged()
	deploy(p, i, at)


## Flash a card's cost: the player asked to place something they cannot pay for.
func reject_placement(player: int, index: int) -> void:
	reject = {"player": player, "index": index, "timer": REJECT_TIME}
	shake(1.5)


func set_view_mode(m: int) -> void:
	view_mode = m
	if panels.size() == 2:
		panels[1].visible = true
		if m == 0:
			panels[1].size = Vector2(214.0, 700.0)
			panels[1].position = Vector2(1382.0, 56.0)
		else:
			panels[1].size = Vector2(214.0, 700.0)
			panels[1].position = Vector2(1382.0, 56.0)
	if m == 0 and selected_player == 1:
		selected_player = -1
		selected_index = -1
	queue_redraw()


# --------------------------------------------------------------------- clock

## Gold per second a player earns right now.
func gold_rate_now() -> float:
	return gold_rate * (OVERTIME_GOLD if overtime else 1.0)


## How long a card draw takes right now (one second faster in the closing window).
func draw_interval() -> float:
	return maxf(1.0, DRAW_INTERVAL - (OVERTIME_DRAW_CUT if overtime else 0.0))


## How long an ability cooldown started right now will be (halved in the window).
func ability_cooldown_time() -> float:
	return ABILITY_COOLDOWN * (0.5 if overtime else 1.0)


## How many casts this card has left in this player's hand (1 for normal cards).
func charges_of(player: int, kind: String) -> int:
	var total := int(DDCard.get_card(kind).get("uses", 1))
	if total <= 1 or player < 0 or player > 1:
		return 1
	return int((charges[player] as Dictionary).get(kind, total))


func _reset_charges(team: int, kind: String) -> void:
	if team >= 0 and team <= 1:
		(charges[team] as Dictionary).erase(kind)


func _tick_clock(delta: float) -> void:
	match_time_left = maxf(0.0, match_time_left - delta)
	if not overtime and match_time_left <= OVERTIME:
		overtime = true
		# a cooldown already running gets shortened too, so the switch is felt
		ability_cd = [minf(float(ability_cd[0]), ability_cooldown_time()),
			minf(float(ability_cd[1]), ability_cooldown_time())]
		banner_flash("FINAL MINUTE  â€”  DOUBLE GOLD")
		return
	if match_time_left <= 0.0:
		_finish_on_towers()


## Time up: the match goes to whoever has more tower HP left, not more towers.
func _finish_on_towers() -> void:
	if match_over:
		return
	var hp := [0.0, 0.0]
	for tw in towers:
		if is_instance_valid(tw) and not tw.dead:
			hp[int(tw.team)] += float(tw.hp)
	match_over = true
	banner_timer = 999.0
	if is_equal_approx(hp[0], hp[1]):
		winner = -1
		banner_text = "TIME  â€”  DRAW (%.0f  Â·  %.0f HP)" % [hp[0], hp[1]]
		return
	winner = 0 if hp[0] > hp[1] else 1
	banner_text = "TIME  â€”  PLAYER %d WINS ON TOWERS (%.0f  Â·  %.0f HP)" % [winner + 1, hp[0], hp[1]]


func _process(delta: float) -> void:
	clock += delta
	if banner_timer > 0.0:
		banner_timer = maxf(0.0, banner_timer - delta)
	if float(reject["timer"]) > 0.0:
		reject["timer"] = maxf(0.0, float(reject["timer"]) - delta)
	if shake_amount > 0.0:
		shake_amount = maxf(0.0, shake_amount - delta * 40.0)
		shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
	else:
		shake_offset = Vector2.ZERO
	queue_redraw()


func _physics_process(delta: float) -> void:
	if match_over:
		return
	_tick_clock(delta)
	if match_over:
		return
	for p in 2:
		gold[p] = minf(gold_max, gold[p] + gold_rate_now() * delta)
		ability_cd[p] = maxf(0.0, float(ability_cd[p]) - delta)
	_tick_control(delta)
	separate_units()
	_tick_draw(delta)
	_tick_staged()
	_tick_reservations(delta)


# ------------------------------------------------------------------ geometry

## The board's own geometry is in DDBoard (pure static functions). These thin
## wrappers keep this file's API stable â€” units, bots and panels all call here.
func row_is_band(row: int) -> bool:
	return DDBoard.row_is_band(row)


func col_min(row: int) -> int:
	return DDBoard.col_min(row)


func col_max(row: int) -> int:
	return DDBoard.col_max(row)


func tile_of(world: Vector2) -> Vector2i:
	return DDBoard.tile_of(world)


## tx/ty are tile coordinates where the centre of tile (col,row) is (col+0.5, row+0.5).
func tile_center(tx: float, ty: float) -> Vector2:
	return DDBoard.tile_center(tx, ty)


func tile_rect(col: int, row: int) -> Rect2:
	return DDBoard.tile_rect(col, row)


## Screen rect covering cols c0..c1 of a single row (orientation agnostic).
func row_span(c0: int, c1: int, row: int) -> Rect2:
	return DDBoard.row_span(c0, c1, row)


## Building covering this tile. Footprints are explicit tile lists, so a 2x2 can
## sit centred on the corner between four tiles.
func building_at(t: Vector2i) -> Node:
	for u in units:
		if not is_instance_valid(u) or u.dead:
			continue
		if u.get("stationary") != true:
			continue
		var occ = u.get("occupied_tiles")
		if occ != null and (occ as Array).size() > 0:
			if (occ as Array).has(t):
				return u
			continue
		if tile_of(u.position) == t:
			return u
	return null


## Tiles a building of this footprint covers, anchored at the clicked tile, plus
## the screen position its art should sit at (corner-centred for 2x2).
func footprint_layout(t: Vector2i, fp: Array) -> Dictionary:
	return DDBoard.footprint_layout(t, fp)


## Nearest free tile centre, diagonals included.
func free_spot_near(at: Vector2) -> Vector2:
	if building_at(tile_of(at)) == null:
		return at
	var t := tile_of(at)
	var best := at
	var best_d := INF
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var nt := Vector2i(t.x + dx, t.y + dy)
			if not valid_tile(nt) or building_at(nt) != null:
				continue
			var c := tile_center(float(nt.x) + 0.5, float(nt.y) + 0.5)
			var dd := c.distance_squared_to(at)
			if dd < best_d:
				best_d = dd
				best = c
	return best


func valid_tile(t: Vector2i) -> bool:
	return DDBoard.valid_tile(t)


func band_index(t: Vector2i) -> int:
	return DDBoard.band_index(t)


func rect_for_arena() -> Rect2:
	return DDBoard.board_rect()


func board_rect() -> Rect2:
	return DDBoard.board_rect()


# ------------------------------------------------------------------- control

const CONTROL_REACH := 3


## Control is presence based: a ground unit holds the tiles 3 across to each
## side and 3 back toward its own half. It never contests the enemy's â€” both
## teams can hold the same tile.
func _tick_control(_delta: float) -> void:
	# only rebuild when some unit has actually changed tile (cheap cache)
	var seen := {}
	var changed := false
	for u in units:
		if not is_instance_valid(u) or u.dead:
			continue
		if u.get("flying") == true:
			continue
		if u.get("gives_presence") == false:
			continue
		var t := tile_of(u.position)
		var id: int = u.get_instance_id()
		seen[id] = t
		if unit_tiles.get(id) != t:
			changed = true
	if seen.size() != unit_tiles.size():
		changed = true
	if not changed:
		return
	unit_tiles = seen
	_rebuild_control()


var control_rebuilds := 0


func _rebuild_control() -> void:
	control_rebuilds += 1
	for t in 2:
		var arr: Array = control[t]
		for i in arr.size():
			arr[i] = false
	for u in units:
		if not is_instance_valid(u) or u.dead:
			continue
		if u.get("flying") == true:
			continue
		if u.get("gives_presence") == false:
			continue
		var ut := int(u.team)
		var back := 1 if ut == 0 else -1
		var base := tile_of(u.position)
		var shift := 0
		if u.get("presence_shift") != null:
			shift = int(u.get("presence_shift"))
		# cone: 3 tiles wide at the unit, then 5, 7, 9 going back toward its own half
		for k in range(0, CONTROL_REACH + 1):
			var half := 1 + k
			var ty: int = base.y + (k - shift) * back
			if ty < 0 or ty >= GRID_H:
				continue
			for dx in range(-half, half + 1):
				var tx: int = base.x + dx
				if tx < 0 or tx >= GRID_W:
					continue
				if not valid_tile(Vector2i(tx, ty)):
					continue
				control[ut][ty * GRID_W + tx] = true
	if control_layer != null:
		control_layer.queue_redraw()


## Units push past each other instead of stacking: overlap is split by mass
## (radius) and buildings never give ground.
func separate_units() -> void:
	var n := units.size()
	for i in n:
		var a = units[i]
		if not is_instance_valid(a) or a.dead:
			continue
		if a.get("stationary") == true:
			continue
		var ra: float = float(a.get_radius_t())
		for j in range(i + 1, n):
			var b = units[j]
			if not is_instance_valid(b) or b.dead:
				continue
			if bool(a.get("flying")) != bool(b.get("flying")):
				continue
			var rb: float = float(b.get_radius_t())
			var need: float = (ra + rb) * 0.85 * TILE
			var d: Vector2 = b.position - a.position
			var dist := d.length()
			if dist >= need or dist < 0.001:
				continue
			var overlap := (need - dist) * 0.5
			var dir := d / dist
			if b.get("stationary") == true:
				a.position -= dir * overlap * 2.0
			else:
				# heavier body wins the contest
				var wa := rb / (ra + rb)
				var wb := ra / (ra + rb)
				a.position -= dir * overlap * 2.0 * wa
				b.position += dir * overlap * 2.0 * wb


func controlled(team: int, t: Vector2i) -> bool:
	if not valid_tile(t):
		return false
	return bool(control[team][band_index(t)])


func control_counts() -> Array:
	var out := [0, 0, 0]
	for row in range(BAND_TOP, BAND_BOTTOM + 1):
		for col in range(col_min(row), col_max(row) + 1):
			var t := Vector2i(col, row)
			var a := controlled(0, t)
			var b := controlled(1, t)
			if a and b:
				out[2] += 1
			elif a:
				out[0] += 1
			elif b:
				out[1] += 1
	return out


# ---------------------------------------------------------------- targeting api

func tiles_between(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b) / TILE


func gap_between(a: Vector2, b: Vector2, ra: float, rb: float) -> float:
	return a.distance_to(b) / TILE - ra - rb


func enemy_entities(team: int) -> Array:
	var out: Array = []
	for u in units:
		if is_instance_valid(u) and not u.dead and int(u.team) != team:
			if u.get("untargetable") == true:
				continue
			out.append(u)
	for t in towers:
		if is_instance_valid(t) and not t.dead and int(t.team) != team:
			out.append(t)
	return out


func enemy_units(team: int) -> Array:
	var out: Array = []
	for u in units:
		if is_instance_valid(u) and not u.dead and int(u.team) != team:
			if u.get("untargetable") == true:
				continue
			out.append(u)
	return out


func nearest_enemy_tower(team: int, pos: Vector2) -> Node:
	var best: Node = null
	var best_d := INF
	for t in towers:
		if not is_instance_valid(t) or t.dead or int(t.team) == team:
			continue
		var d := pos.distance_squared_to(t.position)
		if d < best_d:
			best_d = d
			best = t
	return best


func crown_tower(team: int) -> Node:
	for t in towers:
		if is_instance_valid(t) and not t.dead and int(t.team) == team and bool(t.get("crown")):
			return t
	return null


func nearest_own_tower(team: int, pos: Vector2) -> Node:
	var best: Node = null
	var best_d := INF
	for t in towers:
		if not is_instance_valid(t) or t.dead or int(t.team) != team:
			continue
		var d := pos.distance_squared_to(t.position)
		if d < best_d:
			best_d = d
			best = t
	return best


const GIANT_KINDS := ["dragon"]


func apply_burn_at(center: Vector2, radius_t: float, burn: float, team: int, ticks: int = 4) -> void:
	if burn <= 0.0:
		return
	for e in enemy_entities(team):
		if not is_instance_valid(e) or e.dead or not e.has_method("apply_burn"):
			continue
		var d: float = tiles_between(center, e.position)
		if radius_t <= 0.0:
			if d <= float(e.get_radius_t()) + 0.25:
				e.apply_burn(burn, ticks)
		elif d <= radius_t + float(e.get_radius_t()) * 0.5:
			e.apply_burn(burn, ticks)


func spell_blast(center: Vector2, radius_t: float, dmg: float, team: int, tower_mult: float,
		burn: float, knock_tiles: float, kind: String, burn_ticks: int = 4) -> void:
	for e in enemy_entities(team).duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = tiles_between(center, e.position)
		if d > radius_t + float(e.get_radius_t()) * 0.5:
			continue
		var amount := dmg
		if e.is_tower() and tower_mult != 1.0:
			amount = dmg * tower_mult
		if amount > 0.0:
			e.take_damage(amount, center)
		if burn > 0.0 and e.has_method("apply_burn"):
			e.apply_burn(burn, burn_ticks)
		if knock_tiles > 0.0 and not e.is_tower():
			var kind_s := String(e.get("kind"))
			if e.get("stationary") == true or GIANT_KINDS.has(kind_s):
				continue
			var dir: Vector2 = e.position - center
			if dir.length() > 0.01 and e.has_method("apply_impulse"):
				e.apply_impulse(dir.normalized(), knock_tiles, 0.28)
	var col := Color(1.0, 0.55, 0.15) if kind == "fireball" else Color(1.0, 0.8, 0.3)
	var b := DDBurst.new()
	b.setup(self, maxf(radius_t, 0.6), col)
	b.position = center
	add_child(b)
	shake(7.0 if kind == "fireball" else 3.0)


func register_unit(u: Node) -> void:
	if not units.has(u):
		units.append(u)


func unregister(u: Node) -> void:
	units.erase(u)


# -------------------------------------------------------------- reservations
# Damage promised to a unit by an attack already in flight. Target selection
# skips units whose remaining HP is already covered, so two shooters do not
# both waste a shot on the same doomed troop.

func reserve_damage(attacker_id: int, target: Node, amount: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	release_reservation(attacker_id)
	if target.get("incoming") == null:
		return
	target.incoming = float(target.incoming) + amount
	reservations[attacker_id] = {"target": target, "amount": amount, "ttl": 0.9}


func release_reservation(attacker_id: int) -> void:
	var r = reservations.get(attacker_id)
	if r == null:
		return
	reservations.erase(attacker_id)
	var t = r["target"]
	if is_instance_valid(t) and t.get("incoming") != null:
		t.incoming = maxf(0.0, float(t.incoming) - float(r["amount"]))


func _tick_reservations(delta: float) -> void:
	for k in reservations.keys():
		var r = reservations[k]
		r["ttl"] = float(r["ttl"]) - delta
		if float(r["ttl"]) <= 0.0:
			release_reservation(k)


func is_doomed(t: Node) -> bool:
	if t == null or not is_instance_valid(t):
		return true
	if t.get("incoming") == null:
		return false
	return float(t.incoming) >= float(t.get("hp"))


# ------------------------------------------------------------------- movement

func route_point(from: Vector2, goal: Vector2) -> Vector2:
	var f := tile_of(from)
	var g := tile_of(goal)
	var toward_enemy := g.y < RIVER_TOP and f.y >= RIVER_TOP
	var toward_home := g.y > RIVER_BOTTOM and f.y <= RIVER_BOTTOM
	if not toward_enemy and not toward_home:
		return goal
	var bc := nearest_bridge_col(f.x)
	var lane: Vector2 = tile_center(bc + 0.5, float(RIVER_TOP) + 0.5).lerp(tile_center(bc + 0.5, float(RIVER_BOTTOM) + 0.5), 0.5)
	var far_bank: Vector2 = tile_center(bc + 0.5, float(RIVER_TOP) - 1.2) if toward_enemy else tile_center(bc + 0.5, float(RIVER_BOTTOM) + 1.2)
	# line up with the bridge lane first (the axis the bridge runs along),
	# then step across; never aim at the lane from the wrong side or units
	# oscillate on the bank forever
	var off := absf(from.y - lane.y) if LANDSCAPE else absf(from.x - lane.x)
	if off > TILE * 0.7:
		# aim at the bridge mouth on our own bank so the walk in is diagonal
		var bank: Vector2 = tile_center(bc + 0.5, float(RIVER_BOTTOM) + 1.0) if toward_enemy else tile_center(bc + 0.5, float(RIVER_TOP) - 1.0)
		return bank
	return far_bank


func nearest_bridge_col(col: int) -> float:
	var a := BRIDGE_COL_A
	var b := BRIDGE_COL_B
	return a if absf(a - float(col)) <= absf(b - float(col)) else b


# --------------------------------------------------------------------- spawns

func spawn_projectile(from: Vector2, to: Vector2, team: int, dmg: float, splash: float, kind: String,
		owner_id: int = 0, mode: String = "bolt", pierce: bool = false, owner_node: Node = null,
		speed_px: float = 0.0, target_node: Node = null, payload: Dictionary = {}) -> void:
	var p := DDProjectile.new()
	p.setup(self, from, to, team, dmg, splash, kind, owner_id, mode, pierce, owner_node, speed_px, target_node, payload)
	add_child(p)


func spawn_trail(at: Vector2, facing: float, team: int) -> void:
	var t := DDTrail.new()
	t.setup(self, facing, team)
	t.position = at
	add_child(t)


## A dying unit's confetti: the card's accent plus the owner's team colour,
## thrown further the bigger the body was.
func spawn_unit_confetti(at: Vector2, kind: String, team: int, radius_t: float) -> void:
	var accent: Color = DDCard.get_card(kind).get("accent", Color(0.8, 0.8, 0.8))
	var c := DDConfetti.new()
	c.setup([accent, team_color(team)], radius_t)
	c.position = at
	add_child(c)


func spawn_splash_burst(center: Vector2, radius_t: float, dmg: float, team: int, color: Color, tower_mult: float = 1.0) -> void:
	damage_at_point(center, radius_t, dmg, team, tower_mult)
	var b := DDBurst.new()
	b.setup(self, radius_t, color)
	b.position = center
	add_child(b)


func damage_at_point(center: Vector2, radius_t: float, dmg: float, team: int, tower_mult: float = 1.0) -> void:
	for e in enemy_entities(team):
		if not is_instance_valid(e):
			continue
		var amount := dmg
		if tower_mult != 1.0 and e.is_tower():
			amount = dmg * tower_mult
		var d: float = tiles_between(center, e.position)
		if radius_t <= 0.0:
			if d <= float(e.get_radius_t()) + 0.25:
				e.take_damage(amount, center)
		elif d <= radius_t + float(e.get_radius_t()) * 0.5:
			e.take_damage(amount, center)


func show_damage() -> bool:
	return view_mode == 1


func spawn_damage_text(at: Vector2, amount: float, tint: Color) -> void:
	if not show_damage():
		return
	var d = DDDamageText.new()
	d.setup(self, at, amount, tint)
	add_child(d)


func death_aoe(center: Vector2, radius_t: float, dmg: float, slow_amount: float, slow_time: float, owner_team: int) -> void:
	# troops only â€” the blast does not chip towers
	for e in enemy_units(owner_team).duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		if tiles_between(center, e.position) > radius_t + float(e.get_radius_t()) * 0.5:
			continue
		e.take_damage(dmg, center)
		if e.has_method("slow"):
			e.slow(slow_amount, slow_time)
	var b := DDBurst.new()
	b.setup(self, radius_t, Color(0.35, 0.55, 1.0))
	b.position = center
	add_child(b)
	shake(4.0)


const BOULDER_DIRECTIONS := 16


const BOULDER_RUNUP := 2.5


func spawn_boulder(from: Vector2, dir: Vector2, team: int) -> void:
	var b := DDBoulder.new()
	var snap := snap_direction(dir)
	# it breaks loose 2.5 tiles behind the idol so it rolls through the spot
	b.setup(self, snap, team, 1.0, from)
	b.position = from - snap * BOULDER_RUNUP * TILE
	add_child(b)


func snap_direction(dir: Vector2) -> Vector2:
	if dir.length() < 0.001:
		return Vector2(0, -1)
	var step := TAU / float(BOULDER_DIRECTIONS)
	var snapped := roundf(dir.angle() / step) * step
	return Vector2(cos(snapped), sin(snapped))


func shake(amount: float) -> void:
	shake_amount = maxf(shake_amount, amount)


func banner_flash(text: String) -> void:
	banner_text = text
	banner_timer = 2.0


# ------------------------------------------------------------------ card play

# --------------------------------------------------------------- hero abilities

func ability_name(player: int) -> String:
	return "TENTACLE" if String(ability[player]) == "tentacle" else "SHIESTY"


func ability_status(player: int) -> String:
	if match_over:
		return "â€”"
	if float(ability_cd[player]) > 0.0:
		return "%ds" % int(ceil(float(ability_cd[player])))
	if float(gold[player]) < float(ABILITY_COST):
		return "%dg" % ABILITY_COST
	if String(ability[player]) == "tentacle" and _highest_hp_enemy_unit(player) == null:
		return "no target"
	if String(ability[player]) == "shiesty" and _highest_hp_enemy_tower(player) == null:
		return "no tower"
	return "READY"


func ability_valid(player: int) -> bool:
	if match_over:
		return false
	if float(ability_cd[player]) > 0.0:
		return false
	if float(gold[player]) < float(ABILITY_COST):
		return false
	if String(ability[player]) == "tentacle":
		return _highest_hp_enemy_unit(player) != null
	return _highest_hp_enemy_tower(player) != null


## Circular ability button that floats over the player's king tower.
func ability_button_rect(player: int) -> Rect2:
	var k: Node = _king_of(player)
	var at: Vector2 = k.position if is_instance_valid(k) else tile_center(9.5, 27.5)
	var sz := 46.0
	return Rect2(at + Vector2(-sz * 0.5, -float(TILE) * 1.75), Vector2(sz, sz))


func _draw_ability_button(player: int) -> void:
	var r := ability_button_rect(player)
	var ready := ability_ready(player)
	var total: float = maxf(ability_cooldown_time(), float(ability_cd[player]))
	var f: float = clampf(1.0 - float(ability_cd[player]) / total, 0.0, 1.0)
	draw_circle(r.get_center(), 23.0, Color(0.1, 0.1, 0.14, 0.95))
	draw_arc(r.get_center(), 23.0, 0.0, TAU, 28, Color(0.35, 0.75, 0.45) if ready else Color(0.45, 0.45, 0.55), 2.5, true)
	if not ready:
		draw_arc(r.get_center(), 23.0, -PI * 0.5, -PI * 0.5 + TAU * f, 28, Color(0.55, 0.85, 1.0), 3.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 30.0, r.end.y + 14.0), ability_name(player),
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 60.0, 11,
		Color(0.85, 0.95, 0.85) if ready else Color(0.7, 0.7, 0.8))


func ability_ready(player: int) -> bool:
	if player < 0 or player > 1:
		return false
	return float(ability_cd[player]) <= 0.0


func use_ability(player: int) -> bool:
	if not ability_valid(player):
		return false
	if String(ability[player]) == "tentacle":
		var victim: Node = _highest_hp_enemy_unit(player)
		if victim == null:
			return false
		gold[player] = float(gold[player]) - float(ABILITY_COST)
		ability_cd[player] = ability_cooldown_time()
		var t := DDTentacle.new()
		t.hp = TENTACLE_HP
		t.max_hp = TENTACLE_HP
		t.life = TENTACLE_TIME
		t.setup(self, player, victim)
		t.position = victim.position
		units.append(t)
		add_child(t)
		victim.take_damage(TENTACLE_DMG, t.position)
		if victim.get("stunned") != null:
			victim.stunned = TENTACLE_TIME
		banner_flash("Tentacle grabs %s!" % DDCard.pretty(String(victim.kind)))
		return true
	var tower: Node = _highest_hp_enemy_tower(player)
	if tower == null:
		return false
	gold[player] = float(gold[player]) - float(ABILITY_COST)
	ability_cd[player] = ability_cooldown_time()
	var king := _king_of(player)
	var g := DDShiesty.new()
	g.dmg = GOBLIN_DMG
	g.setup(self, player, tower, king)
	units.append(g)
	add_child(g)
	banner_flash("Shiesty is on the job!")
	return true


func _highest_hp_enemy_unit(player: int) -> Node:
	var best: Node = null
	var best_hp := -1.0
	for u in units:
		if not is_instance_valid(u) or u.dead:
			continue
		if int(u.team) == player:
			continue
		if u.get("hp") == null:
			continue
		var uhp := float(u.get("hp"))
		if uhp > best_hp:
			best_hp = uhp
			best = u
	return best


func _highest_hp_enemy_tower(player: int) -> Node:
	var best: Node = null
	var best_hp := -1.0
	for t in towers:
		if not is_instance_valid(t) or t.dead or int(t.team) == player:
			continue
		var thp := float(t.hp)
		if thp > best_hp + 0.001:
			best = t
			best_hp = thp
		elif absf(thp - best_hp) <= 0.001 and best != null and t.position.x < best.position.x:
			best = t
			best_hp = thp
	return best


func clear_selection() -> void:
	selected_player = -1
	selected_index = -1
	debug_kind = ""
	_sync_shelf_selection()


func selection_kind() -> String:
	if debug_kind != "":
		return debug_kind
	if selected_player >= 0 and selected_index >= 0:
		var h: Array = hands[selected_player]
		if selected_index < h.size():
			return String(h[selected_index])
	return ""


func selection_owner() -> int:
	return 0 if debug_kind != "" else selected_player


func pick_debug_card(kind: String) -> void:
	if kind == "":
		return
	if debug_kind == kind:
		clear_selection()
		return
	debug_kind = kind
	selected_player = 0
	selected_index = -1
	_sync_shelf_selection()


func toggle_debug_shelf() -> void:
	debug_shelf = not debug_shelf
	debug_kind = ""
	if shelf_grid != null:
		shelf_grid.visible = debug_shelf
		shelf_grid.selected_kind = ""
	banner_flash("DEBUG: all-cards shelf %s" % ("ON" if debug_shelf else "OFF"))


func deploy_debug(world: Vector2) -> void:
	if debug_kind == "" or match_over:
		return
	var t := tile_of(world)
	var team := 0
	if t.y <= BAND_TOP - 1:
		team = 1
	elif row_is_band(t.y):
		var c0 := controlled(0, t)
		var c1 := controlled(1, t)
		if c0 and c1:
			team = randi() % 2
		elif c1:
			team = 1
		elif c0:
			team = 0
		else:
			team = 0 if t.y >= BAND_BOTTOM - 1 else 1
	else:
		team = 0
	if not can_deploy(team, debug_kind, world):
		banner_flash("No room for %s there for player %d" % [DDCard.pretty(debug_kind), team + 1])
		return
	spawn_troop(debug_kind, team, world)
	banner_flash("DEBUG: %s for player %d" % [DDCard.pretty(debug_kind), team + 1])


func _debug_gold(player: int, message: String) -> void:
	gold[player] = minf(gold_max, float(gold[player]) + 1.0)
	if message != "":
		banner_flash(message)


func pick_card(player: int, index: int) -> void:
	if match_over:
		return
	if view_mode == 0 and player == 1:
		return
	if index < 0:
		clear_selection()
		return
	if selected_player == player and selected_index == index:
		selected_player = -1
		selected_index = -1
		return
	var hand: Array = hands[player]
	if index < 0 or index >= hand.size():
		return
	# a card you cannot pay for can still be picked up and aimed â€” the gold is
	# only checked when the placement actually lands
	selected_player = player
	selected_index = index


func can_deploy(team: int, kind: String, world: Vector2) -> bool:
	var t := tile_of(world)
	if not valid_tile(t):
		return false
	if DDCard.is_spell(kind):
		return true
	# a 1x1 building blocks its tile outright; a 2x2 lets you in and shoves you off
	var b := building_at(t)
	if b != null:
		var fp: Array = b.get("footprint") if b.get("footprint") != null else [1, 1]
		if int(fp[0]) * int(fp[1]) == 1:
			return false
	for tw in towers:
		if is_instance_valid(tw) and not tw.dead and int(tw.team) != team:
			if tiles_between(world, tw.position) < TOWER_BUFFER:
				return false
	if team == 0:
		if t.y >= BAND_BOTTOM + 1:
			return true
		if t.y >= BAND_BOTTOM - 1:
			return true
	else:
		if t.y <= BAND_TOP - 1:
			return true
		if t.y <= BAND_TOP + 1:
			return true
	if row_is_band(t.y):
		return controlled(team, t)
	return false


func deploy(team: int, index: int, world: Vector2) -> void:
	var hand: Array = hands[team]
	if index < 0 or index >= hand.size():
		return
	var kind: String = hand[index]
	if gold[team] < DDCard.cost(kind):
		return
	if not can_deploy(team, kind, world):
		banner_flash("Claim the middle to deploy there")
		return
	gold[team] -= DDCard.cost(kind)
	spawn_troop(kind, team, world)
	# a card with uses left (Firebolt) stays in the hand AND stays lifted, so the
	# next click casts it again; right click puts it back with the charge intact
	var total_uses := int(DDCard.get_card(kind).get("uses", 1))
	if total_uses > 1:
		var left := charges_of(team, kind) - 1
		if left > 0:
			charges[team][kind] = left
			return
		charges[team].erase(kind)
	hand.remove_at(index)
	if kind == "penny":
		# the one card that changes: Pen takes her slot straight away and flies
		# into the hand from the spot she was played on
		hand.insert(index, "pen")
		for pn in panels:
			if is_instance_valid(pn) and int(pn.player) == team:
				pn.note_arrival("pen", world)
	else:
		# no automatic draw: the card cycles to the back of the deck
		queues[team].append(kind)
	# only clear the selection that belongs to the player who played
	if selected_player == team:
		clear_selection()


func spawn_troop(kind: String, team: int, world: Vector2, single: bool = false) -> Node:
	if DDCard.is_spell(kind):
		if kind == "snowball":
			# a rolling lane cleaner, not a bolt from a tower
			var sb := DDSnowball.new()
			sb.setup(self, team, world)
			add_child(sb)
			return sb
		var s := DDSpell.new()
		s.setup(self, kind, team)
		s.position = world
		add_child(s)
		return s
	var data: Dictionary = DDCard.get_card(kind)
	var world_tile := tile_of(world)
	var snapped := tile_center(float(world_tile.x) + 0.5, float(world_tile.y) + 0.5)
	var fp: Array = data.get("footprint", [1, 1])
	var occupied: Array = []
	if int(fp[0]) > 1 or int(fp[1]) > 1:
		# 2x2 buildings sit centred on the corner between four tiles and claim all four
		var layout := footprint_layout(world_tile, fp)
		snapped = layout["center"]
		occupied = layout["tiles"]
	else:
		# a building under our feet shoves the body off to the nearest free tile
		snapped = free_spot_near(snapped)
	var offsets: Array = data.get("swarm_offsets", [])
	if offsets.is_empty() or single:
		var u := DDUnit.new()
		u.setup(kind, team, self)
		u.position = snapped
		u.occupied_tiles = occupied
		units.append(u)
		add_child(u)
		return u
	# swarm: spawn every bird of the formation, lead bird at the front
	var first: Node = null
	# mirror the formation on both axes: the lead bird stays at the FRONT of
	# the push, whichever side of the board the flock is deployed on
	var ydir := -1.0 if team == 0 else 1.0
	var xdir := 1.0 if team == 0 else -1.0
	for i in offsets.size():
		var off: Array = offsets[i]
		var b := DDUnit.new()
		b.setup(kind, team, self)
		if i == 0 and data.has("lead_hp"):
			var lead_hp := float(data["lead_hp"])
			b.max_hp = lead_hp
			b.hp = lead_hp
			b.bird_lead = true
			b.radius_t = float(data["radius"]) * 1.3
		b.position = snapped + Vector2(float(off[0]) * xdir, float(off[1]) * ydir) * TILE
		units.append(b)
		add_child(b)
		if first == null:
			first = b
	return first


# ------------------------------------------------------------- dragon / hero

func airborne_dragon_of(team_who_owns_it: int) -> Node:
	for u in units:
		if not is_instance_valid(u) or u.dead:
			continue
		if u.get("flying") != true:
			continue
		if int(u.team) == team_who_owns_it and String(u.kind) == "dragon":
			return u
	return null


func _king_of(owner: int) -> Node:
	for t in towers:
		if is_instance_valid(t) and not t.dead and int(t.team) == owner and bool(t.get("crown")):
			return t
	return null


func hero_prompt_active(player: int) -> bool:
	if match_over:
		return false
	if view_mode == 0 and player == 1:
		return false
	if gold[player] < 3.0:
		return false
	return airborne_dragon_of(1 - player) != null


func hero_prompt_rect(player: int) -> Rect2:
	var king: Node = _king_of(player)
	var base := tile_center(9.0, 27.0 if player == 0 else 3.0)
	if king != null:
		base = king.position
	var y: float = base.y - 128.0 if player == 0 else base.y + 92.0
	var board := board_rect()
	var x: float = clampf(base.x - 118.0, board.position.x + 8.0, board.end.x - 244.0)
	return Rect2(x, clampf(y, board.position.y + 6.0, board.end.y - 50.0), 236.0, 44.0)


func launch_hero(player: int) -> void:
	var dragon: Node = airborne_dragon_of(1 - player)
	if dragon == null or gold[player] < 3.0:
		return
	gold[player] -= 3.0
	var king: Node = _king_of(player)
	var src: Vector2 = king.position if king != null else dragon.position + Vector2(0.0, 240.0)
	var leapt := DDLeap.new()
	leapt.setup(self, src, dragon, player)
	add_child(leapt)
	banner_flash("A hero rides out against the dragon!")


func on_tower_destroyed(tower: Node) -> void:
	banner_flash("A tower falls!")
	var owner_team := int(tower.team)
	var alive := 0
	for t in towers:
		if is_instance_valid(t) and int(t.team) == owner_team and not t.dead:
			alive += 1
	# the commander tower is the whole objective now: taking it ends the match
	if bool(tower.get("crown")):
		match_over = true
		winner = 1 - owner_team
		banner_text = "PLAYER %d WINS" % (winner + 1)
		banner_timer = 999.0


# ---------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		clear_selection()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		clear_selection()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		set_view_mode(1 - view_mode)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_A and view_mode == 1:
		toggle_debug_shelf()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		toggle_bot(1)
		return
	# solo view: 1-8 pick a card straight out of the hand, 9 fires the ability
	if event is InputEventKey and event.pressed and not event.echo and view_mode == 0:
		if event.keycode >= KEY_1 and event.keycode <= KEY_8:
			if not panels.is_empty():
				panels[0].select_index(int(event.keycode - KEY_1))
			return
		if event.keycode == KEY_9:
			use_ability(0)
			return
	# debug cheats â€” only while both hands are on screen (Tab)
	if event is InputEventKey and event.pressed and not event.echo and view_mode == 1:
		if event.keycode == KEY_1:
			_debug_gold(0, "+1 gold â†’ PLAYER 1")
			return
		if event.keycode == KEY_2:
			_debug_gold(0, "+1 gold â†’ BOTH")
			_debug_gold(1, "")
			return
		if event.keycode == KEY_3:
			_debug_gold(1, "+1 gold â†’ PLAYER 2")
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_R and match_over:
		get_tree().reload_current_scene()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var am := get_global_mouse_position()
		var king: Node = _king_of(0)
		if ability_button_rect(0).has_point(am) or (is_instance_valid(king) and king.position.distance_to(am) < float(TILE) * 1.15):
			use_ability(0)
			return
		if match_over:
			return
		var world: Vector2 = event.position
		for p in 2:
			if hero_prompt_active(p) and hero_prompt_rect(p).has_point(world):
				launch_hero(p)
				return
		if board_rect().has_point(world):
			try_deploy_at(world)
		else:
			clear_selection()


# --------------------------------------------------------------------- render

## Everything the arena paints lives in DDArenaDraw (scripts/arena_draw.gd): the
## board and terrain, the deploy hint, the hover box, the match HUD and the
## result overlay. This file stays about the rules.
func _draw() -> void:
	DDArenaDraw.draw_all(self, self)


func _hovered_entity(at: Vector2) -> Node:
<<<<<<< Updated upstream
	return DDArenaDraw.hovered(self, at)
=======
	return DDArenaDraw.hovered(self, at)
>>>>>>> Stashed changes
