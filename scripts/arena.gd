class_name Arena
extends Node2D

## Board shape: 30 rows tall. Rows 1..10 (top) and 19..28 (bottom) are 16 tiles
## wide; the middle band of 8 rows (11..18) bulges out to 18 tiles. The band is
## neutral no-man's land: you may only deploy inside it on tiles your ground
## troops have claimed within the last CLAIM_TIME seconds.

const TILE := 38.0
const GRID_W := 18
const GRID_H := 30
const OUTER_COL_MIN := 1
const OUTER_COL_MAX := 16
const BAND_TOP := 11
const BAND_BOTTOM := 18
const RIVER_TOP := 14
const RIVER_BOTTOM := 15
const BRIDGE_COL_A := 5.0
const BRIDGE_COL_B := 13.0
const CLAIM_TIME := 4.0
const TOWER_BUFFER := 3.5
const ABILITY_COST := 2
const ABILITY_COOLDOWN := 20.0
const TENTACLE_HP := 20.0
const TENTACLE_DMG := 20.0
const TENTACLE_TIME := 4.0
const GOBLIN_DMG := 30.0

## Orientation. LANDSCAPE = true  → your half on the LEFT, enemy on the RIGHT,
##                                   hand along the bottom of the screen.
##              LANDSCAPE = false → the original portrait board: your half at the
##                                   BOTTOM, enemy at the top, hands on the sides.
## Everything else (simulation, art, effects) is orientation-agnostic — flip this
## one flag and the board turns, provided the HUD is laid out to match.
const LANDSCAPE := true

const ORIGIN := Vector2(230.0, 56.0)

const GRASS_A := Color(0.45, 0.72, 0.38)
const GRASS_B := Color(0.38, 0.62, 0.32)
const BAND_A := Color(0.36, 0.5, 0.26)
const BAND_B := Color(0.33, 0.46, 0.24)
const WATER := Color(0.22, 0.45, 0.72)
const WATER_HI := Color(0.35, 0.62, 0.86)
const WOOD := Color(0.62, 0.45, 0.3)
const BLUE := Color(0.36, 0.62, 0.95)
const RED := Color(0.92, 0.4, 0.42)

var towers: Array = []
var units: Array = []
var gold := [5.0, 5.0]
var gold_max := 10.0
var gold_rate := 1.0 / 2.4
var hands := [[], []]
var queues := [[], []]
var selected_player := -1
var selected_index := -1
var match_over := false
var winner := -1
var clock := 0.0
var banner_text := ""
var banner_timer := 0.0
var shake_amount := 0.0
var shake_offset := Vector2.ZERO
var panels: Array = []
var view_mode := 0
var bots: Array = [null, null]
var bot_players := [false, true]
var debug_shelf := false
var debug_kind := ""
var ability := ["tentacle", "shiesty"]
var ability_cd := [0.0, 0.0]
var damage_guard := 0
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


func _dev_hook() -> void:
	for a in OS.get_cmdline_user_args():
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


func _build_decks() -> void:
	for p in 2:
		var deck: Array = DDCard.ORDER.duplicate()
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260214 + p
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
		panel.player = p
		panel.arena = self
		if p == 0:
			panel.compact = false
			panel.size = Vector2(1600.0, 196.0)
			panel.position = Vector2(0.0, 804.0)
		else:
			panel.compact = true
			panel.size = Vector2(1600.0, 66.0)
			panel.position = Vector2(0.0, 736.0)
		add_child(panel)
		panels.append(panel)
	panels[1].visible = false


## Called by the hand panel when a dragged card is dropped on the board.
func try_deploy_at(world: Vector2) -> void:
	if match_over or selection_kind() == "":
		return
	if not board_rect().has_point(world):
		return
	if debug_kind != "":
		deploy_debug(world)
	elif selected_player >= 0 and selected_index >= 0:
		deploy(selected_player, selected_index, world)


func set_view_mode(m: int) -> void:
	view_mode = m
	if panels.size() == 2:
		panels[1].visible = m == 1
	if m == 0 and selected_player == 1:
		selected_player = -1
		selected_index = -1
	queue_redraw()


func _process(delta: float) -> void:
	clock += delta
	if banner_timer > 0.0:
		banner_timer = maxf(0.0, banner_timer - delta)
	if shake_amount > 0.0:
		shake_amount = maxf(0.0, shake_amount - delta * 40.0)
		shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
	else:
		shake_offset = Vector2.ZERO
	queue_redraw()


