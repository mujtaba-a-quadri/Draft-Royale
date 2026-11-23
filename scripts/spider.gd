extends Node2D

## The Ballista Matriarch (the ballista spider): the first elite encounter (NOTES §9).
##
## She stands in for all three enemy towers. To everything else in the game she
## *is* a tower: she sits in arena.towers, answers is_tower() / is_building(),
## carries `crown` (so killing her ends the match) and takes damage the same way.
## That is why this has no class_name and no base class in common with DDTower:
## the arena only ever duck-types its towers. It is loaded with preload() so a
## headless run does not depend on the editor having rescanned global classes.
##
## What she does, all on fixed physics ticks (her dice are a seeded RNG, so a run
## is reproducible). One cycle, and she never turns round:
##   skitter  she waits at the back a random 3-7 s and runs 3-6 tiles toward the
##            player.
##   seep     forward, poison seeps from her mouth: a pool in front of her face
##            that runs on down the "hill" as a braided stream into the river,
##            and the river turns poison from the inflow downstream. Enemy
##            ground troops in the pool or stream are poisoned.
##   spit     only once the pool has formed: every forward_spit_every s at the
##            closest enemy unit, a splash of damage + poison, until she has
##            been forward (10 - that wait) s.
##   egg      she lays an egg on a 2x2 patch of web and stops seeping: the pool
##            dries from her mouth down, then the river clears from the top.
##   trap     she walks to a bridge with no trap and builds one with her front
##            legs (3 s): a slingshot cone of silk. The first ground troop to
##            step on it is launched out of the arena. No free bridge, no trap.
##   parting  her eye glints, she spits at the nearest tower or building, and
##            walks home.
## And all the while: a front-leg stab at the nearest enemy inside `reach`
## tiles, and every web_every s a 2x2 web ahead of the nearest ground troop (a
## troop stepping on a web tile is slowed and that tile is gone).
##
## All numbers come from the "spider" card in card_db.gd.

enum S { HOME, ADVANCE, FORWARD, TO_BRIDGE, BUILD, GLINT, RETREAT }

## the green of her abdomen, for the poison
const POISON := Color(0.8, 0.8, 0.32)
const POISON_DARK := Color(0.62, 0.66, 0.22)

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
var next_bridge := 0
## the trap she is walking to / building (one of `traps`), empty for none
var build_trap: Dictionary = {}
var build_poke := 0.0

