class_name DDShiesty
extends Node2D

## Hero ability "Shiesty": leaps from your king tower onto the enemy tower with
## the most HP (leftmost on ties), hits it once and steals 1 gold. Then it runs
## home — reaching your tower keeps the gold, dying hands it back.
##
## Shiesty is a thief, not a soldier: it gives its owner no map presence and
## towers ignore it entirely. Only troops can stop it.

enum P { LAND, RETURN }

var kind := "shiesty"
var arena: Node2D = null
var team := 0
var hp := 40.0
var max_hp := 40.0
var dmg := 30.0
var interval := 1.0
var flying := false
var gives_presence := false
var tower_ignore := true
## Airborne on the way out: nothing can see or hurt him until he lands.
var untargetable := true
var dead := false
var incoming := 0.0
var phase: int = P.LAND
var clock := 0.0
var land_time := 0.7
var from := Vector2.ZERO
var target_tower: Node = null
var home_tower: Node = null
var stolen := 0.0
var speed_px := 25.0
var radius_t := 0.4
## Pen's darts work on him too: a stunned Shiesty stands still.
var stunned := 0.0
var run_clock := 0.0
## cosmetic: which way he is drawn facing
var facing := 1.0
## the bridge column he runs home over, fixed when he lands
var bridge_col := 5.0
## enemy troops able to hit him on each half when he chose [bridge A, bridge B]
var lane_threat := [0, 0]


func setup(a: Node2D, tm: int, tower: Node, home: Node) -> void:
	arena = a
	team = tm
	target_tower = tower
	home_tower = home
	from = home.position if home != null else Vector2.ZERO
	position = from
	speed_px = 1.8    * float(a.TILE)
	z_index = 9


func is_building() -> bool:
	return false


func is_tower() -> bool:
	return false


func get_radius_t() -> float:
	return radius_t


func _physics_process(delta: float) -> void:
	if dead:
		return
	clock += delta
	if stunned > 0.0:
		stunned = maxf(0.0, stunned - delta)
		queue_redraw()
		return
	if phase == P.LAND:
		var to: Vector2 = from
		if is_instance_valid(target_tower):
			to = target_tower.position
		var f := clampf(clock / land_time, 0.0, 1.0)
		position = from.lerp(to, f) - Vector2(0, sin(f * PI) * 80.0)
		queue_redraw()
		if f >= 1.0:
			_land()
		return
	run_clock += delta
	var home: Vector2 = from
	if is_instance_valid(home_tower):
		home = home_tower.position
	var wp: Vector2 = _route_home(position, home)
	var dir: Vector2 = wp - position
	if dir.length() < 2.0:
		dir = home - position
	if position.distance_to(home) < float(arena.TILE) * 1.2:
		_escape()
		return
	if dir.length() > 0.001:
		position += dir.normalized() * speed_px * delta
		if absf(dir.x) > 0.5:
			facing = signf(dir.x)
	queue_redraw()


func _land() -> void:
	if is_instance_valid(target_tower) and not target_tower.dead:
		target_tower.take_damage(dmg, position)
	var enemy_team := 1 - team
	var steal: float = minf(1.0, float(arena.gold[enemy_team]))
	if steal > 0.0:
		arena.gold[enemy_team] = float(arena.gold[enemy_team]) - steal
	stolen = steal
	arena.banner_flash("Shiesty picks a pocket! %d gold taken" % int(steal))
	# back on the ground: the run home is the dangerous part
	untargetable = false
	phase = P.RETURN
	clock = 0.0
	bridge_col = _pick_bridge()
	queue_redraw()


## Chosen once, as he lands: the bridge whose half of the board holds fewer
## enemy troops that could attack him. Ties go to the nearer bridge. He never
## changes his mind on the way.
func _pick_bridge() -> float:
	var a: float = float(arena.BRIDGE_COL_A)
	var b: float = float(arena.BRIDGE_COL_B)
	var split: float = (a + b) * 0.5 + 0.5
	var threat := [0, 0]
	for u in arena.units:
		if not _can_hit_me(u):
			continue
		var col: float = float(arena.tile_of(u.position).x) + 0.5
		threat[0 if col < split else 1] += 1
	lane_threat = threat
	if threat[0] != threat[1]:
		return a if threat[0] < threat[1] else b
	return arena.nearest_bridge_col(arena.tile_of(position).x)


## An enemy troop or building that would pick him as a target.
func _can_hit_me(u: Node) -> bool:
	if not (u is DDUnit) or not is_instance_valid(u) or u.dead or int(u.team) == team:
		return false
	if (float(u.dmg) <= 0.0 and u.shoot_payload.is_empty()) or u.buildings_only or u.phase2:
		return false
	if String(u.kind) == "dragon" and u.flying:
		return false
	return true


