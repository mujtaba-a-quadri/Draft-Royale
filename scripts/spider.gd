extends Node2D

## The Momma Ballista Spider: the first elite encounter (NOTES §9).
##
## She stands in for all three enemy towers. To everything else in the game she
## *is* a tower: she sits in arena.towers, answers is_tower() / is_building(),
## carries `crown` (so killing her ends the match) and takes damage the same way.
## That is why this has no class_name and no base class in common with DDTower:
## the arena only ever duck-types its towers. It is loaded with preload() so a
## headless run does not depend on the editor having rescanned global classes.
##
## What she does, all on fixed physics ticks (her dice are a seeded RNG, so a run
## is reproducible):
##   skitter  she waits at the back a random 3-7 s, runs 3-6 tiles toward the
##            player, holds for (10 - that wait) s, lays an egg on a 2x2 patch of
##            web and runs back. She never turns.
##   spit     any distance, each a small splash of damage + poison: one at the
##            closest enemy unit as she sets off, one every 1.2 s at the closest
##            unit while she is forward, and one at the nearest tower or building
##            as she backs up. Her eye glints from the last forward spit until
##            she leaves: the warning for the building shot.
##   legs     a front-leg stab at the nearest enemy inside `reach` tiles.
##   webs     every web_every s a 2x2 patch ahead of the nearest ground troop.
##            A troop stepping on a web tile is slowed and that tile is gone.
##   traps    every trap_every s a ballista trap on one bridge, alternating. The
##            first ground troop to step on it is launched out of the arena.
##
## All numbers come from the "spider" card in card_db.gd.

enum S { HOME, ADVANCE, FORWARD, RETREAT }

const STRIKE_SHOW := 0.32
const FLING_TIME := 0.9
const STRAND_TIME := 0.3
## art scale in tiles: the legs reach about twice this from her centre
const ART_SCALE := 1.5
## the art is then stretched along the lane (WIDE) and across it (TALL); her
## hitbox is unchanged
const WIDE := 1.5
const TALL := 1.5
## where she lives in tile space: the enemy commander's spot, and the lane axis
const HOME_COL := 9.0
const HOME_ROW := 3.0

var kind := "spider"
var team := 1
var arena: Node2D = null
var crown := true
var dead := false
var hp := 900.0
var max_hp := 900.0
var radius_t := 1.5
## the hover inspector draws this as her reach ring
var reach := 4.0
var dmg := 35.0
var interval := 1.6
var cfg: Dictionary = {}

var clock := 0.0
var flash := 0.0
var home := Vector2.ZERO
var fwd := Vector2.LEFT
var state: int = S.HOME
var state_t := 0.0
var move_from := Vector2.ZERO
var move_to := Vector2.ZERO
var advance_tiles := 0
var skitter_clock := 0.0
## this cycle: how long she waits at the back, and so how long she stays forward
var back_wait := 5.0
var stay_time := 5.0
var forward_spit_cd := 0.0
## lit from her last forward spit until she starts backing up
var glint := false
var leg_cd := 0.0
var web_cd := 0.0
var trap_clock := 0.0
var next_bridge := 0
var rng := RandomNumberGenerator.new()

## Vector2i tile -> true
var webs := {}
## [{"at": Vector2, "bridge": int}]
var traps: Array = []
## cosmetics: units on their way out of the arena, silk shots, the leg stab
var flings: Array = []
var strands: Array = []
var strike_t := 0.0
var strike_side := 1.0
var strike_at := Vector2.ZERO

const BURN_RATE := 0.2
var burn_stack := 0.0
var burn_ticks := 0
var burn_max_ticks := 4
var burn_timer := 0.0

var floor_layer: Node2D = null
var sky_layer: Node2D = null


func setup(a: Node2D, tm: int) -> void:
	arena = a
	team = tm
	var d: Dictionary = DDCard.get_card("spider")
	cfg = d.get("boss", {})
	max_hp = float(d["hp"])
	hp = max_hp
	radius_t = float(d["radius"])
	reach = float(d["reach"])
	dmg = float(d["dmg"])
	interval = float(d["interval"])
	home = arena.tile_center(HOME_COL, HOME_ROW)
	position = home
	# one tile further down the lane, toward the player's board
	fwd = (arena.tile_center(HOME_COL, HOME_ROW + 1.0) - home).normalized()
	rng.seed = 20261116
	_roll_back_wait()
	web_cd = float(cfg["web_every"])
	z_index = 4


