extends Node2D

## One tentacle of the South Sea Kraken (NOTES §10). Like the spider it duck-types
## a tower: it sits in arena.towers (not a crown), so troops walk at it and hit it
## like any tower. No class_name; scripts/kraken.gd preloads it.
##
## It is rooted in one tile (`base`). The part troops hit, this node's position,
## is its body and head, which lean slowly toward the nearest enemy but never
## more than `lean` tiles from the root on either axis (a 3x3 area).
##
## Attacks, each wind-up -> strike -> recover, all on fixed physics ticks:
##   slam    an enemy within `reach`: sway, smash, then waves ahead and to both
##           sides of the impact. Nothing behind it is touched.
##   spin    at or under spin_hp of its HP with an enemy inside spin_radius: coil
##           back, then one full turn that hits everything in that radius.
##   arrow   on its own timer, and only if every enemy unit is arrow_min tiles
##           away or more: flatten, point, shoot a slow straight arrow that the
##           first body in its path takes.
##   burrow  revived tentacles only, when the kraken says so: sink, mark the spot
##           a troop is standing on, burst out there and hold whoever is still on
##           it (the hero ability's tentacle: 4 s unless it is cut down).
##
## `dead` means "cannot be targeted right now" (sunk or away burrowing); `down`
## means it was actually killed. All numbers: the "krakenarm" card.

enum A { IDLE, SLAM_WIND, SLAM_DOWN, SPIN_WIND, SPIN, ARROW_WIND, RECOVER, DOWN, RISING, SINKING, AWAY }

const SLAM_HOLD := 0.35
const BURST_SHOW := 0.5
const BURN_RATE := 0.2

var kind := "krakenarm"
var team := 1
var arena: Node2D = null
var boss: Node = null
var crown := false
var dead := false
var down := false
var hp := 150.0
var max_hp := 150.0
var full_hp := 150.0
var radius_t := 0.7
var reach := 3.5
var dmg := 30.0
var interval := 2.5
var cfg: Dictionary = {}
## multiplies the wait between attacks: 1 normally; revived tentacles get
## 1 / revive_speed (under 1: faster)
var slow := 1.0
var revived := false

var base := Vector2.ZERO
var offset := Vector2.ZERO
var state: int = A.IDLE
var state_t := 0.0
var attack_cd := 1.0
var arrow_cd := 10.0
var aim := Vector2.LEFT
var home_dir := Vector2.LEFT
var impact := Vector2.ZERO
var arrow_target: Node = null
## where the pose was when RECOVER began (world point under the head, head height)
var rec_ground := Vector2.ZERO
var rec_lift := 0.0
var wave_t := 0.0
var wave_at := Vector2.ZERO
var wave_dir := Vector2.LEFT
## burrow
var spot := Vector2.ZERO
var warn_t := 0.0
var burst_t := 0.0
var grab: Node = null
var away_done := false

var clock := 0.0
var flash := 0.0
var burn_stack := 0.0
var burn_ticks := 0
var burn_max_ticks := 4
var burn_timer := 0.0
var over_layer: Node2D = null


func setup(a: Node2D, tm: int, owner_boss: Node, tile: Vector2i) -> void:
	arena = a
	team = tm
	boss = owner_boss
	var d: Dictionary = DDCard.get_card("krakenarm")
	cfg = d.get("arm", {})
	full_hp = float(d["hp"])
	max_hp = full_hp
	hp = max_hp
	radius_t = float(d["radius"])
	reach = float(d["reach"])
	dmg = float(d["dmg"])
	interval = float(d["interval"])
	base = arena.tile_center(float(tile.x) + 0.5, float(tile.y) + 0.5)
	position = base
	# toward the player's board
	aim = (arena.tile_center(float(tile.x) + 0.5, float(tile.y) + 1.5) - base).normalized()
	home_dir = aim
	offset = home_dir * float(arena.TILE) * 0.6
	position = base + offset
	z_index = 4


func _ready() -> void:
	# the burrow warning has to show over the troops it is aimed at
	over_layer = Node2D.new()
	over_layer.top_level = true
	over_layer.z_as_relative = false
	over_layer.z_index = 13
	over_layer.draw.connect(_draw_over)
	add_child(over_layer)


func is_building() -> bool:
	return true


func is_tower() -> bool:
	return true


func get_radius_t() -> float:
	return radius_t


func add_poison(_amount: float) -> void:
	pass


func busy() -> bool:
	return state != A.IDLE