## arena.route_point, but always through the bridge he picked.
func _route_home(from_p: Vector2, goal: Vector2) -> Vector2:
	var f: Vector2i = arena.tile_of(from_p)
	var g: Vector2i = arena.tile_of(goal)
	var toward_enemy: bool = g.y < arena.RIVER_TOP and f.y >= arena.RIVER_TOP
	var toward_home: bool = g.y > arena.RIVER_BOTTOM and f.y <= arena.RIVER_BOTTOM
	if not toward_enemy and not toward_home:
		return goal
	var bc: float = bridge_col
	var top: float = float(arena.RIVER_TOP)
	var bottom: float = float(arena.RIVER_BOTTOM)
	var lane: Vector2 = arena.tile_center(bc + 0.5, top + 0.5).lerp(arena.tile_center(bc + 0.5, bottom + 0.5), 0.5)
	var far_bank: Vector2 = arena.tile_center(bc + 0.5, top - 1.2) if toward_enemy else arena.tile_center(bc + 0.5, bottom + 1.2)
	var off: float = absf(from_p.y - lane.y) if arena.LANDSCAPE else absf(from_p.x - lane.x)
	if off > float(arena.TILE) * 0.7:
		return arena.tile_center(bc + 0.5, bottom + 1.0) if toward_enemy else arena.tile_center(bc + 0.5, top - 1.0)
	return far_bank


func _escape() -> void:
	arena.stat_shiesty_escaped += 1
	arena.gold[team] = minf(float(arena.gold_max), float(arena.gold[team]) + stolen)
	arena.banner_flash("Shiesty gets away with %d gold" % int(stolen))
	# the card is the reward for the trip itself; the coin is the bonus
	arena.draw_card(team)
	_finish()


func take_damage(amount: float, _from: Vector2, _attacker: Node = null) -> void:
	if dead or amount <= 0.0 or untargetable:
		return
	hp -= amount
	if hp <= 0.0:
		var enemy_team := 1 - team
		arena.stat_shiesty_caught += 1
		if stolen > 0.0:
			arena.gold[enemy_team] = minf(float(arena.gold_max), float(arena.gold[enemy_team]) + stolen)
			arena.banner_flash("Shiesty is caught — %d gold recovered" % int(stolen))
		# caught or not, the trip pays a card; only the coin has to get home
		arena.draw_card(team)
		_finish()
	queue_redraw()


func _finish() -> void:
	if dead:
		return
	dead = true
	arena.unregister(self)
	queue_free()


## Where he is *drawn* on the way out, as an offset from his real position. The
## simulation keeps the plain tower-to-tower arc (nothing can touch him in the
## air, so only the picture changes): for the first TOSS_SCOOP seconds he sits in
## the goblin commander's hand as it scoops him off the ground and swings him
## overhead, and the rest of the flight starts from that hand.
func _launch_offset() -> Vector2:
	if phase != P.LAND or not is_instance_valid(home_tower) or not home_tower.has_method("face_dir"):
		return Vector2.ZERO
	var to: Vector2 = from
	if is_instance_valid(target_tower):
		to = target_tower.position
	var r_c: float = float(home_tower.w) * 0.62
	var face: float = home_tower.face_dir()
	var at: Vector2
	if clock < DDArt.TOSS_SCOOP:
		# in the fist; before the grab he is crouched where the hand comes down
		var p: float = maxf(clock / DDArt.TOSS_SCOOP, 0.4)
		at = home_tower.position + DDArt.commander_toss_hand(r_c, face, p)
	else:
		var start: Vector2 = home_tower.position + DDArt.commander_toss_hand(r_c, face, 1.0)
		var g: float = clampf((clock - DDArt.TOSS_SCOOP) / maxf(0.05, land_time - DDArt.TOSS_SCOOP), 0.0, 1.0)
		at = start.lerp(to, g) - Vector2(0, sin(g * PI) * 80.0)
	return at - position


func _draw() -> void:
	var r: float = radius_t * float(arena.TILE)
	var spin := 0.0
	if phase == P.LAND:
		if is_instance_valid(target_tower) and absf(target_tower.position.x - from.x) > 1.0:
			facing = signf(target_tower.position.x - from.x)
		if clock >= DDArt.TOSS_SCOOP:
			# thrown, not jumping: he tumbles once on the way over
			spin = facing * TAU * clampf((clock - DDArt.TOSS_SCOOP) / maxf(0.05, land_time - DDArt.TOSS_SCOOP), 0.0, 1.0)
		draw_set_transform(_launch_offset(), spin, Vector2.ONE)
		draw_arc(Vector2.ZERO, r * 1.2, 0.0, TAU, 20, Color(1.0, 0.9, 0.4, 0.35), 2.0, true)
	DDArt.shiesty(self, r, facing, run_clock, arena.team_ink(int(team)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hp < max_hp:
		var w := r * 2.0
		draw_rect(Rect2(-w * 0.5, -r * 1.6, w, 3.0), Color(0.1, 0.08, 0.12, 0.8), true)
		draw_rect(Rect2(-w * 0.5, -r * 1.6, w * clampf(hp / max_hp, 0.0, 1.0), 3.0), Color(0.5, 0.9, 0.5), true)