func _ready() -> void:
	# webs and traps lie on the ground under everything; launched units fly over
	# everything. Both are separate canvas items so they do not move with her.
	floor_layer = Node2D.new()
	floor_layer.top_level = true
	floor_layer.z_as_relative = false
	floor_layer.z_index = 1
	floor_layer.draw.connect(_draw_floor)
	add_child(floor_layer)
	sky_layer = Node2D.new()
	sky_layer.top_level = true
	sky_layer.z_as_relative = false
	sky_layer.z_index = 14
	sky_layer.draw.connect(_draw_sky)
	add_child(sky_layer)


func is_building() -> bool:
	return true


func is_tower() -> bool:
	return true


func get_radius_t() -> float:
	return radius_t


## Nothing poisons her; the method exists so callers need not ask.
func add_poison(_amount: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	clock += delta
	flash = maxf(0.0, flash - delta * 5.0)
	strike_t = maxf(0.0, strike_t - delta)
	for f in flings:
		f["t"] = float(f["t"]) + delta
	flings = flings.filter(func(f): return float(f["t"]) < FLING_TIME)
	for s in strands:
		s["t"] = float(s["t"]) - delta
	strands = strands.filter(func(s): return float(s["t"]) > 0.0)
	_redraw()
	if dead or arena.match_over:
		return
	if burn_timer > 0.0:
		burn_timer -= delta
		if burn_timer <= 0.0:
			var tick_dmg := floorf(burn_stack * BURN_RATE)
			burn_ticks += 1
			if tick_dmg <= 0.0 or burn_ticks >= burn_max_ticks:
				burn_stack = 0.0
				burn_ticks = 0
				burn_timer = 0.0
			else:
				burn_stack = maxf(0.0, burn_stack - tick_dmg)
				burn_timer = 1.0
				take_damage(tick_dmg, position)
				if dead:
					return
	_tick_skitter(delta)
	_tick_legs(delta)
	_tick_webs(delta)
	_tick_traps(delta)


func _redraw() -> void:
	queue_redraw()
	if floor_layer != null:
		floor_layer.queue_redraw()
	if sky_layer != null:
		sky_layer.queue_redraw()


# ---------------------------------------------------------------------- skitter

## One cycle: wait at the back for a random back_min..back_max seconds, run
## forward, hold there for (cycle - time waited at the back), run home. The
## longer she sat at the back, the shorter she stays in your face.
func _tick_skitter(delta: float) -> void:
	var run_time: float = maxf(0.1, float(cfg["skitter_time"]))
	if state == S.HOME:
		skitter_clock += delta
		if skitter_clock >= back_wait:
			_begin_skitter()
	elif state == S.ADVANCE:
		state_t += delta
		position = move_from.lerp(move_to, smoothstep(0.0, 1.0, state_t / run_time))
		if state_t >= run_time:
			position = move_to
			state = S.FORWARD
			state_t = 0.0
			stay_time = maxf(0.0, float(cfg["cycle"]) - back_wait)
			forward_spit_cd = 0.0
			glint = false
	elif state == S.FORWARD:
		state_t += delta
		# at the front she spits at the closest unit on a steady beat. The shot
		# after which there is no time for another lights her eye: that glint
		# is the warning for the one she fires at a building as she backs up.
		forward_spit_cd -= delta
		if forward_spit_cd <= 0.0 and state_t < stay_time:
			var beat: float = float(cfg["forward_spit_every"])
			forward_spit_cd = beat
			_spit_at(_nearest_enemy(INF))
			if state_t + beat >= stay_time:
				glint = true
		if state_t >= stay_time:
			glint = false
			_lay_egg()
			# the parting shot goes at a tower or building, wherever it is
			_spit_at(_nearest_structure())
			move_from = position
			move_to = home
			state = S.RETREAT
			state_t = 0.0
	else:
		# backing up: she keeps facing the player's board the whole way
		state_t += delta
		position = move_from.lerp(move_to, smoothstep(0.0, 1.0, state_t / run_time))
		if state_t >= run_time:
			position = home
			state = S.HOME
			state_t = 0.0
			_roll_back_wait()


func _roll_back_wait() -> void:
	skitter_clock = 0.0
	back_wait = rng.randf_range(float(cfg["back_min"]), float(cfg["back_max"]))


func _begin_skitter() -> void:
	advance_tiles = rng.randi_range(int(cfg["skitter_min"]), int(cfg["skitter_max"]))
	move_from = position
	move_to = home + fwd * float(advance_tiles) * float(arena.TILE)
	state = S.ADVANCE
	state_t = 0.0
	# setting off: a spit at the closest enemy unit, however far away it is
	_spit_at(_nearest_enemy(INF))


## The egg is an ordinary 2x2 building (card "spideregg") dropped where she is
## standing; the four tiles it sits on become web.
func _lay_egg() -> void:
	# aim at the tile whose corner she is standing on, so the egg is under her
	var at: Vector2 = arena.tile_center(HOME_COL + 0.5, HOME_ROW + float(advance_tiles) + 0.5)
	var egg = arena.spawn_troop("spideregg", team, at)
	if egg == null or not is_instance_valid(egg):
		return
	egg.deploy_timer = 0.0
	for t in egg.occupied_tiles:
		webs[t] = true


# ---------------------------------------------------------------------- attacks

## Nearest enemy unit within range_t tiles of her centre (edge of the unit).
func _nearest_enemy(range_t: float, ground_troops_only: bool = false) -> Node:
	var best: Node = null
	var best_d := INF
	for u in arena.enemy_units(team):
		if not is_instance_valid(u) or u.dead:
			continue
		if ground_troops_only and (u.get("flying") == true or u.is_building() or not u.has_method("slow")):
			continue
		var d: float = arena.tiles_between(position, u.position) - float(u.get_radius_t())
		if d > range_t:
			continue
		if d < best_d - 0.0001:
			best = u
			best_d = d
		elif absf(d - best_d) <= 0.0001 and best != null and u.get_instance_id() < best.get_instance_id():
			best = u
	return best


## Nearest enemy tower or building, anywhere on the board.
func _nearest_structure() -> Node:
	var best: Node = null
	var best_d := INF
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead or not e.is_building():
			continue
		var d: float = arena.tiles_between(position, e.position)
		if d < best_d - 0.0001:
			best = e
			best_d = d
		elif absf(d - best_d) <= 0.0001 and best != null and e.get_instance_id() < best.get_instance_id():
			best = e
	return best


## One glob of venom. It follows its target and bursts where it lands: damage
## and poison to everything of the other side inside spit_splash tiles.
func _spit_at(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var mouth: Vector2 = position + fwd * ART_SCALE * WIDE * 0.9 * float(arena.TILE)
	arena.spawn_projectile(mouth, target.position, team, float(cfg["spit_dmg"]), float(cfg["spit_splash"]),
		"venom", 0, "bolt", false, self, float(cfg["spit_speed"]), null,
		{"poison": float(cfg["spit_poison"]), "seek": target})


func _tick_legs(delta: float) -> void:
	leg_cd = maxf(0.0, leg_cd - delta)
	if leg_cd > 0.0:
		return
	var target: Node = _nearest_enemy(reach)
	if target == null:
		return
	leg_cd = interval
	strike_t = STRIKE_SHOW
	strike_at = target.position
	# stab with the leg on the target's side
	strike_side = 1.0 if fwd.cross(target.position - position) >= 0.0 else -1.0
	target.take_damage(dmg, position, self)
	arena.shake(1.6)


# ------------------------------------------------------------------------- webs

func _tick_webs(delta: float) -> void:
	web_cd -= delta
	if web_cd <= 0.0:
		web_cd = float(cfg["web_every"])
		var walker: Node = _nearest_enemy(999.0, true)
		if walker != null:
			lay_web_ahead_of(walker)
	if webs.is_empty():
		return
	for u in arena.enemy_units(team):
		if not is_instance_valid(u) or u.dead:
			continue
		if u.get("flying") == true or u.is_building() or not u.has_method("slow"):
			continue
		var t: Vector2i = arena.tile_of(u.position)
		if webs.has(t):
			# the web does its job once: it slows the troop and tears
			webs.erase(t)
			u.slow(float(cfg["web_slow"]), float(cfg["web_slow_time"]))


## A 2x2 patch on the troop's path: web_ahead tiles along the way it is walking.
func lay_web_ahead_of(walker: Node) -> void:
	var goal: Vector2 = position
	var tg = walker.get("target")
	if tg != null and is_instance_valid(tg):
		goal = tg.position
	var dir: Vector2 = arena.route_point(walker.position, goal) - walker.position
	if dir.length() < 1.0:
		dir = position - walker.position
	if dir.length() < 1.0:
		return
	var at: Vector2 = walker.position + dir.normalized() * float(cfg["web_ahead"]) * float(arena.TILE)
	var t: Vector2i = arena.tile_of(at)
	var laid := false
	for dy in [-1, 0]:
		for dx in [-1, 0]:
			var nt := Vector2i(t.x + dx, t.y + dy)
			if not arena.valid_tile(nt) or webs.has(nt):
				continue
			webs[nt] = true
			laid = true
	if laid:
		strands.append({"to": arena.tile_center(float(t.x), float(t.y)), "t": STRAND_TIME})


# ------------------------------------------------------------------------ traps

func bridge_point(bridge: int) -> Vector2:
	var col: float = float(arena.BRIDGE_COL_A) if bridge == 0 else float(arena.BRIDGE_COL_B)
	return arena.tile_center(col + 0.5, float(arena.RIVER_TOP) + 0.5).lerp(
		arena.tile_center(col + 0.5, float(arena.RIVER_BOTTOM) + 0.5), 0.5)


func _tick_traps(delta: float) -> void:
	trap_clock += delta
	if trap_clock >= float(cfg["trap_every"]):
		trap_clock = 0.0
		lay_trap()
	if traps.is_empty():
		return
	var trigger: float = float(cfg["trap_radius"])
	for trap in traps.duplicate():
		for u in arena.enemy_units(team):
			if not is_instance_valid(u) or u.dead:
				continue
			if u.get("flying") == true or u.is_building():
				continue
			if arena.tiles_between(trap["at"], u.position) <= trigger:
				traps.erase(trap)
				_launch(u)
				break


## One bridge at a time, alternating. A bridge that is still armed is left alone.
func lay_trap() -> void:
	var bridge := next_bridge
	next_bridge = 1 - next_bridge
	for trap in traps:
		if int(trap["bridge"]) == bridge:
			return
	traps.append({"at": bridge_point(bridge), "bridge": bridge})
	strands.append({"to": bridge_point(bridge), "t": STRAND_TIME})


## The ballista goes off: the unit leaves the arena. It is removed, not killed,
## so nothing that happens on death (blasts, boulders, risen zombies) fires.
func _launch(u: Node) -> void:
	var k = u.get("kind")
	flings.append({"kind": String(k) if k != null else "", "at": u.position, "t": 0.0})
	arena.banner_flash("The bridge snaps: %s is launched out of the arena!" % (
		DDCard.pretty(String(k)) if k != null else "a unit"))
	arena.shake(3.0)
	if u is DDUnit:
		u.dead = true
		arena.unregister(u)
		u.queue_free()
	elif u.has_method("take_damage"):
		u.take_damage(99999.0, u.position)


# ----------------------------------------------------------------------- damage

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
	hp -= amount
	flash = 0.5
	if arena.show_damage():
		arena.spawn_damage_text(position + Vector2(0.0, -radius_t * float(arena.TILE) - 8.0), amount,
			Color(1.0, 0.85, 0.5) if amount >= 20.0 else Color(0.95, 0.95, 1.0))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		# her works go with her
		webs.clear()
		traps.clear()
		modulate = Color(1.0, 1.0, 1.0, 0.35)
		arena.on_tower_destroyed(self)
	_redraw()


# -------------------------------------------------------------------------- art

func _draw() -> void:
	var tile: float = float(arena.TILE)
	var r: float = ART_SCALE * tile
	draw_circle(Vector2.ZERO, r * 1.5, Color(0.0, 0.0, 0.0, 0.14))
	var pose := {"move": 1.0 if (state == S.ADVANCE or state == S.RETREAT) else 0.12}
	if strike_t > 0.0:
		var local: Vector2 = (strike_at - position).rotated(-fwd.angle())
		pose["strike"] = 1.0 - strike_t / STRIKE_SHOW
		pose["side"] = strike_side
		pose["reach"] = clampf(local.length() / r, 1.2, 5.4)
		pose["aim"] = local.angle()
	# she is drawn facing +x, so the art's y axis is her width across the lane:
	# stretching it is what makes her taller on screen
	draw_set_transform(Vector2.ZERO, fwd.angle(), Vector2(WIDE, TALL))
	if pose.has("aim"):
		# keep the stab pointing at its target through the stretch
		var aimed := Vector2.from_angle(float(pose["aim"])) * float(pose["reach"])
		aimed.x /= WIDE
		aimed.y /= TALL
		pose["aim"] = aimed.angle()
		pose["reach"] = aimed.length()
	DDArt.spider_boss(self, r, clock, pose, arena.team_ink(int(team)))
	if glint:
		# the warning: a four point star flaring on one eye (the eye sits at
		# (0.6, 0.1) r in the art)
		var eye := Vector2(r * 0.6, r * 0.1)
		var arm: float = r * (0.16 + 0.07 * sin(clock * 18.0))
		var spark := Color(1.0, 1.0, 1.0, 0.95)
		draw_line(eye - Vector2(arm, 0.0), eye + Vector2(arm, 0.0), spark, 2.0, true)
		draw_line(eye - Vector2(0.0, arm), eye + Vector2(0.0, arm), spark, 2.0, true)
		draw_line(eye - Vector2(arm, arm) * 0.4, eye + Vector2(arm, arm) * 0.4, spark, 1.2, true)
		draw_line(eye - Vector2(arm, -arm) * 0.4, eye + Vector2(arm, -arm) * 0.4, spark, 1.2, true)
	if flash > 0.0:
		draw_circle(Vector2(-r * 0.4, 0.0), r * 1.2, Color(1.0, 1.0, 1.0, 0.35 * flash))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if dead:
		return
	var bw := tile * 3.2
	var by := -r * 1.45 * TALL - 16.0
	draw_rect(Rect2(-bw * 0.5, by, bw, 8.0), Color(0.08, 0.07, 0.1, 0.85), true)
	draw_rect(Rect2(-bw * 0.5 + 1.5, by + 1.5, (bw - 3.0) * clampf(hp / max_hp, 0.0, 1.0), 5.0),
		Color(0.95, 0.45, 0.45), true)
	draw_string(ThemeDB.fallback_font, Vector2(bw * 0.5 + 6.0, by + 9.0), "%d" % int(ceil(hp)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.95, 0.9))


func _draw_floor() -> void:
	for t in webs:
		DDArt.web_tile(floor_layer, arena.tile_rect(t.x, t.y))
	for trap in traps:
		DDArt.ballista_trap(floor_layer, trap["at"], float(arena.TILE), clock)
	# a line of silk from her spinneret to whatever she just laid
	for s in strands:
		var a: float = clampf(float(s["t"]) / STRAND_TIME, 0.0, 1.0)
		floor_layer.draw_line(position - fwd * ART_SCALE * WIDE * 1.6 * float(arena.TILE), s["to"],
			Color(1.0, 1.0, 1.0, 0.7 * a), 2.0, true)


## Launched units: straight up toward the camera, so they swell, drift and pop.
func _draw_sky() -> void:
	var r: float = 0.42 * float(arena.TILE)
	for f in flings:
		var p: float = clampf(float(f["t"]) / FLING_TIME, 0.0, 1.0)
		var at: Vector2 = f["at"] + Vector2(sin(p * 9.0) * 6.0, -p * 150.0)
		if String(f["kind"]) != "":
			DDArt.icon(sky_layer, String(f["kind"]), at, r * (1.0 + 1.6 * p), clock)
		sky_layer.draw_arc(f["at"], r * (1.0 + 3.0 * p), 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.7 * (1.0 - p)), 2.0, true)
