class_name Arena
extends Node2D

## Board shape: 30 rows tall. Rows 1..10 (top) and 19..28 (bottom) are 16 tiles
## wide; the middle band of 8 rows (11..18) bulges out to 18 tiles. The band is
## neutral no-man's land: you may only deploy inside it on tiles your ground
## troops have claimed within the last CLAIM_TIME seconds.

const TILE := 27.0
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

const ORIGIN := Vector2(470.0, 46.0)

const GRASS_A := Color(0.42, 0.68, 0.36)
const GRASS_B := Color(0.38, 0.62, 0.33)
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
var ability := ["tentacle", "goblin"]
var ability_cd := [0.0, 0.0]
var damage_guard := 0
var stat_goblin_escaped := 0
var stat_goblin_caught := 0
var claim := [[], []]
var reservations := {}


func _ready() -> void:
	for t in 2:
		var arr: Array = []
		arr.resize(GRID_W * GRID_H)
		arr.fill(0.0)
		claim[t] = arr
	var forced := ""
	for a in OS.get_cmdline_user_args():
		if a == "--bots=both":
			bot_players = [true, true]
		elif a == "--bots=off":
			bot_players = [false, false]
		elif a.begins_with("--ability="):
			forced = a.substr(10)
	if forced == "tentacle":
		ability = ["tentacle", "goblin"]
	elif forced == "goblin":
		ability = ["goblin", "tentacle"]
	else:
		var arng := RandomNumberGenerator.new()
		arng.randomize()
		ability = ["tentacle", "goblin"] if arng.randf() < 0.5 else ["goblin", "tentacle"]
	_build_board_state()
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
		panel.size = Vector2(430.0, 808.0)
		panel.position = Vector2(10.0, 46.0) if p == 0 else Vector2(960.0, 46.0)
		add_child(panel)
		panels.append(panel)
	panels[1].visible = false


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
	return Vector2i(int(floor((world.x - ORIGIN.x) / TILE)), int(floor((world.y - ORIGIN.y) / TILE)))


func tile_center(tx: float, ty: float) -> Vector2:
	return ORIGIN + Vector2(tx, ty) * TILE


func valid_tile(t: Vector2i) -> bool:
	if t.y < 0 or t.y >= GRID_H:
		return false
	return t.x >= col_min(t.y) and t.x <= col_max(t.y)


func band_index(t: Vector2i) -> int:
	return t.y * GRID_W + t.x


func rect_for_arena() -> Rect2:
	return Rect2(ORIGIN, Vector2(GRID_W, GRID_H) * TILE)


func board_rect() -> Rect2:
	return Rect2(ORIGIN, Vector2(GRID_W, GRID_H) * TILE)


# ------------------------------------------------------------------- control

func _tick_control(delta: float) -> void:
	for t in 2:
		var arr: Array = claim[t]
		for i in arr.size():
			if float(arr[i]) > 0.0:
				arr[i] = maxf(0.0, float(arr[i]) - delta)
	for u in units:
		if not is_instance_valid(u) or u.dead:
			continue
		if u.get("flying") == true:
			continue
		var t2 := tile_of(u.position)
		if not row_is_band(t2.y) or t2.x < 0 or t2.x >= GRID_W:
			continue
		claim[int(u.team)][band_index(t2)] = CLAIM_TIME


func tile_claim(team: int, t: Vector2i) -> float:
	if not valid_tile(t):
		return 0.0
	return float(claim[team][band_index(t)])


func tile_contested(t: Vector2i) -> bool:
	return tile_claim(0, t) > 0.05 and tile_claim(1, t) > 0.05


func control_counts() -> Array:
	var out := [0, 0, 0]
	for row in range(BAND_TOP, BAND_BOTTOM + 1):
		for col in range(col_min(row), col_max(row) + 1):
			var t := Vector2i(col, row)
			if tile_contested(t):
				out[2] += 1
			elif tile_claim(0, t) > 0.05:
				out[0] += 1
			elif tile_claim(1, t) > 0.05:
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
	var water_top := ORIGIN.y + float(RIVER_TOP) * TILE
	var water_bottom := ORIGIN.y + float(RIVER_BOTTOM + 1) * TILE
	var fr := int((from.y - ORIGIN.y) / TILE)
	var gr := int((goal.y - ORIGIN.y) / TILE)
	var going_down := gr > RIVER_BOTTOM and fr <= RIVER_BOTTOM
	var going_up := gr < RIVER_TOP and fr >= RIVER_TOP
	if not going_down and not going_up:
		return goal
	var bx := nearest_bridge_x(from.x)
	var tol := TILE * 0.8
	if absf(from.x - bx) > tol:
		return Vector2(bx, water_top - TILE * 0.7) if going_down else Vector2(bx, water_bottom + TILE * 0.7)
	if going_down:
		return Vector2(bx, water_bottom + TILE * 0.8)
	return Vector2(bx, water_top - TILE * 0.8)