func _physics_process(delta: float) -> void:
	if match_over:
		return
	for p in 2:
		gold[p] = minf(gold_max, gold[p] + gold_rate * delta)
		ability_cd[p] = maxf(0.0, float(ability_cd[p]) - delta)
	_tick_control(delta)
	_tick_reservations(delta)


# ------------------------------------------------------------------ geometry

func row_is_band(row: int) -> bool:
	return row >= BAND_TOP and row <= BAND_BOTTOM


func col_min(row: int) -> int:
	return 0 if row_is_band(row) else OUTER_COL_MIN


func col_max(row: int) -> int:
	return 17 if row_is_band(row) else OUTER_COL_MAX


func tile_of(world: Vector2) -> Vector2i:
	var gx := int(floorf((world.x - ORIGIN.x) / TILE))
	var gy := int(floorf((world.y - ORIGIN.y) / TILE))
	if LANDSCAPE:
		return Vector2i(gy, GRID_H - 1 - gx)
	return Vector2i(gx, gy)


## tx/ty are tile coordinates where the centre of tile (col,row) is (col+0.5, row+0.5).
func tile_center(tx: float, ty: float) -> Vector2:
	if LANDSCAPE:
		return ORIGIN + Vector2(float(GRID_H) - ty, tx) * TILE
	return ORIGIN + Vector2(tx, ty) * TILE


func tile_rect(col: int, row: int) -> Rect2:
	if LANDSCAPE:
		return Rect2(ORIGIN + Vector2(float(GRID_H - 1 - row), float(col)) * TILE, Vector2(TILE, TILE))
	return Rect2(ORIGIN + Vector2(float(col), float(row)) * TILE, Vector2(TILE, TILE))


## Screen rect covering cols c0..c1 of a single row (orientation agnostic).
func row_span(c0: int, c1: int, row: int) -> Rect2:
	return tile_rect(c0, row).merge(tile_rect(c1, row))


func valid_tile(t: Vector2i) -> bool:
	if t.y < 0 or t.y >= GRID_H:
		return false
	return t.x >= col_min(t.y) and t.x <= col_max(t.y)


func band_index(t: Vector2i) -> int:
	return t.y * GRID_W + t.x


func rect_for_arena() -> Rect2:
	return board_rect()


func board_rect() -> Rect2:
	if LANDSCAPE:
		return Rect2(ORIGIN, Vector2(GRID_H, GRID_W) * TILE)
	return Rect2(ORIGIN, Vector2(GRID_W, GRID_H) * TILE)


# ------------------------------------------------------------------- control

const CONTROL_REACH := 3


## Control is presence based: a ground unit holds the tiles 3 across to each
## side and 3 back toward its own half. It never contests the enemy's — both
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
			out.append(u)
	for t in towers:
		if is_instance_valid(t) and not t.dead and int(t.team) != team:
			out.append(t)
	return out


func enemy_units(team: int) -> Array:
	var out: Array = []
	for u in units:
		if is_instance_valid(u) and not u.dead and int(u.team) != team:
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


func apply_burn_at(center: Vector2, radius_t: float, burn: float, team: int) -> void:
	if burn <= 0.0:
		return
	for e in enemy_entities(team):
		if not is_instance_valid(e) or e.dead or not e.has_method("apply_burn"):
			continue
		var d: float = tiles_between(center, e.position)
		if radius_t <= 0.0:
			if d <= float(e.get_radius_t()) + 0.25:
				e.apply_burn(burn)
		elif d <= radius_t + float(e.get_radius_t()) * 0.5:
			e.apply_burn(burn)


func spell_blast(center: Vector2, radius_t: float, dmg: float, team: int, tower_mult: float,
		burn: float, knock_tiles: float, kind: String) -> void:
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
			e.apply_burn(burn)
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
	var own_bank: Vector2 = tile_center(bc + 0.5, float(RIVER_BOTTOM) + 1.5) if toward_enemy else tile_center(bc + 0.5, float(RIVER_TOP) - 0.5)
	var far_bank: Vector2 = tile_center(bc + 0.5, float(RIVER_TOP) - 1.5) if toward_enemy else tile_center(bc + 0.5, float(RIVER_BOTTOM) + 1.5)
	# the axis we approach along is the one the river runs across
	var cross := Vector2(1, 0) if LANDSCAPE else Vector2(0, 1)
	var along := absf((from - lane).dot(cross))
	if along > TILE * 1.6:
		return Vector2(lane.x, from.y) if LANDSCAPE else Vector2(from.x, lane.y)
	return far_bank if own_bank.distance_to(from) < far_bank.distance_to(from) else own_bank


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
	# troops only — the blast does not chip towers
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


