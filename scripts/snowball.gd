class_name DDSnowball
extends Node2D

## The Snowball spell. It leaves the caster's nearest tower as a single tile of
## packed snow and rolls along the row it was cast on, gaining a tile of height
## for every two tiles it covers. Everything enemy in its lane takes 10 damage per
## tile of height and is shoved that many tiles. When it reaches the river or the
## back of the board it bursts: 30 damage and a slow.

enum P { FLY, ROLL }

var area: Node2D = null
## so kill credit and any "what hit me" lookup has something to read
var kind := "snowball"
var team := 0
## It is thrown first: an arc from the tower to the tile you picked. Only after
## it lands does it start rolling, which is what lets you cast it on their side.
var phase := P.FLY
var launch_from := Vector2.ZERO
var land_to := Vector2.ZERO
var fly_t := 0.0
var fly_time := 0.5
const ARC_LIFT := 96.0
var clock := 0.0
var travelled := 0.0        ## pixels rolled, drives the growth
var height_t := 1.0         ## tiles tall; the lane it flattens
var speed_px := 160.0
var roll_dmg := 10.0        ## per tile of current height
var push_t := 1.0           ## tiles of shove per tile of height
var burst_dmg := 30.0
var slow_amount := 0.32
var slow_time := 3.5
var dir := 1.0
var row_y := 0.0
var hit: Dictionary = {}
var done := false
const GROWTH_TILES := 2.0


func setup(a: Node2D, tm: int, at: Vector2) -> void:
	area = a
	team = tm
	dir = 1.0 if tm == 0 else -1.0
	row_y = at.y
	var data: Dictionary = DDCard.get_card("snowball")
	var roll: Dictionary = data.get("roll", {})
	speed_px = float(roll.get("speed", 4.2)) * float(a.TILE)
	roll_dmg = float(roll.get("dmg", 10.0))
	push_t = float(roll.get("push", 1.0))
	burst_dmg = float(data.get("dmg", 30.0))
	slow_amount = float(data.get("slow", 0.32))
	slow_time = float(data.get("slow_time", 3.5))
	land_to = at
	var tw: Node = a.nearest_own_tower(tm, at)
	launch_from = tw.position + Vector2(0.0, -float(a.TILE) * 0.8) if tw != null else at
	position = launch_from
	z_index = 15


func tiles_rolled() -> float:
	return travelled / float(area.TILE)


## One tile at birth, one more for every two tiles of travel.
func current_height() -> float:
	return 1.0 + floorf(tiles_rolled() / GROWTH_TILES)


func _lane_half() -> float:
	return height_t * 0.5 * float(area.TILE)


func _in_lane(u: Node, x_reach_t: float) -> bool:
	if not is_instance_valid(u) or u.dead:
		return false
	var r: float = float(u.get_radius_t()) * float(area.TILE)
	if absf(u.position.y - row_y) > _lane_half() + r * 0.5:
		return false
	return absf(u.position.x - position.x) <= x_reach_t * float(area.TILE) + r


func _physics_process(delta: float) -> void:
	if done:
		return
	clock += delta
	if phase == P.FLY:
		fly_t += delta
		var f: float = clampf(fly_t / maxf(fly_time, 0.01), 0.0, 1.0)
		position = launch_from.lerp(land_to, f) - Vector2(0.0, sin(f * PI) * ARC_LIFT)
		queue_redraw()
		if f >= 1.0:
			# landed: now it is one tile of packed snow and starts to gather
			phase = P.ROLL
			position = land_to
			travelled = 0.0
			height_t = 1.0
			queue_redraw()
		return
	var step := speed_px * delta
	position.x += dir * step
	travelled += step
	height_t = current_height()
	_sweep()
	if _should_burst():
		_burst()
		return
	queue_redraw()