func nearest_bridge_x(x: float) -> float:
	var a: float = ORIGIN.x + BRIDGE_COL_A * TILE
	var b: float = ORIGIN.x + BRIDGE_COL_B * TILE
	return a if absf(a - x) <= absf(b - x) else b


# --------------------------------------------------------------------- spawns

func spawn_projectile(from: Vector2, to: Vector2, team: int, dmg: float, splash: float, kind: String,
		owner_id: int = 0, mode: String = "bolt", pierce: bool = false, owner_node: Node = null,
		speed_px: float = 0.0) -> void:
	var p := DDProjectile.new()
	p.setup(self, from, to, team, dmg, splash, kind, owner_id, mode, pierce, owner_node, speed_px)
	add_child(p)


func spawn_trail(at: Vector2, facing: float, team: int) -> void:
	var t := DDTrail.new()
	t.setup(self, facing, team)
	t.position = at
	add_child(t)


func spawn_splash_burst(center: Vector2, radius_t: float, dmg: float, team: int, color: Color) -> void:
	damage_at_point(center, radius_t, dmg, team)
	var b := DDBurst.new()
	b.setup(self, radius_t, color)
	b.position = center
	add_child(b)


func damage_at_point(center: Vector2, radius_t: float, dmg: float, team: int) -> void:
	for e in enemy_entities(team):
		if not is_instance_valid(e):
			continue
		var d: float = tiles_between(center, e.position)
		if radius_t <= 0.0:
			if d <= float(e.get_radius_t()) + 0.25:
				e.take_damage(dmg, center)
		elif d <= radius_t + float(e.get_radius_t()) * 0.5:
			e.take_damage(dmg, center)


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


func spawn_boulder(from: Vector2, dir: Vector2, team: int) -> void:
	var b := DDBoulder.new()
	b.setup(self, dir, team)
	b.position = from
	add_child(b)


func shake(amount: float) -> void:
	shake_amount = maxf(shake_amount, amount)


func banner_flash(text: String) -> void:
	banner_text = text
	banner_timer = 2.0


# ------------------------------------------------------------------ card play

# --------------------------------------------------------------- hero abilities

func ability_name(player: int) -> String:
	return "TENTACLE" if String(ability[player]) == "tentacle" else "GOBLIN RAID"


func ability_status(player: int) -> String:
	if match_over:
		return "—"
	if float(ability_cd[player]) > 0.0:
		return "%ds" % int(ceil(float(ability_cd[player])))
	if float(gold[player]) < float(ABILITY_COST):
		return "%dg" % ABILITY_COST
	if String(ability[player]) == "tentacle" and _highest_hp_enemy_unit(player) == null:
		return "no target"
	if String(ability[player]) == "goblin" and _highest_hp_enemy_tower(player) == null:
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
	var g := DDGoblin.new()
	g.dmg = GOBLIN_DMG
	g.setup(self, player, tower, king)
	units.append(g)
	add_child(g)
	banner_flash("A goblin is launched at the tower!")
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
		selected_player = -1
		selected_index = -1
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
	else:
		if t.y <= BAND_TOP - 1:
			return true
	if row_is_band(t.y):
		return tile_claim(team, t) > 0.4 and not tile_contested(t)
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
	selected_player = -1
	selected_index = -1