func dragon_breath(center: Vector2, radius_t: float, dmg: float, owner_team: int) -> void:
	for u in units.duplicate():
		if not is_instance_valid(u) or u.dead:
			continue
		if u.get("flying") == true:
			continue
		if tiles_between(center, u.position) <= radius_t + float(u.get_radius_t()) * 0.5:
			u.take_damage(dmg, center)
	for t in towers.duplicate():
		if not is_instance_valid(t) or t.dead:
			continue
		if int(t.team) == owner_team:
			continue
		if tiles_between(center, t.position) <= radius_t + 0.7:
			t.take_damage(dmg, center)
	var fire := DDBurst.new()
	fire.setup(self, radius_t, Color(1.0, 0.45, 0.12))
	fire.position = center
	add_child(fire)
	shake(3.0)


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
		return "—"
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
		ability_cd[player] = ABILITY_COOLDOWN
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
	ability_cd[player] = ABILITY_COOLDOWN
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


func toggle_debug_shelf() -> void:
	debug_shelf = not debug_shelf
	debug_kind = ""
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
	if gold[player] < DDCard.cost(hand[index]):
		banner_flash("Not enough gold for %s" % DDCard.pretty(hand[index]))
		return
	selected_player = player
	selected_index = index


func can_deploy(team: int, kind: String, world: Vector2) -> bool:
	var t := tile_of(world)
	if not valid_tile(t):
		return false
	if DDCard.is_spell(kind):
		return true
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
	hand.remove_at(index)
	if queues[team].size() > 0:
		hand.append(queues[team].pop_front())
	queues[team].append(kind)
	# only clear the selection that belongs to the player who played
	if selected_player == team:
		clear_selection()


func spawn_troop(kind: String, team: int, world: Vector2, single: bool = false) -> Node:
	if DDCard.is_spell(kind):
		var s := DDSpell.new()
		s.setup(self, kind, team)
		s.position = world
		add_child(s)
		return s
	var data: Dictionary = DDCard.get_card(kind)
	var world_tile := tile_of(world)
	var snapped := tile_center(float(world_tile.x) + 0.5, float(world_tile.y) + 0.5)
	var offsets: Array = data.get("swarm_offsets", [])
	if offsets.is_empty() or single:
		var u := DDUnit.new()
		u.setup(kind, team, self)
		u.position = snapped
		units.append(u)
		add_child(u)
		return u
	# swarm: spawn every bird of the formation, lead bird at the front
	var first: Node = null
	var ydir := -1.0 if team == 0 else 1.0
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
		b.position = snapped + Vector2(float(off[0]), float(off[1]) * ydir) * TILE
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
	if alive == 0:
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
	# debug cheats — only while both hands are on screen (Tab)
	if event is InputEventKey and event.pressed and not event.echo and view_mode == 1:
		if event.keycode == KEY_1:
			_debug_gold(0, "+1 gold → PLAYER 1")
			return
		if event.keycode == KEY_2:
			_debug_gold(0, "+1 gold → BOTH")
			_debug_gold(1, "")
			return
		if event.keycode == KEY_3:
			_debug_gold(1, "+1 gold → PLAYER 2")
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_R and match_over:
		get_tree().reload_current_scene()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if match_over:
			return
		var world: Vector2 = event.position
		for p in 2:
			if hero_prompt_active(p) and hero_prompt_rect(p).has_point(world):
				launch_hero(p)
				return
		if debug_kind != "" and board_rect().has_point(world):
			deploy_debug(world)
		elif selected_player >= 0 and board_rect().has_point(world):
			deploy(selected_player, selected_index, world)
		elif not board_rect().has_point(world):
			clear_selection()


# --------------------------------------------------------------------- render