func _physics_process(delta: float) -> void:
	clock += delta
	flash = maxf(0.0, flash - delta * 5.0)
	wave_t = maxf(0.0, wave_t - delta)
	burst_t = maxf(0.0, burst_t - delta)
	queue_redraw()
	if over_layer != null:
		over_layer.queue_redraw()
	if arena.match_over or down:
		return
	_tick_burn(delta)
	if down:
		return
	arrow_cd = maxf(0.0, arrow_cd - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	state_t += delta
	match state:
		A.IDLE:
			_lean(delta)
			if attack_cd <= 0.0:
				_pick_attack()
		A.SLAM_WIND:
			if state_t >= float(cfg["slam_windup"]):
				_slam()
		A.SLAM_DOWN:
			if state_t >= SLAM_HOLD:
				_recover(impact, 0.0)
		A.SPIN_WIND:
			if state_t >= float(cfg["spin_windup"]):
				_spin()
		A.SPIN:
			if state_t >= float(cfg["spin_time"]):
				_recover(position + _spin_dir(1.0) * float(cfg["spin_radius"]) * 0.85 * float(arena.TILE),
					float(arena.TILE) * 0.25)
		A.ARROW_WIND:
			if arrow_target != null and is_instance_valid(arrow_target) and arrow_target.get("dead") != true:
				var to: Vector2 = arrow_target.position - position
				if to.length() > 1.0:
					aim = to.normalized()
			if state_t >= float(cfg["arrow_windup"]):
				_shoot()
		A.RECOVER:
			if state_t >= float(cfg["recover"]):
				_set_state(A.IDLE)
				attack_cd = interval * slow
		A.RISING:
			if state_t >= float(cfg["rise_time"]):
				_set_state(A.IDLE)
		A.SINKING:
			if state_t >= float(cfg["burrow_sink"]):
				_go_under()
		A.AWAY:
			_tick_away(delta)


func _set_state(s: int) -> void:
	state = s
	state_t = 0.0


func _recover(ground_world: Vector2, lift: float) -> void:
	rec_ground = ground_world
	rec_lift = lift
	_set_state(A.RECOVER)


# --------------------------------------------------------------------- choosing

## Nearest enemy unit and the gap to its edge, in tiles: [node, gap] or [null, INF].
func _nearest_unit() -> Array:
	var best: Node = null
	var best_d := INF
	for u in arena.enemy_units(team):
		if not is_instance_valid(u) or u.dead:
			continue
		var d: float = arena.tiles_between(position, u.position) - float(u.get_radius_t())
		if d < best_d - 0.0001 or (absf(d - best_d) <= 0.0001 and best != null and u.get_instance_id() < best.get_instance_id()):
			best = u
			best_d = d
	return [best, best_d]


func _nearest_entity() -> Node:
	var best: Node = null
	var best_d := INF
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = arena.tiles_between(position, e.position)
		if d < best_d - 0.0001 or (absf(d - best_d) <= 0.0001 and best != null and e.get_instance_id() < best.get_instance_id()):
			best = e
			best_d = d
	return best


## The head drifts toward the nearest enemy in sight, inside its 3x3 area.
func _lean(delta: float) -> void:
	var tile: float = float(arena.TILE)
	# with nobody in sight it hangs over toward the player's board
	var want: Vector2 = home_dir * tile * 0.6
	var near: Array = _nearest_unit()
	if near[0] != null and float(near[1]) <= float(cfg["lean_sight"]):
		var to: Vector2 = near[0].position - base
		var lim: float = float(cfg["lean"]) * tile
		want = Vector2(clampf(to.x, -lim, lim), clampf(to.y, -lim, lim))
	offset = offset.move_toward(want, float(cfg["lean_speed"]) * tile * delta)
	position = base + offset


func _pick_attack() -> void:
	var tile: float = float(arena.TILE)
	var near: Array = _nearest_unit()
	var u: Node = near[0]
	var gap: float = float(near[1])
	if u != null:
		var to: Vector2 = u.position - position
		if to.length() > 1.0:
			aim = to.normalized()
		if hp <= max_hp * float(cfg["spin_hp"]) and gap <= float(cfg["spin_radius"]):
			_set_state(A.SPIN_WIND)
			return
		if gap <= reach:
			impact = position + aim * clampf(to.length() / tile, 1.0, float(cfg["slam_reach"])) * tile
			_set_state(A.SLAM_WIND)
			return
	if arrow_cd <= 0.0 and (u == null or gap >= float(cfg["arrow_min"])):
		arrow_target = _nearest_entity()
		if arrow_target != null:
			aim = (arrow_target.position - position).normalized()
			_set_state(A.ARROW_WIND)


# ---------------------------------------------------------------------- attacks

## The smash. Everything in a rectangle around the impact is hit: wave_len tiles
## ahead of it and to both sides, and only wave_back tiles behind it, so the
## ground behind the tentacle is safe.
func _slam() -> void:
	var tile: float = float(arena.TILE)
	var length: float = float(cfg["wave_len"])
	var back: float = float(cfg["wave_back"])
	var side := Vector2(-aim.y, aim.x)
	for e in arena.enemy_entities(team).duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector2 = (e.position - impact) / tile
		var r: float = float(e.get_radius_t()) * 0.5
		var x: float = rel.dot(aim)
		var y: float = rel.dot(side)
		if x >= -back - r and x <= length + r and absf(y) <= length + r:
			e.take_damage(dmg, impact)
	wave_at = impact
	wave_dir = aim
	wave_t = float(cfg["wave_time"])
	arena.shake(3.0)
	_set_state(A.SLAM_DOWN)


func _spin() -> void:
	var radius: float = float(cfg["spin_radius"])
	for e in arena.enemy_entities(team).duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		if arena.tiles_between(position, e.position) <= radius + float(e.get_radius_t()) * 0.5:
			e.take_damage(float(cfg["spin_dmg"]), position)
	arena.shake(2.0)
	_set_state(A.SPIN)


## Where the tip is p of the way through the spin (it coils 0.9 rad back first).
func _spin_dir(p: float) -> Vector2:
	return Vector2.from_angle(aim.angle() - 0.9 + (TAU + 0.9) * p)


func _shoot() -> void:
	var tile: float = float(arena.TILE)
	boss.fire_arrow(position + aim * tile * 1.5, aim, float(cfg["arrow_dmg"]), float(cfg["arrow_speed"]))
	arrow_cd = float(cfg["arrow_every"]) * slow
	_recover(position + aim * tile * 0.5, tile * 0.12)


# ----------------------------------------------------------------------- burrow

## Called by the kraken. Sinks through its root, then comes up under `victim`.
func begin_burrow(victim: Node) -> bool:
	if down or state != A.IDLE or not revived:
		return false
	if victim == null or not is_instance_valid(victim) or victim.dead:
		return false
	grab = victim
	_set_state(A.SINKING)
	return true


func _go_under() -> void:
	dead = true
	offset = Vector2.ZERO
	position = base
	_set_state(A.AWAY)
	away_done = false
	if grab == null or not is_instance_valid(grab) or grab.dead:
		grab = null
		away_done = true
		return
	# the mark is fixed where the troop stands now; it has the warning to walk off
	spot = grab.position
	grab = null
	warn_t = float(cfg["burrow_warn"])


func _tick_away(delta: float) -> void:
	if warn_t > 0.0:
		warn_t -= delta
		if warn_t <= 0.0:
			_burst()
		return
	if grab != null and is_instance_valid(grab) and not grab.dead:
		return
	grab = null
	if away_done or burst_t <= 0.0:
		dead = false
		_set_state(A.RISING)


func _burst() -> void:
	burst_t = BURST_SHOW
	arena.shake(2.5)
	var victim: Node = null
	var best := INF
	for u in arena.enemy_units(team):
		# troops, and Shiesty on his run home (anything else in `units`, such as a
		# hero tentacle, is not a body to grab)
		if not is_instance_valid(u) or u.dead or not (u is DDUnit or u is DDShiesty):
			continue
		if u.get("flying") == true or u.is_building():
			continue
		var d: float = arena.tiles_between(spot, u.position)
		if d <= float(cfg["burrow_catch"]) and d < best:
			best = d
			victim = u
	if victim == null:
		return
	# the hero ability's tentacle, on the kraken's side
	var t := DDTentacle.new()
	t.hp = float(arena.TENTACLE_HP)
	t.max_hp = float(arena.TENTACLE_HP)
	t.life = float(arena.TENTACLE_TIME)
	t.dmg = float(arena.TENTACLE_DMG)
	t.interval = float(arena.TENTACLE_INTERVAL)
	t.setup(arena, team, victim)
	t.position = victim.position
	arena.units.append(t)
	arena.add_child(t)
	# the tentacle squeezes on its own clock (first squeeze on the grab)
	if is_instance_valid(victim) and not victim.dead:
		victim.stunned = float(arena.TENTACLE_TIME)
		grab = t
		arena.banner_flash("A tentacle bursts up under %s!" % DDCard.pretty(String(victim.kind)))


# ----------------------------------------------------------------------- damage

func revive(hp_share: float, slow_by: float) -> void:
	down = false
	dead = false
	revived = true
	slow = slow_by
	max_hp = full_hp * hp_share
	hp = max_hp
	burn_stack = 0.0
	burn_timer = 0.0
	offset = Vector2.ZERO
	position = base
	attack_cd = interval
	_set_state(A.RISING)


func _tick_burn(delta: float) -> void:
	if burn_timer <= 0.0 or dead:
		return
	burn_timer -= delta
	if burn_timer > 0.0:
		return
	var tick_dmg := floorf(burn_stack * BURN_RATE)
	burn_ticks += 1
	if tick_dmg <= 0.0:
		burn_stack = 0.0
		burn_ticks = 0
		burn_timer = 0.0
	else:
		burn_stack = maxf(0.0, burn_stack - tick_dmg)
		burn_timer = 1.0
		arena.tick_damage(self, tick_dmg)
		# the last tick still lands, as on a troop; then the fire is out
		if burn_ticks >= burn_max_ticks:
			burn_stack = 0.0
			burn_ticks = 0
			burn_timer = 0.0


func apply_burn(amount: float, max_ticks: int = 4) -> void:
	if dead or amount <= 0.0:
		return
	burn_stack += amount
	burn_ticks = 0
	burn_max_ticks = maxi(max_ticks, 1)
	if burn_timer <= 0.0:
		burn_timer = 1.0


func take_damage(amount: float, _from: Vector2, _attacker: Node = null) -> void:
	if dead or amount <= 0.0:
		return
	hp -= arena.scale_hit(amount, team)
	flash = 0.5
	if arena.show_damage():
		arena.spawn_damage_text(position + Vector2(0.0, -float(arena.TILE) * 1.6), amount,
			Color(1.0, 0.85, 0.5) if amount >= 20.0 else Color(0.95, 0.95, 1.0))
	if hp <= 0.0:
		sink()
		boss.on_arm_down(self)


## Killed: it pulls back into the ground and only the horn is left showing.
func sink() -> void:
	hp = 0.0
	dead = true
	down = true
	offset = Vector2.ZERO
	position = base
	wave_t = 0.0
	warn_t = 0.0
	_set_state(A.DOWN)
	queue_redraw()


# -------------------------------------------------------------------------- art

func _draw() -> void:
	var tile: float = float(arena.TILE)
	var root: Vector2 = base - position
	if wave_t > 0.0:
		_draw_waves(tile)
	if state == A.DOWN:
		DDArt.kraken_stub(self, root, tile)
		return
	var ground := Vector2.ZERO
	var lift: float = tile * 0.9
	var arch: float = tile * 0.9
	var horn: Vector2 = (aim + Vector2(0.0, 0.45)).normalized()
	var sway := 0.0
	var out := 1.0
	match state:
		A.SLAM_WIND:
			lift = tile * 1.6
			arch = tile * 1.2
			sway = sin(state_t * 16.0) * tile * 0.3
		A.SLAM_DOWN:
			var k: float = clampf(state_t / 0.08, 0.0, 1.0)
			ground = (impact - position) * k
			lift = tile * 1.6 * (1.0 - k)
			arch = tile * 0.5
			horn = aim
		A.SPIN_WIND:
			var p: float = clampf(state_t / float(cfg["spin_windup"]), 0.0, 1.0)
			var ang: float = aim.angle() - 0.9 * p
			ground = Vector2.from_angle(ang) * tile * 1.2
			lift = tile * 0.35
			arch = tile * 0.6
			# the tip points back, away from the way it is about to go
			horn = Vector2.from_angle(ang - PI * 0.5)
		A.SPIN:
			var p2: float = clampf(state_t / float(cfg["spin_time"]), 0.0, 1.0)
			var d2: Vector2 = _spin_dir(p2)
			var rad: float = float(cfg["spin_radius"]) * 0.85 * tile
			ground = d2 * rad
			lift = tile * 0.25
			arch = tile * 0.5
			horn = d2
			var swept: float = minf(2.2, (TAU + 0.9) * p2)
			draw_arc(Vector2.ZERO, rad, d2.angle() - swept, d2.angle(), 24,
				Color(DDArt.KRAKEN_PINK.r, DDArt.KRAKEN_PINK.g, DDArt.KRAKEN_PINK.b, 0.55), tile * 0.4, true)
		A.ARROW_WIND:
			var p3: float = clampf(state_t / float(cfg["arrow_windup"]), 0.0, 1.0)
			ground = aim * tile * 0.5 * p3
			lift = lerpf(tile * 0.9, tile * 0.12, p3)
			arch = lerpf(tile * 0.9, tile * 0.2, p3)
			horn = aim
			# the stinger charges
			draw_circle(ground + Vector2(0.0, -lift) + aim * tile * 1.1, tile * 0.16 * p3,
				Color(DDArt.KRAKEN_PURPLE.r, DDArt.KRAKEN_PURPLE.g, DDArt.KRAKEN_PURPLE.b, 0.7))
		A.RECOVER:
			var p4: float = clampf(state_t / float(cfg["recover"]), 0.0, 1.0)
			ground = (rec_ground - position) * (1.0 - p4)
			lift = lerpf(rec_lift, tile * 0.9, p4)
		A.RISING:
			out = clampf(state_t / float(cfg["rise_time"]), 0.0, 1.0)
		A.SINKING:
			out = 1.0 - clampf(state_t / float(cfg["burrow_sink"]), 0.0, 1.0)
		A.AWAY:
			out = 0.0
	DDArt.kraken_arm(self, root, ground, lift, arch, horn, tile, arena.team_color(int(team)), clock, sway, out,
		arena.team_ink(int(team)))
	if flash > 0.0 and out > 0.5:
		draw_circle(ground + Vector2(0.0, -lift), tile * 0.5, Color(1.0, 1.0, 1.0, 0.35 * flash))
	if dead:
		return
	var bw: float = tile * 1.3
	var by: float = -tile * 2.1
	draw_rect(Rect2(-bw * 0.5, by, bw, 6.0), Color(0.08, 0.07, 0.1, 0.85), true)
	draw_rect(Rect2(-bw * 0.5 + 1.0, by + 1.0, (bw - 2.0) * clampf(hp / max_hp, 0.0, 1.0), 4.0),
		Color(0.95, 0.45, 0.45), true)


## The slam's shockwave: a rectangle growing out of the impact, ahead and to both
## sides, with a bright front on each of those three edges.
func _draw_waves(tile: float) -> void:
	var total: float = float(cfg["wave_time"])
	var q: float = 1.0 - wave_t / total
	var length: float = float(cfg["wave_len"]) * tile * q
	var back: float = float(cfg["wave_back"]) * tile
	var c: Vector2 = wave_at - position
	var f: Vector2 = wave_dir
	var s := Vector2(-f.y, f.x)
	var a: Vector2 = c - f * back - s * length
	var b: Vector2 = c + f * length - s * length
	var d: Vector2 = c + f * length + s * length
	var e: Vector2 = c - f * back + s * length
	var fill := DDArt.KRAKEN_PURPLE
	draw_colored_polygon(PackedVector2Array([a, b, d, e]), Color(fill.r, fill.g, fill.b, 0.3 * (1.0 - q)))
	var edge := Color(DDArt.KRAKEN_PINK.r, DDArt.KRAKEN_PINK.g, DDArt.KRAKEN_PINK.b, 0.95 * (1.0 - q * 0.6))
	draw_line(b, d, edge, 4.0, true)
	draw_line(a, b, edge, 4.0, true)
	draw_line(e, d, edge, 4.0, true)


## Burrow: the red mark over the spot, then the burst.
func _draw_over() -> void:
	var tile: float = float(arena.TILE)
	if state == A.AWAY and warn_t > 0.0:
		var pulse: float = 0.75 + 0.25 * sin(clock * 30.0)
		var red := Color(1.0, 0.2, 0.2, pulse)
		over_layer.draw_arc(spot + Vector2(0.0, -tile * 0.95), tile * 0.22, 0.0, TAU, 20, red, 3.0, true)
		over_layer.draw_set_transform(spot, 0.0, Vector2(1.0, 0.5))
		over_layer.draw_arc(Vector2.ZERO, tile * 0.7, 0.0, TAU, 28, Color(1.0, 0.2, 0.2, 0.6 * pulse), 2.0, true)
		over_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if burst_t > 0.0:
		var p: float = 1.0 - burst_t / BURST_SHOW
		over_layer.draw_set_transform(spot, 0.0, Vector2(1.0, 0.5))
		over_layer.draw_arc(Vector2.ZERO, tile * (0.4 + 0.9 * p), 0.0, TAU, 28, Color(0.85, 0.75, 0.6, 0.8 * (1.0 - p)), 3.0, true)
		over_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 6:
			var a: float = TAU * float(i) / 6.0 + 0.4
			over_layer.draw_circle(spot + Vector2(cos(a), sin(a) * 0.5) * tile * (0.3 + 0.8 * p) + Vector2(0.0, -tile * 0.5 * sin(p * PI)),
				tile * 0.07, Color(0.6, 0.5, 0.42, 1.0 - p))