## the poison: a path from where her mouth was (`ooze_from`) straight down the
## lane to the river's near bank, `ooze_len` tiles long. The stretch from
## `ooze_dry` to `ooze_wet` tiles along it is wet. The river is poison from
## column `river_a` to `river_b` (tile columns, fractional; it flows toward
## higher columns, down the screen).
var ooze_on := false
var ooze_from := Vector2.ZERO
var ooze_len := 0.0
var ooze_wet := 0.0
var ooze_dry := 0.0
var river_in := 0.0
var river_a := 0.0
var river_b := 0.0
var river_wet := false
var pool_cd := 0.0
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
			if tick_dmg <= 0.0:
				burn_stack = 0.0
				burn_ticks = 0
				burn_timer = 0.0
			else:
				burn_stack = maxf(0.0, burn_stack - tick_dmg)
				burn_timer = 1.0
				arena.tick_damage(self, tick_dmg)
				if dead:
					return
				# the last tick still lands, as on a troop; then the fire is out
				if burn_ticks >= burn_max_ticks:
					burn_stack = 0.0
					burn_ticks = 0
					burn_timer = 0.0
	_tick_skitter(delta)
	_tick_ooze(delta)
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
## forward, seep and (once the pool is there) spit for (cycle - time waited at
## the back) s, lay an egg, build a trap on a free bridge, glint, take the
## parting shot, walk home. The longer she sat at the back, the shorter she
## stays in your face.
func _tick_skitter(delta: float) -> void:
	var run_time: float = maxf(0.1, float(cfg["skitter_time"]))
	state_t += delta
	match state:
		S.HOME:
			skitter_clock += delta
			if skitter_clock >= back_wait:
				_begin_skitter()
		S.ADVANCE:
			position = move_from.lerp(move_to, smoothstep(0.0, 1.0, state_t / run_time))
			if state_t >= run_time:
				position = move_to
				_set_state(S.FORWARD)
				stay_time = maxf(0.0, float(cfg["cycle"]) - back_wait)
				forward_spit_cd = 0.0
				_start_ooze()
		S.FORWARD:
			# no shooting until the pool in front of her has formed
			if ooze_wet >= float(cfg["pool_len"]):
				forward_spit_cd -= delta
				if forward_spit_cd <= 0.0 and state_t < stay_time:
					forward_spit_cd = float(cfg["forward_spit_every"])
					_spit_at(_nearest_enemy(INF))
			if state_t >= stay_time:
				_lay_egg()
				ooze_on = false
				_head_for_bridge()
		S.TO_BRIDGE:
			if _walk_to(move_to, delta):
				_set_state(S.BUILD)
		S.BUILD:
			var trap: Dictionary = build_trap
			trap["build"] = minf(1.0, state_t / maxf(0.1, float(cfg["build_time"])))
			# the front legs work the silk, left and right in turn
			build_poke -= delta
			if build_poke <= 0.0:
				build_poke = STRIKE_SHOW
				strike_t = STRIKE_SHOW
				strike_at = trap["at"]
				strike_side = -strike_side
			if float(trap["build"]) >= 1.0:
				build_trap = {}
				glint = true
				_set_state(S.GLINT)
		S.GLINT:
			if state_t >= float(cfg["glint_time"]):
				glint = false
				# the parting shot goes at a tower or building, wherever it is
				_spit_at(_nearest_structure())
				move_to = home
				_set_state(S.RETREAT)
		S.RETREAT:
			# walking home: she keeps facing the player's board the whole way
			if _walk_to(home, delta):
				_set_state(S.HOME)
				_roll_back_wait()


func _set_state(s: int) -> void:
	state = s
	state_t = 0.0


## A step toward `to` at walk_speed tiles a second; true once she is there.
func _walk_to(to: Vector2, delta: float) -> bool:
	var step: float = float(cfg["walk_speed"]) * float(arena.TILE) * delta
	var d: Vector2 = to - position
	if d.length() <= step:
		position = to
		return true
	position += d.normalized() * step
	return false


## Off to a bridge with no trap on it (the nearer one; both free and level,
## alternating). Neither free: straight to the glint and the parting shot.
func _head_for_bridge() -> void:
	var free: Array = []
	for b in [0, 1]:
		var taken := false
		for trap in traps:
			if int(trap["bridge"]) == b:
				taken = true
		if not taken:
			free.append(b)
	if free.is_empty():
		glint = true
		_set_state(S.GLINT)
		return
	var pick: int = int(free[0])
	if free.size() == 2:
		var d0: float = position.distance_to(bridge_point(0))
		var d1: float = position.distance_to(bridge_point(1))
		if absf(d0 - d1) < 1.0:
			pick = next_bridge
		else:
			pick = 0 if d0 < d1 else 1
	next_bridge = 1 - pick
	build_trap = {"at": bridge_point(pick), "bridge": pick, "build": 0.0}
	traps.append(build_trap)
	build_poke = 0.0
	# she stands on her own bank, far enough back that her front legs reach
	# the middle of the bridge
	move_to = bridge_point(pick) - fwd * (1.0 + float(cfg.get("build_back", 2.4))) * float(arena.TILE)
	_set_state(S.TO_BRIDGE)


func _roll_back_wait() -> void:
	skitter_clock = 0.0
	back_wait = rng.randf_range(float(cfg["back_min"]), float(cfg["back_max"]))


func _begin_skitter() -> void:
	advance_tiles = rng.randi_range(int(cfg["skitter_min"]), int(cfg["skitter_max"]))
	move_from = position
	move_to = home + fwd * float(advance_tiles) * float(arena.TILE)
	_set_state(S.ADVANCE)


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


# ----------------------------------------------------------------------- poison