func _hovered_entity(at: Vector2) -> Node:
	var best: Node = null
	var best_d := INF
	for e in units:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = tiles_between(at, e.position)
		if d <= float(e.get_radius_t()) + 0.35 and d < best_d:
			best = e
			best_d = d
	for t in towers:
		if not is_instance_valid(t) or t.dead:
			continue
		var d2: float = tiles_between(at, t.position)
		if d2 <= 1.1 and d2 < best_d:
			best = t
			best_d = d2
	return best


func _draw_hover(m: Vector2) -> void:
	var e := _hovered_entity(m)
	if e == null:
		return
	var px: float = float(e.get_radius_t()) * TILE
	var reach_var = e.get("reach")
	var reach_v := 0.0
	if reach_var != null:
		reach_v = float(reach_var)
	var aggro_var = e.get("aggro")
	var aggro_v := 0.0
	if aggro_var != null:
		aggro_v = float(aggro_var)
	var label := "TOWER"
	var kind_var = e.get("kind")
	if kind_var != null:
		label = DDCard.pretty(String(kind_var))
	var hp_txt := "%d / %d HP" % [int(ceil(float(e.get("hp")))), int(float(e.get("max_hp")))]
	if aggro_v > 0.0:
		draw_circle(e.position, aggro_v * TILE, Color(1.0, 0.95, 0.5, 0.05))
		draw_arc(e.position, aggro_v * TILE, 0.0, TAU, 56, Color(1.0, 0.95, 0.45, 0.55), 2.0, true)
	if reach_v > 0.0:
		draw_circle(e.position, reach_v * TILE, Color(1.0, 0.42, 0.34, 0.06))
		draw_arc(e.position, reach_v * TILE, 0.0, TAU, 56, Color(1.0, 0.45, 0.4, 0.65), 2.0, true)
	draw_arc(e.position, px + 2.0, 0.0, TAU, 24, Color(1, 1, 1, 0.45), 1.5, true)
	var font := ThemeDB.fallback_font
	var w := 190.0
	var box := Rect2(e.position.x - w * 0.5, e.position.y - px - 48.0, w, 34.0)
	draw_rect(box, Color(0.09, 0.08, 0.13, 0.92), true)
	draw_rect(box, DDArt.OUTLINE, false, 1.5)
	draw_string(font, Vector2(box.position.x + 8.0, box.position.y + 15.0), label, HORIZONTAL_ALIGNMENT_LEFT, w - 16.0, 13, Color(1.0, 0.95, 0.8))
	draw_string(font, Vector2(box.position.x + 8.0, box.position.y + 29.0), hp_txt, HORIZONTAL_ALIGNMENT_LEFT, w - 16.0, 11, Color(0.8, 0.85, 0.95))


