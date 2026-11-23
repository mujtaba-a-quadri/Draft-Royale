extends Node2D

## The South Sea Kraken: the second elite encounter (NOTES §10).
##
## Phase 1: five tentacles (scripts/kraken_arm.gd) stand in for the enemy towers.
## The body is under water: it is not in arena.towers and cannot be hit.
## Phase 2, once every tentacle is down: the body surfaces in the middle of its
## side as the crown "tower" (killing it wins), raises every tentacle again with
## revive_hp of its HP, attacking revive_speed times as fast, and from then on
##   orbs    every orb_every s it spews orb_count big red orbs. Each turns slowly
##           toward the nearest enemy, bursts on touch or on timeout, and splits
##           into 3-5 small orbs that chase for a moment and burst too.
##   burrow  every burrow_every s the next free tentacle burrows at a troop.
##
## It also flies the tentacles' purple arrows, so every projectile of this fight
## lives in one place. All on fixed physics ticks with a seeded RNG. Numbers:
## the "kraken" card. No class_name; arena.gd preloads it.

const ARM_SCRIPT := preload("res://scripts/kraken_arm.gd")
const BURN_RATE := 0.2
const BIG_R := 0.34
const SMALL_R := 0.18
const MOUTH_SHOW := 0.7

var kind := "kraken"
var team := 1
var arena: Node2D = null
var crown := true
var dead := false
var hp := 500.0
var max_hp := 500.0
var radius_t := 1.5
var reach := 0.0
var dmg := 0.0
var interval := 0.0
var cfg: Dictionary = {}

var phase := 1
var arms: Array = []
var fwd := Vector2.LEFT
var clock := 0.0
var flash := 0.0
var emerge_t := 0.0
var orb_clock := 0.0
var mouth_t := 0.0
var burrow_clock := 0.0
var next_burrow := 0
var rng := RandomNumberGenerator.new()

## [{"pos": Vector2, "dir": Vector2, "dmg": float, "speed": float, "t": float}]
var arrows: Array = []
## [{"pos": Vector2, "dir": Vector2, "big": bool, "t": float}]
var orbs: Array = []

var burn_stack := 0.0
var burn_ticks := 0
var burn_max_ticks := 4
var burn_timer := 0.0
var sky_layer: Node2D = null


func setup(a: Node2D, tm: int) -> void:
	arena = a
	team = tm
	var d: Dictionary = DDCard.get_card("kraken")
	cfg = d.get("boss", {})
	max_hp = float(d["hp"])
	hp = max_hp
	radius_t = float(d["radius"])
	var c: Array = cfg["center"]
	position = arena.tile_center(float(c[0]), float(c[1]))
	fwd = (arena.tile_center(float(c[0]), float(c[1]) + 1.0) - position).normalized()
	rng.seed = 20261117
	z_index = 3
	for t in cfg["arm_tiles"]:
		var arm: Node = ARM_SCRIPT.new()
		arm.name = "KrakenArm%d" % arms.size()
		arm.setup(arena, team, self, Vector2i(int(t[0]), int(t[1])))
		arms.append(arm)
	_stagger_arrows()


## The arrow timers start 2 s apart, the tentacle furthest from the player first.
func _stagger_arrows() -> void:
	var foe: Node = arena.crown_tower(1 - team)
	var from: Vector2 = foe.position if foe != null else position - fwd * 1000.0
	var order: Array = arms.duplicate()
	order.sort_custom(func(x, y):
		var dx: float = x.base.distance_to(from)
		var dy: float = y.base.distance_to(from)
		if not is_equal_approx(dx, dy):
			return dx > dy
		return arms.find(x) < arms.find(y))
	for i in order.size():
		order[i].arrow_cd = float(order[i].cfg["arrow_stagger"]) * float(i + 1)


func _ready() -> void:
	sky_layer = Node2D.new()
	sky_layer.top_level = true
	sky_layer.z_as_relative = false
	sky_layer.z_index = 12
	sky_layer.draw.connect(_draw_sky)
	add_child(sky_layer)


func is_building() -> bool:
	return true


func is_tower() -> bool:
	return true


func get_radius_t() -> float:
	return radius_t