## She has just arrived forward: poison starts at her mouth and runs down the
## lane to the river's near bank.
func _start_ooze() -> void:
	ooze_from = position + fwd * ART_SCALE * WIDE * 0.9 * float(arena.TILE)
	var bank: Vector2 = arena.tile_center(HOME_COL, float(arena.RIVER_TOP))
	ooze_len = maxf(0.5, (bank - ooze_from).dot(fwd) / float(arena.TILE))
	ooze_wet = 0.0
	ooze_dry = 0.0
	ooze_on = true
	river_in = HOME_COL
	river_wet = false
	pool_cd = float(cfg["pool_every"])


func _tick_ooze(delta: float) -> void:
	if ooze_len <= 0.0:
		return
	var seep: float = float(cfg["seep_speed"])
	if ooze_on:
		ooze_wet = minf(ooze_len, ooze_wet + seep * delta)
	else:
		ooze_dry = minf(ooze_wet, ooze_dry + seep * delta)
	var flow: float = float(cfg["river_speed"]) * delta
	var stream_in: bool = ooze_wet >= ooze_len - 0.001 and ooze_dry < ooze_len - 0.001
	if stream_in:
		# it has reached the river: the poison runs downstream from the inflow
		if not river_wet:
			river_wet = true
			river_a = river_in
			river_b = river_in
		river_b = minf(_river_end(), river_b + flow)
	elif not ooze_on and river_wet:
		# the stream has dried: the river clears from the top down
		river_a = minf(river_b, river_a + flow)
		if river_a >= river_b - 0.001:
			river_wet = false
	if not ooze_on and ooze_dry >= ooze_wet - 0.001 and not river_wet:
		ooze_len = 0.0
		return
	# whatever stands in the pool or the stream soaks some up
	pool_cd -= delta
	if pool_cd <= 0.0:
		pool_cd += float(cfg["pool_every"])
		for u in arena.enemy_units(team):
			if not is_instance_valid(u) or u.dead or u.get("flying") == true or u.is_building():
				continue
			if in_ooze(u.position, float(u.get_radius_t())) and u.has_method("add_poison"):
				u.add_poison(float(cfg["pool_poison"]))


## The far end of the river, in tile columns: the bottom edge of the board.
func _river_end() -> float:
	return float(arena.col_max(arena.RIVER_TOP) + 1)


## Half-width in tiles of the pool `s` tiles from her mouth (pool part only).
func _pool_half(s: float) -> float:
	var pl: float = float(cfg["pool_len"])
	return float(cfg["pool_wide"]) * (0.55 + 0.45 * sin(PI * clampf(s / pl, 0.0, 1.0)))


## How far either branch of the stream sits from the middle `s` tiles down: they
## split below the pool and come together again at the river.
func _branch_off(s: float) -> float:
	var pl: float = float(cfg["pool_len"])
	var k: float = clampf((s - pl) / maxf(0.1, ooze_len - pl), 0.0, 1.0)
	return 0.32 * sin(PI * k) + 0.05 * sin(s * 7.0)


## Is a body at `at` (radius r tiles) standing in the wet part of the pool or
## the stream?
func in_ooze(at: Vector2, r: float) -> bool:
	if ooze_len <= 0.0 or ooze_wet <= ooze_dry:
		return false
	var rel: Vector2 = (at - ooze_from) / float(arena.TILE)
	var s: float = rel.dot(fwd)
	if s < ooze_dry - r or s > ooze_wet + r:
		return false
	var lat: float = absf(rel.dot(fwd.orthogonal()))
	if s < float(cfg["pool_len"]):
		return lat <= _pool_half(s) + r
	return lat <= _branch_off(s) + float(cfg["stream_wide"]) + r


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
			# never on water, which includes the bridge decks' outer half tiles
			if not arena.valid_tile(nt) or webs.has(nt) or arena.is_water(nt):
				continue
			webs[nt] = true
			laid = true
	if laid:
		strands.append({"to": arena.tile_center(float(t.x), float(t.y)), "t": STRAND_TIME})


# ------------------------------------------------------------------------ traps

func bridge_point(bridge: int) -> Vector2:
	# the outer two bridges (a plain match's middle one is never trapped)
	var col: float = float(arena.bridges[0][0]) if bridge == 0 else float(arena.bridges[arena.bridges.size() - 1][0])
	return arena.tile_center(col + 0.5, float(arena.RIVER_TOP) + 0.5).lerp(
		arena.tile_center(col + 0.5, float(arena.RIVER_BOTTOM) + 0.5), 0.5)