func _draw() -> void:
	draw_set_transform(shake_offset, 0.0, Vector2.ONE)
	# tiles
	for row in GRID_H:
		var c0 := col_min(row)
		var c1 := col_max(row)
		for col in range(c0, c1 + 1):
			var rect := tile_rect(col, row)
			var base := GRASS_A if (row + col) % 2 == 0 else GRASS_B
			if row_is_band(row):
				base = BAND_A if (row + col) % 2 == 0 else BAND_B
			draw_rect(rect, base)
	# halves tint (orientation agnostic: one row at a time)
	for row in GRID_H:
		var c0 := col_min(row)
		var span := row_span(c0, col_max(row), row)
		if row < BAND_TOP:
			draw_rect(span, Color(0.92, 0.35, 0.35, 0.07))
		elif row > BAND_BOTTOM:
			draw_rect(span, Color(0.35, 0.55, 1.0, 0.07))
	# river
	var river_span := tile_rect(col_min(RIVER_TOP), RIVER_TOP).merge(tile_rect(col_max(RIVER_BOTTOM), RIVER_BOTTOM))
	draw_rect(river_span, WATER)
	for i in 6:
		var phase := clock * 0.8 + float(i)
		if LANDSCAPE:
			var x := river_span.position.x + 10.0 + float(i) * 9.0
			var y := river_span.position.y + fmod(phase * 26.0, river_span.size.y)
			draw_line(Vector2(x, y), Vector2(x, y + 34.0), WATER_HI, 2.0, true)
		else:
			var y2 := river_span.position.y + 10.0 + float(i) * 9.0
			var x2 := river_span.position.x + fmod(phase * 26.0, river_span.size.x)
			draw_line(Vector2(x2, y2), Vector2(x2 + 34.0, y2), WATER_HI, 2.0, true)
	# bridges
	for bx in [int(BRIDGE_COL_A), int(BRIDGE_COL_B)]:
		var br := tile_rect(bx - 1, RIVER_TOP).merge(tile_rect(bx, RIVER_BOTTOM))
		draw_rect(br, WOOD)
		for k in 5:
			if LANDSCAPE:
				var x2 := br.position.x + 6.0 + float(k) * 16.0
				draw_line(Vector2(x2, br.position.y + 2.0), Vector2(x2, br.end.y - 2.0), Color(0.45, 0.31, 0.2), 1.5, true)
			else:
				var y2 := br.position.y + 6.0 + float(k) * 16.0
				draw_line(Vector2(br.position.x + 2.0, y2), Vector2(br.end.x - 2.0, y2), Color(0.45, 0.31, 0.2), 1.5, true)
		draw_rect(br, DDArt.OUTLINE, false, 2.5)
	# (control tint lives in DDControlLayer so it only repaints on change)
	# dashed no-man's-land edges
	for edge_row in [BAND_TOP, BAND_BOTTOM + 1]:
		var er := tile_rect(col_min(edge_row), edge_row)
		var across := board_rect().size.y if LANDSCAPE else board_rect().size.x
		var start := board_rect().position.y if LANDSCAPE else board_rect().position.x
		var at: float = er.position.x if LANDSCAPE else er.position.y
		var k2 := 0.0
		while k2 < across:
			if LANDSCAPE:
				draw_line(Vector2(at, start + k2), Vector2(at, start + k2 + 9.0), Color(1.0, 0.9, 0.55, 0.55), 2.0)
			else:
				draw_line(Vector2(start + k2, at), Vector2(start + k2 + 9.0, at), Color(1.0, 0.9, 0.55, 0.55), 2.0)
			k2 += 18.0
	# board silhouette: three slabs make the plus shape
	draw_rect(tile_rect(col_min(0), 0).merge(tile_rect(col_max(GRID_H - 1), BAND_TOP - 1)), DDArt.OUTLINE, false, 4.0)
	draw_rect(tile_rect(col_min(BAND_TOP), BAND_TOP).merge(tile_rect(col_max(BAND_BOTTOM), BAND_BOTTOM)), DDArt.OUTLINE, false, 4.0)
	draw_rect(tile_rect(col_min(GRID_H - 1), BAND_BOTTOM + 1).merge(tile_rect(col_max(GRID_H - 1), GRID_H - 1)), DDArt.OUTLINE, false, 4.0)
	# deploy hint
	var armed := selection_kind()
	if armed != "" and not match_over:
		var kind: String = armed
		var sel_player := selection_owner()
		if not DDCard.is_spell(kind):
			for row in GRID_H:
				for col in range(col_min(row), col_max(row) + 1):
					var t := Vector2i(col, row)
					if not can_deploy(sel_player, kind, tile_center(float(col) + 0.5, float(row) + 0.5)):
						continue
					draw_rect(tile_rect(col, row), Color(0.9, 0.95, 0.6, 0.13))
		var m := get_global_mouse_position()
		if board_rect().has_point(m):
			var tt := tile_of(m)
			var at := tile_center(float(tt.x) + 0.5, float(tt.y) + 0.5)
			var ok := can_deploy(sel_player, kind, m)
			var col2 := Color(0.5, 1.0, 0.6, 0.85) if ok else Color(1.0, 0.35, 0.35, 0.85)
			draw_rect(Rect2(at - Vector2(TILE, TILE) * 0.5, Vector2(TILE, TILE)), col2, false, 2.5)
			if DDCard.is_spell(kind):
				var rad: float = maxf(float(DDCard.get_card(kind)["splash"]), 0.5) * TILE
				draw_circle(at, rad, Color(1.0, 0.6, 0.2, 0.16 if ok else 0.1))
				draw_arc(at, rad, 0.0, TAU, 48, col2, 2.5, true)
			if preview != null:
				preview.show_for(kind, sel_player, at)
		elif preview != null:
			preview.hide_preview()
	else:
		if preview != null:
			preview.hide_preview()
	# bot intent, only rendered while both hands are on screen
	for p in 2:
		var tp := bot_target(p)
		if tp == Vector2.INF:
			continue
		var pulse := 0.5 + 0.5 * absf(sin(clock * 6.0))
		draw_arc(tp, TILE * 1.15, 0.0, TAU, 32, Color(0.55, 0.85, 1.0, 0.5 + 0.4 * pulse), 2.5, true)
		draw_arc(tp, TILE * 0.55, 0.0, TAU, 24, Color(1.0, 0.95, 0.75, 0.7), 2.0, true)
	# hover inspection (only when nothing is armed)
	if selection_kind() == "" and not match_over:
		_draw_hover(get_global_mouse_position())
	# control chip
	var counts := control_counts()
	var chip_w := 300.0
	var chip := Rect2(ORIGIN.x + board_rect().size.x * 0.5 - chip_w * 0.5, 10.0, chip_w, 30.0)
	draw_rect(chip, Color(0.09, 0.08, 0.13, 0.92), true)
	draw_rect(chip, DDArt.OUTLINE, false, 2.0)
	var label := "MID  —  YOU %d  ·  THEM %d" % [counts[0], counts[1]]
	if counts[2] > 0:
		label = "MID  CONTESTED  ·  %d / %d" % [counts[0], counts[1]]
	draw_string(ThemeDB.fallback_font, Vector2(chip.position.x + 12.0, chip.position.y + 21.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, chip_w - 24.0, 15, Color(1.0, 0.93, 0.78))
	if view_mode == 1:
		draw_string(ThemeDB.fallback_font, Vector2(ORIGIN.x, 30.0),
			"DEBUG  1 = +1 gold P1   2 = +1 both   3 = +1 P2   B = bot",
			HORIZONTAL_ALIGNMENT_LEFT, 620.0, 13, Color(0.75, 0.8, 0.95, 0.75))
	# opponent chip (top right, clear of the board)
	var strip := Rect2(1372.0, 8.0, 216.0, 40.0)
	draw_rect(strip, Color(0.1, 0.1, 0.14, 0.96), true)
	draw_rect(strip, DDArt.OUTLINE, false, 2.0)
	draw_rect(Rect2(strip.position, Vector2(strip.size.x, 4.0)), RED, true)
	draw_string(ThemeDB.fallback_font, Vector2(strip.position.x + 14.0, strip.position.y + 26.0), "OPPONENT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, RED.lightened(0.3))
	DDArt.coin(self, Vector2(strip.position.x + 128.0, strip.position.y + 21.0), 10.0)
	draw_string(ThemeDB.fallback_font, Vector2(strip.position.x + 143.0, strip.position.y + 27.0),
		"%d" % int(floor(gold[1])), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.98, 0.85, 0.45))
	# hero prompt
	for p in 2:
		if hero_prompt_active(p):
			var pr := hero_prompt_rect(p)
			var pulse := 0.55 + 0.45 * absf(sin(clock * 3.2))
			draw_rect(pr, Color(0.1, 0.08, 0.12, 0.94), true)
			draw_rect(pr, Color(1.0, 0.82, 0.32, pulse), false, 3.0)
			DDArt.coin(self, Vector2(pr.position.x + 24.0, pr.position.y + 22.0), 11.0)
			draw_string(ThemeDB.fallback_font, Vector2(pr.position.x + 44.0, pr.position.y + 28.0),
				"LAUNCH HERO · 3", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.93, 0.76))
	# banner
	if banner_timer > 0.0 and banner_text != "":
		var w := 620.0
		var box := Rect2(ORIGIN.x + board_rect().size.x * 0.5 - w * 0.5, ORIGIN.y - 34.0, w, 32.0)
		draw_rect(box, Color(0.09, 0.08, 0.13, 0.9), true)
		draw_rect(box, DDArt.OUTLINE, false, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(box.position.x + 14.0, box.position.y + 22.0), banner_text,
			HORIZONTAL_ALIGNMENT_CENTER, w - 28.0, 18, Color(1.0, 0.95, 0.85))
	if match_over:
		var board := board_rect()
		draw_rect(board, Color(0.05, 0.05, 0.08, 0.62), true)
		draw_string(ThemeDB.fallback_font, Vector2(board.position.x, board.position.y + 380.0), "PLAYER %d WINS" % (winner + 1),
			HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 44, Color(1.0, 0.95, 0.8))
		draw_string(ThemeDB.fallback_font, Vector2(board.position.x, board.position.y + 424.0), "press R to play again",
			HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 20, Color(0.85, 0.85, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