func add_poison(_amount: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	clock += delta
	flash = maxf(0.0, flash - delta * 5.0)
	mouth_t = maxf(0.0, mouth_t - delta)
	queue_redraw()
	if sky_layer != null:
		sky_layer.queue_redraw()
	if dead or arena.match_over:
		return
	_tick_arrows(delta)
	if phase == 1:
		return
	emerge_t += delta
	_tick_burn(delta)
	if dead:
		return
	_tick_orbs(delta)
	if emerge_t < float(cfg["emerge_time"]):
		return
	orb_clock -= delta
	if orb_clock <= 0.0:
		orb_clock = float(cfg["orb_every"])
		_spew()
	burrow_clock -= delta
	if burrow_clock <= 0.0:
		burrow_clock = float(cfg["burrow_every"])
		_send_burrow()


# ------------------------------------------------------------------------ phase

func on_arm_down(_arm: Node) -> void:
	if phase != 1:
		arena.banner_flash("A tentacle sinks!")
		return
	for a in arms:
		if not a.down:
			arena.banner_flash("A tentacle sinks!")
			return
	_surface()


func _surface() -> void:
	phase = 2
	emerge_t = 0.0
	orb_clock = 0.0
	burrow_clock = float(cfg["burrow_every"])
	arena.towers.append(self)
	for a in arms:
		a.revive(float(cfg["revive_hp"]), 1.0 / maxf(0.1, float(cfg["revive_speed"])))
	_stagger_arrows()
	arena.shake(8.0)
	arena.banner_flash("The KRAKEN surfaces!")


# ----------------------------------------------------------------------- arrows

func fire_arrow(from: Vector2, dir: Vector2, amount: float, speed_t: float) -> void:
	arrows.append({"pos": from, "dir": dir.normalized(), "dmg": amount, "speed": speed_t, "t": 0.0})


## Straight and slow, never turning. The first enemy body in the way takes it:
## that is how a troop played into its path shields a tower.
func _tick_arrows(delta: float) -> void:
	if arrows.is_empty():
		return
	var tile: float = float(arena.TILE)
	var board: Rect2 = arena.board_rect().grow(tile)
	var keep: Array = []
	for ar in arrows:
		ar["t"] = float(ar["t"]) + delta
		ar["pos"] = ar["pos"] + ar["dir"] * float(ar["speed"]) * tile * delta
		var struck: Node = _body_at(ar["pos"], 0.3)
		if struck != null:
			struck.take_damage(float(ar["dmg"]), ar["pos"])
			continue
		if board.has_point(ar["pos"]) and float(ar["t"]) < 12.0:
			keep.append(ar)
	arrows = keep


## The enemy body nearest to `at` that is within pad tiles of its edge.
func _body_at(at: Vector2, pad: float) -> Node:
	var best: Node = null
	var best_d := INF
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = arena.tiles_between(at, e.position) - float(e.get_radius_t())
		if d <= pad and d < best_d:
			best = e
			best_d = d
	return best


# ------------------------------------------------------------------------- orbs

func _mouth() -> Vector2:
	return position + fwd * radius_t * 0.72 * float(arena.TILE)


func _spew() -> void:
	mouth_t = MOUTH_SHOW
	var n: int = int(cfg["orb_count"])
	for i in n:
		var spread: float = (float(i) - float(n - 1) * 0.5) * 0.6
		orbs.append({"pos": _mouth(), "dir": fwd.rotated(spread), "big": true, "t": 0.0})
	arena.banner_flash("The Kraken spews red orbs!")


func _tick_orbs(delta: float) -> void:
	if orbs.is_empty():
		return
	var tile: float = float(arena.TILE)
	var keep: Array = []
	var born: Array = []
	for o in orbs:
		var big: bool = bool(o["big"])
		o["t"] = float(o["t"]) + delta
		var target: Node = _nearest_to(o["pos"])
		if target != null:
			var want: float = (target.position - o["pos"]).angle()
			var cur: float = o["dir"].angle()
			var turn: float = float(cfg["orb_turn"] if big else cfg["small_turn"]) * delta
			o["dir"] = Vector2.from_angle(cur + clampf(angle_difference(cur, want), -turn, turn))
		# big ones leave the mouth slowly and pick up speed over the first second
		var speed: float = float(cfg["orb_speed"]) * clampf(0.35 + float(o["t"]) * 0.65, 0.0, 1.0) if big else float(cfg["small_speed"])
		o["pos"] = o["pos"] + o["dir"] * speed * tile * delta
		var life: float = float(cfg["orb_life"] if big else cfg["small_life"])
		if float(o["t"]) >= life or _body_at(o["pos"], BIG_R if big else SMALL_R) != null:
			_burst_orb(o, born)
		else:
			keep.append(o)
	orbs = keep + born


func _burst_orb(o: Dictionary, born: Array) -> void:
	var big: bool = bool(o["big"])
	var splash: float = float(cfg["orb_splash"] if big else cfg["small_splash"])
	arena.spawn_splash_ring(o["pos"], splash, team)
	arena.damage_at_point(o["pos"], splash, float(cfg["orb_dmg"] if big else cfg["small_dmg"]), team)
	if not big:
		return
	arena.shake(2.5)
	var n: int = rng.randi_range(int(cfg["orb_split_min"]), int(cfg["orb_split_max"]))
	var a0: float = rng.randf() * TAU
	for i in n:
		born.append({"pos": o["pos"], "dir": Vector2.from_angle(a0 + TAU * float(i) / float(n)), "big": false, "t": 0.0})


func _nearest_to(at: Vector2) -> Node:
	var best: Node = null
	var best_d := INF
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = at.distance_squared_to(e.position)
		if d < best_d - 0.01 or (absf(d - best_d) <= 0.01 and best != null and e.get_instance_id() < best.get_instance_id()):
			best = e
			best_d = d
	return best


# ----------------------------------------------------------------------- burrow

## One tentacle at a time, in turn, at the ground troop nearest to it that is
## not already held.
func _send_burrow() -> void:
	for i in arms.size():
		var arm: Node = arms[(next_burrow + i) % arms.size()]
		if arm.down or arm.busy():
			continue
		var victim: Node = null
		var best := INF
		for u in arena.enemy_units(team):
			if not is_instance_valid(u) or u.dead or not (u is DDUnit or u is DDShiesty):
				continue
			if u.get("flying") == true or u.is_building() or float(u.stunned) > 0.0:
				continue
			var d: float = arm.base.distance_squared_to(u.position)
			if d < best:
				best = d
				victim = u
		if victim == null:
			return
		if arm.begin_burrow(victim):
			next_burrow = (next_burrow + i + 1) % arms.size()
			return


# ----------------------------------------------------------------------- damage

func _tick_burn(delta: float) -> void:
	if burn_timer <= 0.0:
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
	if dead or phase == 1 or amount <= 0.0:
		return
	burn_stack += amount
	burn_ticks = 0
	burn_max_ticks = maxi(max_ticks, 1)
	if burn_timer <= 0.0:
		burn_timer = 1.0


func take_damage(amount: float, _from: Vector2, _attacker: Node = null) -> void:
	if dead or phase == 1 or amount <= 0.0:
		return
	hp -= arena.scale_hit(amount, team)
	flash = 0.5
	if arena.show_damage():
		arena.spawn_damage_text(position + Vector2(0.0, -radius_t * float(arena.TILE) - 8.0), amount,
			Color(1.0, 0.85, 0.5) if amount >= 20.0 else Color(0.95, 0.95, 1.0))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		arrows.clear()
		orbs.clear()
		for a in arms:
			if not a.down:
				a.sink()
		modulate = Color(1.0, 1.0, 1.0, 0.35)
		arena.on_tower_destroyed(self)


# -------------------------------------------------------------------------- art

func _draw() -> void:
	var tile: float = float(arena.TILE)
	var r: float = radius_t * tile
	var rise := 0.0
	if phase == 2:
		rise = clampf(emerge_t / float(cfg["emerge_time"]), 0.0, 1.0)
	var pose := {"rise": rise, "mouth": sin(clampf(mouth_t / MOUTH_SHOW, 0.0, 1.0) * PI)}
	# before it surfaces (rise 0) only the whirlpool is drawn
	draw_set_transform(Vector2.ZERO, fwd.angle(), Vector2.ONE)
	DDArt.kraken_head(self, r, clock, pose, arena.team_ink(int(team)), arena.team_color(int(team)))
	if flash > 0.0:
		draw_circle(Vector2.ZERO, r, Color(1.0, 1.0, 1.0, 0.3 * flash))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if dead or phase == 1:
		return
	var bw := tile * 3.2
	var by := -r * 1.4 - 16.0
	draw_rect(Rect2(-bw * 0.5, by, bw, 8.0), Color(0.08, 0.07, 0.1, 0.85), true)
	draw_rect(Rect2(-bw * 0.5 + 1.5, by + 1.5, (bw - 3.0) * clampf(hp / max_hp, 0.0, 1.0), 5.0),
		Color(0.95, 0.45, 0.45), true)
	draw_string(ThemeDB.fallback_font, Vector2(bw * 0.5 + 6.0, by + 9.0), "%d" % int(ceil(hp)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.95, 0.9))


func _draw_sky() -> void:
	var tile: float = float(arena.TILE)
	var purple := DDArt.KRAKEN_PURPLE
	for ar in arrows:
		var p: Vector2 = ar["pos"]
		var d: Vector2 = ar["dir"]
		var n := Vector2(-d.y, d.x)
		# tail, shaft, arrowhead
		sky_layer.draw_line(p - d * tile * 1.1, p - d * tile * 0.3, Color(purple.r, purple.g, purple.b, 0.3), 7.0, true)
		sky_layer.draw_line(p - d * tile * 0.6, p, purple, 4.0, true)
		sky_layer.draw_colored_polygon(PackedVector2Array([p + d * tile * 0.32, p + n * tile * 0.2 - d * tile * 0.05,
			p - n * tile * 0.2 - d * tile * 0.05]), Color(0.9, 0.6, 1.0))
	for o in orbs:
		var at: Vector2 = o["pos"]
		var rr: float = (BIG_R if bool(o["big"]) else SMALL_R) * tile * (1.0 + 0.08 * sin(clock * 14.0 + at.x))
		sky_layer.draw_circle(at, rr * 1.5, Color(1.0, 0.15, 0.1, 0.25))
		sky_layer.draw_circle(at, rr, Color(0.92, 0.12, 0.14))
		sky_layer.draw_circle(at - Vector2(rr, rr) * 0.3, rr * 0.35, Color(1.0, 0.7, 0.6, 0.9))
		sky_layer.draw_arc(at, rr, 0.0, TAU, 20, Color(0.35, 0.02, 0.05), 1.6, true)