func _tick_traps(_delta: float) -> void:
	if traps.is_empty():
		return
	var trigger: float = float(cfg["trap_radius"])
	for trap in traps.duplicate():
		if float(trap.get("build", 1.0)) < 1.0:
			# still being spun: nothing to spring yet
			continue
		for u in arena.enemy_units(team):
			if not is_instance_valid(u) or u.dead:
				continue
			if u.get("flying") == true or u.is_building():
				continue
			if arena.tiles_between(trap["at"], u.position) <= trigger:
				traps.erase(trap)
				_launch(u)
				break


## Dev only (--scenario=spider): an armed trap on the next bridge at once. In
## play she builds them herself (_head_for_bridge / S.BUILD).
func lay_trap() -> void:
	var bridge := next_bridge
	next_bridge = 1 - next_bridge
	for trap in traps:
		if int(trap["bridge"]) == bridge:
			return
	traps.append({"at": bridge_point(bridge), "bridge": bridge, "build": 1.0})
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
	hp -= arena.scale_hit(amount, team)
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
		build_trap = {}
		ooze_len = 0.0
		river_wet = false
		modulate = Color(1.0, 1.0, 1.0, 0.35)
		arena.on_tower_destroyed(self)
	_redraw()


# -------------------------------------------------------------------------- art

func _draw() -> void:
	var tile: float = float(arena.TILE)
	var r: float = ART_SCALE * tile
	draw_circle(Vector2.ZERO, r * 1.5, Color(0.0, 0.0, 0.0, 0.14))
	var walking: bool = state == S.ADVANCE or state == S.RETREAT or state == S.TO_BRIDGE
	var pose := {"move": 1.0 if walking else 0.12}
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
	_draw_river()
	_draw_ooze()
	for t in webs:
		DDArt.web_tile(floor_layer, arena.tile_rect(t.x, t.y))
	for trap in traps:
		DDArt.slingshot_trap(floor_layer, trap["at"], float(arena.TILE), clock, float(trap.get("build", 1.0)))
	# a line of silk from her spinneret to whatever she just laid
	for s in strands:
		var a: float = clampf(float(s["t"]) / STRAND_TIME, 0.0, 1.0)
		floor_layer.draw_line(position - fwd * ART_SCALE * WIDE * 1.6 * float(arena.TILE), s["to"],
			Color(1.0, 1.0, 1.0, 0.7 * a), 2.0, true)


## The pool and the stream: blobs of her green laid along the path, a darker
## rim under a lighter body, a sheen that drifts downhill.
func _draw_ooze() -> void:
	if ooze_len <= 0.0 or ooze_wet <= ooze_dry:
		return
	var tile: float = float(arena.TILE)
	var side: Vector2 = fwd.orthogonal()
	var pl: float = float(cfg["pool_len"])
	var sw: float = float(cfg["stream_wide"])
	var blobs: Array = []
	var s := ooze_dry
	while s <= ooze_wet:
		var at: Vector2 = ooze_from + fwd * s * tile
		if s < pl:
			blobs.append([at, _pool_half(s) * tile])
		else:
			var off: float = _branch_off(s) * tile
			blobs.append([at + side * off, sw * tile])
			blobs.append([at - side * off, sw * tile])
		s += 0.08
	for b in blobs:
		floor_layer.draw_circle(b[0], float(b[1]) + 2.5, POISON_DARK)
	for b in blobs:
		floor_layer.draw_circle(b[0], float(b[1]), POISON)
	# sheen running downhill
	for k in 6:
		var sk: float = fmod(clock * 1.6 + float(k) * 0.7, maxf(0.5, ooze_wet - ooze_dry)) + ooze_dry
		var lat: float = sin(float(k) * 2.3) * (float(cfg["pool_wide"]) * 0.45 if sk < pl else 0.0)
		var p: Vector2 = ooze_from + fwd * sk * tile + side * lat * tile
		if sk >= pl:
			p += side * _branch_off(sk) * tile * (1.0 if k % 2 == 0 else -1.0)
		floor_layer.draw_circle(p, tile * 0.07, Color(1.0, 1.0, 0.85, 0.55))
	if ooze_on and ooze_dry <= 0.0:
		# still welling up at her mouth
		var bub: float = 0.5 + 0.5 * sin(clock * 7.0)
		floor_layer.draw_circle(ooze_from, tile * (0.2 + 0.08 * bub), POISON.lightened(0.15))