func spawn_troop(kind: String, team: int, world: Vector2, single: bool = false) -> Node:
	if DDCard.is_spell(kind):
		var s := DDSpell.new()
		s.setup(self, kind, team)
		s.position = world
		add_child(s)
		return s
	var data: Dictionary = DDCard.get_card(kind)
	var snapped := tile_center(
		floorf((world.x - ORIGIN.x) / TILE) + 0.5,
		floorf((world.y - ORIGIN.y) / TILE) + 0.5)
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
		selected_player = -1
		selected_index = -1
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		set_view_mode(1 - view_mode)
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
		if selected_player >= 0 and board_rect().has_point(world):
			deploy(selected_player, selected_index, world)
		elif not board_rect().has_point(world):
			selected_player = -1
			selected_index = -1


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
			var rect := Rect2(ORIGIN + Vector2(float(col), float(row)) * TILE, Vector2(TILE, TILE))
			var base := GRASS_A if (row + col) % 2 == 0 else GRASS_B
			if row_is_band(row):
				base = BAND_A if (row + col) % 2 == 0 else BAND_B
			draw_rect(rect, base)
	# halves tint
	for row in GRID_H:
		var c0 := col_min(row)
		var span := Rect2(ORIGIN + Vector2(float(c0), float(row)) * TILE, Vector2(float(col_max(row) - c0 + 1), 1.0) * TILE)
		if row < BAND_TOP:
			draw_rect(span, Color(0.92, 0.35, 0.35, 0.07))
		elif row > BAND_BOTTOM:
			draw_rect(span, Color(0.35, 0.55, 1.0, 0.07))
	# river
	var river_span := Rect2(ORIGIN + Vector2(0.0, RIVER_TOP) * TILE, Vector2(GRID_W, float(RIVER_BOTTOM - RIVER_TOP + 1)) * TILE)
	draw_rect(river_span, WATER)
	for i in 6:
		var y := river_span.position.y + 10.0 + float(i) * 9.0
		var phase := clock * 0.8 + float(i)
		var x := river_span.position.x + fmod(phase * 26.0, river_span.size.x)
		draw_line(Vector2(x, y), Vector2(x + 34.0, y), WATER_HI, 2.0, true)
	# bridges
	for bx in [BRIDGE_COL_A, BRIDGE_COL_B]:
		var br := Rect2(ORIGIN + Vector2(bx - 1.0, RIVER_TOP) * TILE, Vector2(2.0 * TILE, float(RIVER_BOTTOM - RIVER_TOP + 1) * TILE))
		draw_rect(br, WOOD)
		for k in 6:
			var y2 := br.position.y + 4.0 + float(k) * 9.0
			draw_line(Vector2(br.position.x + 2.0, y2), Vector2(br.end.x - 2.0, y2), Color(0.45, 0.31, 0.2), 1.5, true)
		draw_rect(br, DDArt.OUTLINE, false, 2.5)
	# control tint (after water so river claims read)
	for row in range(BAND_TOP, BAND_BOTTOM + 1):
		for col in range(col_min(row), col_max(row) + 1):
			var t := Vector2i(col, row)
			var c0: float = tile_claim(0, t)
			var c1: float = tile_claim(1, t)
			if c0 <= 0.02 and c1 <= 0.02:
				continue
			var rect := Rect2(ORIGIN + Vector2(float(col), float(row)) * TILE, Vector2(TILE, TILE))
			var f0 := clampf(c0 / CLAIM_TIME, 0.0, 1.0)
			var f1 := clampf(c1 / CLAIM_TIME, 0.0, 1.0)
			if c0 > 0.05 and c1 > 0.05:
				draw_rect(rect, Color(0.72, 0.45, 0.95, 0.42))
				draw_rect(rect, Color(0.85, 0.6, 1.0, 0.85), false, 1.5)
			elif c0 > 0.05:
				draw_rect(rect, Color(0.36, 0.62, 0.95, 0.3 + 0.3 * f0))
				if f0 > 0.6:
					draw_rect(rect, Color(0.6, 0.82, 1.0, 0.55), false, 1.0)
			else:
				draw_rect(rect, Color(0.95, 0.42, 0.44, 0.3 + 0.3 * f1))
				if f1 > 0.6:
					draw_rect(rect, Color(1.0, 0.72, 0.7, 0.55), false, 1.0)
	# dashed no-man's-land edges
	for edge_row in [BAND_TOP, BAND_BOTTOM + 1]:
		var y := ORIGIN.y + float(edge_row) * TILE
		var x := ORIGIN.x
		while x < ORIGIN.x + float(GRID_W) * TILE:
			draw_line(Vector2(x, y), Vector2(x + 7.0, y), Color(1.0, 0.9, 0.55, 0.55), 2.0)
			x += 14.0
	# board outline (plus shape)
	for row in GRID_H:
		var c0 := col_min(row)
		var c1 := col_max(row)
		var left := ORIGIN.x + float(c0) * TILE
		var right := ORIGIN.x + float(c1 + 1) * TILE
		var top := ORIGIN.y + float(row) * TILE
		var bot := top + TILE
		draw_line(Vector2(left, top), Vector2(left, bot), DDArt.OUTLINE, 4.0, true)
		draw_line(Vector2(right, top), Vector2(right, bot), DDArt.OUTLINE, 4.0, true)
	draw_line(Vector2(ORIGIN.x + float(col_min(0)) * TILE, ORIGIN.y), Vector2(ORIGIN.x + float(col_max(0) + 1) * TILE, ORIGIN.y), DDArt.OUTLINE, 4.0, true)
	var last := GRID_H - 1
	var yb := ORIGIN.y + float(GRID_H) * TILE
	draw_line(Vector2(ORIGIN.x + float(col_min(last)) * TILE, yb), Vector2(ORIGIN.x + float(col_max(last) + 1) * TILE, yb), DDArt.OUTLINE, 4.0, true)
	for edge_row in [BAND_TOP, BAND_BOTTOM + 1]:
		var y := ORIGIN.y + float(edge_row) * TILE
		draw_line(Vector2(ORIGIN.x, y), Vector2(ORIGIN.x + TILE, y), DDArt.OUTLINE, 4.0, true)
		draw_line(Vector2(ORIGIN.x + float(GRID_W - 1) * TILE, y), Vector2(ORIGIN.x + float(GRID_W) * TILE, y), DDArt.OUTLINE, 4.0, true)
	# deploy hint
	if selected_player >= 0 and not match_over and selected_index >= 0:
		var kind: String = hands[selected_player][selected_index]
		if not DDCard.is_spell(kind):
			for row in GRID_H:
				for col in range(col_min(row), col_max(row) + 1):
					var t := Vector2i(col, row)
					if not can_deploy(selected_player, kind, ORIGIN + Vector2(float(col) + 0.5, float(row) + 0.5) * TILE):
						continue
					draw_rect(Rect2(ORIGIN + Vector2(float(col), float(row)) * TILE, Vector2(TILE, TILE)), Color(0.9, 0.95, 0.6, 0.13))
		var m := get_global_mouse_position()
		if board_rect().has_point(m):
			var ok := can_deploy(selected_player, kind, m)
			var col2 := Color(0.5, 1.0, 0.6, 0.8) if ok else Color(1.0, 0.35, 0.35, 0.8)
			draw_arc(m, TILE * 0.9, 0.0, TAU, 32, col2, 2.5, true)
			DDArt.icon(self, kind, m, TILE * 0.55, clock)
	# bot intent, only rendered while both hands are on screen
	for p in 2:
		var tp := bot_target(p)
		if tp == Vector2.INF:
			continue
		var pulse := 0.5 + 0.5 * absf(sin(clock * 6.0))
		draw_arc(tp, TILE * 1.15, 0.0, TAU, 32, Color(0.55, 0.85, 1.0, 0.5 + 0.4 * pulse), 2.5, true)
		draw_arc(tp, TILE * 0.55, 0.0, TAU, 24, Color(1.0, 0.95, 0.75, 0.7), 2.0, true)
	# hover inspection (only when nothing is armed)
	if selected_player < 0 and not match_over:
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
		draw_string(ThemeDB.fallback_font, Vector2(board_rect().position.x, chip.end.y + 16.0),
			"DEBUG  1 = +1 gold P1    2 = +1 both    3 = +1 P2    B = bot",
			HORIZONTAL_ALIGNMENT_CENTER, board_rect().size.x, 13, Color(0.75, 0.8, 0.95, 0.75))
	# solo-mode opponent strip
	if view_mode == 0:
		var strip := Rect2(960.0, 46.0, 430.0, 120.0)
		draw_rect(strip, Color(0.1, 0.1, 0.14, 0.96), true)
		draw_rect(strip, DDArt.OUTLINE, false, 3.0)
		draw_rect(Rect2(strip.position, Vector2(strip.size.x, 6.0)), RED, true)
		draw_string(ThemeDB.fallback_font, Vector2(strip.position.x + 20.0, strip.position.y + 40.0), "OPPONENT",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, RED.lightened(0.3))
		DDArt.coin(self, Vector2(strip.position.x + 30.0, strip.position.y + 74.0), 12.0)
		draw_string(ThemeDB.fallback_font, Vector2(strip.position.x + 50.0, strip.position.y + 81.0),
			"%d gold" % int(floor(gold[1])), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.98, 0.85, 0.45))
		draw_string(ThemeDB.fallback_font, Vector2(strip.position.x + 20.0, strip.position.y + 108.0),
			"TAB — show both hands", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.7, 0.8))
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