## Anything it rolls over: damage scaled by height, and a shove to match.
func _sweep() -> void:
	for u in area.enemy_units(team):
		if not _in_lane(u, 0.9):
			continue
		var key: int = u.get_instance_id()
		if hit.has(key):
			continue
		hit[key] = true
		u.take_damage(roll_dmg * height_t, position, self)
		if u.has_method("apply_impulse"):
			u.apply_impulse(Vector2(dir, 0.0), push_t * height_t, 0.3)


func _should_burst() -> bool:
	var river: Rect2 = area.tile_rect(area.col_min(area.RIVER_TOP), area.RIVER_TOP).merge(
		area.tile_rect(area.col_max(area.RIVER_BOTTOM), area.RIVER_BOTTOM))
	if position.x >= river.position.x - float(area.TILE) * 0.5 and position.x <= river.end.x + float(area.TILE) * 0.5:
		return true
	var board: Rect2 = area.board_rect()
	if dir > 0.0 and position.x >= board.end.x - float(area.TILE) * 0.4:
		return true
	if dir < 0.0 and position.x <= board.position.x + float(area.TILE) * 0.4:
		return true
	return false


func _burst() -> void:
	done = true
	for u in area.enemy_units(team).duplicate():
		if not _in_lane(u, 1.2):
			continue
		u.take_damage(burst_dmg, position)
		if u.has_method("slow"):
			u.slow(slow_amount, slow_time)
	for tw in area.towers.duplicate():
		if not is_instance_valid(tw) or tw.dead or int(tw.team) == team:
			continue
		if absf(tw.position.y - row_y) > _lane_half() + float(area.TILE) * 0.6:
			continue
		if absf(tw.position.x - position.x) > float(area.TILE) * 1.6:
			continue
		tw.take_damage(burst_dmg * 0.4, position)
	var b := DDBurst.new()
	b.setup(area, maxf(height_t * 0.5, 1.0), Color(0.72, 0.88, 1.0))
	b.position = position
	area.add_child(b)
	area.shake(3.0)
	queue_free()


func _draw() -> void:
	var r: float = maxf(height_t * 0.5, 0.5) * float(area.TILE)
	var spin := clock * 2.4 * dir
	if phase == P.FLY:
		# in the air: shadow on the ground below it, ball up in the arc
		var f: float = clampf(fly_t / maxf(fly_time, 0.01), 0.0, 1.0)
		var lift: float = sin(f * PI) * ARC_LIFT
		draw_set_transform(Vector2(0.0, lift + r * 0.8), 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, r * (1.05 - 0.3 * sin(f * PI)), Color(0.05, 0.07, 0.12, 0.26))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_ball(r, spin * 2.2)
		return
	# snow kicked up behind it
	for i in 4:
		var back: float = r * (1.1 + 0.4 * float(i))
		var puff: float = r * (0.34 - 0.06 * float(i))
		draw_circle(Vector2(-dir * back, sin(clock * 6.0 + float(i)) * r * 0.12), puff,
			Color(0.86, 0.94, 1.0, 0.22 - 0.04 * float(i)))
	draw_set_transform(Vector2(0.0, r * 0.82), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, r * 0.92, Color(0.05, 0.07, 0.12, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_ball(r, spin)


func _ball(r: float, spin: float) -> void:
	draw_circle(Vector2.ZERO, r, Color(0.9, 0.95, 1.0))
	draw_circle(Vector2(-r * 0.28, -r * 0.3), r * 0.52, Color(1.0, 1.0, 1.0, 0.92))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 44, Color(0.5, 0.68, 0.92, 0.95), 2.4, true)
	for i in 5:
		var a := spin + float(i) * TAU / 5.0
		draw_circle(Vector2(cos(a), sin(a)) * r * 0.58, r * 0.11, Color(0.66, 0.82, 1.0, 0.9))
	for i in 3:
		var t2: float = clock * 4.0 + float(i) * 2.1
		draw_line(Vector2(cos(t2) * r * 0.72, sin(t2) * r * 0.72),
			Vector2(cos(t2 + 0.5) * r * 0.94, sin(t2 + 0.5) * r * 0.94), Color(0.55, 0.72, 0.95, 0.5), 1.6, true)