## The poisoned river: from river_a down to river_b, both lanes of water, but
## not the bridges.
func _draw_river() -> void:
	if not river_wet or river_b <= river_a:
		return
	var tile: float = float(arena.TILE)
	var gaps: Array = []
	for b in arena.bridges:
		gaps.append([float(b[0]) - float(b[1]), float(b[0]) + float(b[1])])
	# split the wet span around the bridges
	var spans: Array = [[river_a, river_b]]
	for g in gaps:
		var next: Array = []
		for sp in spans:
			var a: float = sp[0]
			var b: float = sp[1]
			if b <= float(g[0]) or a >= float(g[1]):
				next.append(sp)
				continue
			if a < float(g[0]):
				next.append([a, float(g[0])])
			if b > float(g[1]):
				next.append([float(g[1]), b])
		spans = next
	for row in range(arena.RIVER_TOP, arena.RIVER_BOTTOM + 1):
		var base: Rect2 = arena.tile_rect(0, row)
		for sp in spans:
			var a2: float = sp[0]
			var b2: float = sp[1]
			var rect: Rect2
			if arena.LANDSCAPE:
				rect = Rect2(base.position.x, base.position.y + a2 * tile, tile, (b2 - a2) * tile)
			else:
				rect = Rect2(base.position.x + a2 * tile, base.position.y, (b2 - a2) * tile, tile)
			floor_layer.draw_rect(rect, Color(POISON.r, POISON.g, POISON.b, 0.96), true)
	# ripples carried downstream, and a frothy leading edge
	for sp in spans:
		var a3: float = sp[0]
		var b3: float = sp[1]
		var c := a3 + fmod(clock * 2.0, 1.0)
		while c < b3:
			for row2 in range(arena.RIVER_TOP, arena.RIVER_BOTTOM + 1):
				var r2: Rect2 = arena.tile_rect(0, row2)
				var p0: Vector2
				var p1: Vector2
				if arena.LANDSCAPE:
					p0 = Vector2(r2.position.x + tile * 0.2, r2.position.y + c * tile)
					p1 = p0 + Vector2(tile * 0.6, 0.0)
				else:
					p0 = Vector2(r2.position.x + c * tile, r2.position.y + tile * 0.2)
					p1 = p0 + Vector2(0.0, tile * 0.6)
				floor_layer.draw_line(p0, p1, Color(1.0, 1.0, 0.8, 0.35), 2.0, true)
			c += 1.0
	if river_b < _river_end() - 0.01:
		for row3 in range(arena.RIVER_TOP, arena.RIVER_BOTTOM + 1):
			var r3: Rect2 = arena.tile_rect(0, row3)
			var front: Vector2 = Vector2(r3.get_center().x, r3.position.y + river_b * tile) if arena.LANDSCAPE \
				else Vector2(r3.position.x + river_b * tile, r3.get_center().y)
			floor_layer.draw_circle(front, tile * 0.3, Color(POISON_DARK.r, POISON_DARK.g, POISON_DARK.b, 0.7))


## Launched units: straight up toward the camera, so they swell, drift and pop.
func _draw_sky() -> void:
	var r: float = 0.42 * float(arena.TILE)
	for f in flings:
		var p: float = clampf(float(f["t"]) / FLING_TIME, 0.0, 1.0)
		var at: Vector2 = f["at"] + Vector2(sin(p * 9.0) * 6.0, -p * 150.0)
		if String(f["kind"]) != "":
			DDArt.icon(sky_layer, String(f["kind"]), at, r * (1.0 + 1.6 * p), clock)
		sky_layer.draw_arc(f["at"], r * (1.0 + 3.0 * p), 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.7 * (1.0 - p)), 2.0, true)
