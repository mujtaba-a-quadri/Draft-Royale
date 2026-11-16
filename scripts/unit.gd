class_name DDUnit
extends Node2D

## Troop primitive: a small state machine plus the shared combat systems.
##
##   states    IDLE / APPROACH / ATTACK / STUNNED / SLIDING
##   impulse   apply_impulse(dir, tiles, seconds) slides the unit and cancels its swing
##   cooldown  interval + cooldown_per_tile * distance (per card)
##   roll      per-card charge: walk uninterrupted, gain levels, spend on the next hit
##   projectile lifecycle hooks live in DDProjectile; units expose catch_projectile()

enum S { IDLE, APPROACH, ATTACK, STUNNED, SLIDING }

const DEPLOY_DELAY := 0.5
const FALL_TIME := 0.26
const SQUASH_TIME := 0.16
const ATTACK_STRETCH := 0.14

var kind: String = "slate"
var team: int = 0
var arena: Node2D = null

var max_hp := 1.0
var hp := 1.0
var radius_t := 0.5
var speed := 1.0
var reach := 0.35
var interval := 1.0
var dmg := 0.0
var splash := 0.0
var aggro := 5.0
var stationary := false
var lifetime := 0.0
var buildings_only := false
var cooldown_per_tile := 0.0
var hits_air := false
var bird_lead := false

var age := 0.0
var atk_cd := 0.0
var target: Node = null
var facing := 1.0
var flash := 0.0
var clock := 0.0
var dead := false
var phase2 := false
var last_from := Vector2.INF
var last_attacker: Node = null
var incoming := 0.0

var state: int = S.IDLE
var ground_speed := 0.0
var ground_reach := 0.0

var flying := false
var stunned := 0.0

var knock_vel := Vector2.ZERO
var knock_time := 0.0

var curl_cfg: Dictionary = {}
var curled := false
## Hot Chicken: pecks fireballs, then takes to the air and rams.
var chicken_cfg: Dictionary = {}
var chicken_hits := 0
var chicken_target := 0
var airborne := false
var burn_per_hit := 0.0
## Second phase of a chicken: fly at the target and burst on contact.
var kamikaze_cfg: Dictionary = {}
## Primal Aphid: a cone of pellets instead of a single shot.
var spread_cfg: Dictionary = {}
var targets_weakest := false
var presence_shift := 0
var summon_cfg: Dictionary = {}
var shoots := ""
var shoot_payload: Dictionary = {}
## Some units only ever pick fights with troops (Penny ignores buildings/towers).
var troops_only := false
## Penny: three swipes, then an invincible fading step-back and a quarter circle.
var dodge_cfg: Dictionary = {}
var swipes := 0
var dodging := false
var dodge_t := 0.0
var dodge_sign := 1.0
var dodge_picked := false
var dodge_center := Vector2.ZERO
var dodge_radius := 0.0
var dodge_start_r := 0.0
var dodge_angle0 := 0.0
var invincible := false
## Untargetable: the arena's enemy queries skip these (Penny mid-dodge).
var untargetable := false
var is_b := false
var occupied_tiles: Array = []
var footprint: Array = [1, 1]
var summon_cd := 0.0
enum Status { NONE, SLOW, BURN }
var status: int = Status.NONE
var slow_amount := 0.0
var slow_time := 0.0
const BURN_RATE := 0.4
var burn_stack := 0.0
var burn_ticks := 0
var burn_max_ticks := 4
var burn_timer := 0.0
var burn_pulse := 0.0
var boom_cfg: Dictionary = {}
var throw_cd := 0.0
var throw_dist := 0.0
var combo_hits := 0

var roll_cfg: Dictionary = {}
var roll_level := 0
var roll_timer := 0.0
var trail_t := 0.0
var moved_this_frame := false
var has_projectile := false
var deploy_timer := 0.0
var hurt_frames := 0
var attack_stretch := 0.0
var attack_dir := Vector2.RIGHT


func setup(k: String, tm: int, ar: Node2D) -> void:
	kind = k
	team = tm
	arena = ar
	var d: Dictionary = DDCard.get_card(k)
	max_hp = float(d["hp"])
	hp = max_hp
	radius_t = float(d["radius"])
	speed = float(d["speed"])
	reach = float(d["reach"])
	interval = float(d["interval"])
	dmg = float(d["dmg"])
	splash = float(d["splash"])
	aggro = float(d["aggro"])
	stationary = bool(d["stationary"])
	lifetime = float(d["lifetime"])
	buildings_only = bool(d.get("buildings_only", false))
	cooldown_per_tile = float(d.get("cooldown_per_tile", 0.0))
	hits_air = bool(d.get("hits_air", false))
	if bool(d.get("flying_unit", false)):
		flying = true
	roll_cfg = d.get("roll", {})
	boom_cfg = d.get("boomerang", {})
	curl_cfg = d.get("curl", {})
	chicken_cfg = d.get("chicken", {})
	kamikaze_cfg = d.get("kamikaze", {})
	spread_cfg = d.get("spread", {})
	burn_per_hit = float(d.get("burn", 0.0))
	targets_weakest = bool(d.get("targets_weakest", false))
	presence_shift = int(d.get("presence_shift", 0))
	summon_cfg = d.get("summon", {})
	shoots = String(d.get("shoots", ""))
	shoot_payload = d.get("payload", {})
	troops_only = bool(d.get("troops_only", false))
	dodge_cfg = d.get("dodge", {})
	footprint = d.get("footprint", [1, 1])
	is_b = String(d.get("type", "troop")) == "building"
	ground_speed = speed
	ground_reach = reach
	deploy_timer = DEPLOY_DELAY
	state = S.IDLE if stationary else S.APPROACH
	z_index = 5


func is_building() -> bool:
	return is_b or stationary


func is_tower() -> bool:
	return false


func is_airborne() -> bool:
	return flying


func is_alive_unit() -> bool:
	return not dead and hp > 0.0


func get_radius_t() -> float:
	return radius_t


# ------------------------------------------------------------------- primitives

func apply_impulse(dir: Vector2, tiles: float, duration: float) -> void:
	if is_b:
		return
	# buildings are planted: shoves do nothing to them
	if dead or duration <= 0.0 or is_b:
		return
	knock_vel = dir.normalized() * (tiles * arena.TILE / duration)
	knock_time = duration
	state = S.SLIDING
	stunned = 0.0
	atk_cd = maxf(atk_cd, duration)
	if not roll_cfg.is_empty():
		roll_level = 0
		roll_timer = 0.0
		speed = ground_speed


## Only one status can be active; the newest one replaces whatever was there.
func clear_status() -> void:
	status = Status.NONE
	slow_amount = 0.0
	slow_time = 0.0
	burn_stack = 0.0
	burn_ticks = 0
	burn_timer = 0.0


func slow(amount: float, seconds: float) -> void:
	if dead or amount <= 0.0:
		return
	if status != Status.SLOW:
		burn_stack = 0.0
		burn_ticks = 0
		burn_timer = 0.0
	status = Status.SLOW
	slow_amount = amount
	slow_time = maxf(slow_time, seconds)


## Burn: a stack that eats 30 % of itself per second. Four seconds without a
## fresh application and the whole thing goes out.
func apply_burn(amount: float, max_ticks: int = 4) -> void:
	if dead or amount <= 0.0:
		return
	if status != Status.BURN:
		slow_amount = 0.0
		slow_time = 0.0
		burn_timer = 1.0
	status = Status.BURN
	burn_stack += amount
	burn_ticks = 0
	burn_max_ticks = maxi(max_ticks, 1)


func catch_projectile() -> void:
	has_projectile = false
	atk_cd = 0.0
	if not boom_cfg.is_empty():
		throw_cd = cooldown_per_tile * throw_dist


func _physics_process(delta: float) -> void:
	if dead:
		return
	moved_this_frame = false
	clock += delta
	age += delta
	if hurt_frames > 0:
		hurt_frames -= 1
	if attack_stretch > 0.0:
		attack_stretch = maxf(0.0, attack_stretch - delta)
	flash = maxf(0.0, flash - delta * 5.0)
	if dodging:
		_tick_dodge(delta)
		queue_redraw()
		return
	if lifetime > 0.0:
		# Clash-Royale style decay: a building bleeds its whole HP bar away over
		# its lifetime, so it always dies on the timer unless something kills it
		# sooner. The rate is max_hp / lifetime per second.
		if is_building():
			hp = maxf(0.0, hp - max_hp / lifetime * delta)
			if hp <= 0.0:
				_die()
				return
		if age >= lifetime:
			_die()
			return
	if arena.match_over:
		queue_redraw()
		return
	if deploy_timer > 0.0:
		deploy_timer = maxf(0.0, deploy_timer - delta)
		queue_redraw()
		return

	if stunned > 0.0:
		stunned = maxf(0.0, stunned - delta)
		# a stunned unit can still be carried by an impulse (boulder knockback)
		if knock_time > 0.0:
			knock_time = maxf(0.0, knock_time - delta)
			position += knock_vel * delta
			if knock_time <= 0.0:
				knock_vel = Vector2.ZERO
		if stunned <= 0.0:
			if kind == "dragon" and hp <= max_hp * 0.5 and hp > 0.0:
				_take_off()
			state = S.IDLE if stationary else S.APPROACH
		queue_redraw()
		return

	if knock_time > 0.0:
		knock_time = maxf(0.0, knock_time - delta)
		position += knock_vel * delta
		if knock_time <= 0.0:
			knock_vel = Vector2.ZERO
			state = S.IDLE if stationary else S.APPROACH
		queue_redraw()
		return

	atk_cd = maxf(0.0, atk_cd - delta)
	throw_cd = maxf(0.0, throw_cd - delta)

	if burn_pulse > 0.0:
		burn_pulse = maxf(0.0, burn_pulse - delta * 1.7)
	if status == Status.BURN:
		burn_timer -= delta
		if burn_timer <= 0.0:
			burn_timer += 1.0
			var tick_dmg := floorf(burn_stack * BURN_RATE)
			if tick_dmg <= 0.0:
				clear_status()
			else:
				burn_stack = maxf(0.0, burn_stack - tick_dmg)
				burn_ticks += 1
				burn_pulse = 1.0
				take_damage(tick_dmg, position)
				if dead or burn_ticks >= burn_max_ticks or burn_stack <= 0.0:
					clear_status()
	elif status == Status.SLOW:
		slow_time = maxf(0.0, slow_time - delta)
		if slow_time <= 0.0:
			clear_status()

	if not summon_cfg.is_empty():
		_tick_summon(delta)

	# a balled-up hedgehog holds its ground while anything is inside thorn reach;
	# once nothing is, it uncurls and walks again
	if not curl_cfg.is_empty() and curled:
		if _enemy_within(float(curl_cfg["thorn_range"])) == null:
			curled = false
		else:
			state = S.IDLE
			queue_redraw()
			return

	if kind == "dragon" and not flying and hp <= max_hp * 0.5 and hp > 0.0:
		_take_off()

	# a turned alchemist only has eyes for structures; _acquire enforces it, so
	# the nearest tower *or* building is what he charges

	if target == null or not _target_valid(target):
		target = _acquire()
	elif atk_cd <= 0.0 and targets_weakest:
		target = _acquire()
	elif atk_cd <= 0.0:
		var cand: Node = _acquire()
		if cand != null and cand.get_instance_id() != target.get_instance_id():
			var d_new: float = arena.tiles_between(position, cand.position)
			var d_old: float = arena.tiles_between(position, target.position)
			if d_new < d_old - 0.3:
				target = cand

	if target == null and not stationary:
		# nothing worth shooting: advance on the nearest enemy tower rather than
		# standing in the open waiting for someone to walk into range
		target = arena.nearest_enemy_tower(team, position)
	if target == null:
		state = S.IDLE if stationary else S.APPROACH
		queue_redraw()
		return

	var gap: float = arena.gap_between(position, target.position, radius_t, float(target.get_radius_t()))
	if not kamikaze_cfg.is_empty() and airborne:
		# airborne: it flies at whatever it picked and bursts on contact
		if gap <= reach:
			_burst()
			return
		state = S.APPROACH
		_move(delta)
		queue_redraw()
		return
	if phase2:
		if gap <= 0.35:
			_explode()
			return
		_move(delta)
		queue_redraw()
		return
	if stationary:
		state = S.IDLE
		queue_redraw()
		return
	if not curl_cfg.is_empty() and not curled and gap <= reach:
		# a hedgehog has no jab: getting into reach is the cue to ball up
		_curl()
		queue_redraw()
		return
	if gap <= reach:
		state = S.ATTACK
		_attack()
	elif not boom_cfg.is_empty() and has_projectile:
		state = S.IDLE
	else:
		state = S.APPROACH
		_move(delta)
		_tick_roll(delta)
	queue_redraw()


func _move(delta: float) -> void:
	var goal: Vector2 = target.position
	var wp := goal
	if not flying:
		wp = arena.route_point(position, goal)
	var dir := wp - position
	if dir.length() < 1.0:
		dir = goal - position
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	if absf(dir.x) > 0.05:
		facing = signf(dir.x)
	var spd := speed * (1.0 - (slow_amount if status == Status.SLOW else 0.0))
	position += dir * spd * arena.TILE * delta
	moved_this_frame = true


func _tick_roll(delta: float) -> void:
	if roll_cfg.is_empty():
		return
	if not moved_this_frame:
		roll_timer = 0.0
		return
	roll_timer += delta
	var max_level := int(roll_cfg["max_level"])
	if roll_level < max_level and roll_timer >= float(roll_cfg["interval"]):
		roll_timer = 0.0
		roll_level += 1
		speed = ground_speed * pow(float(roll_cfg["speed_mult"]), float(roll_level))
	if roll_level >= max_level:
		trail_t -= delta
		if trail_t <= 0.0:
			trail_t = 0.11
			arena.spawn_trail(position, facing, team)


func _attack() -> void:
	if atk_cd > 0.0 or dmg <= 0.0:
		return
	if not boom_cfg.is_empty():
		_attack_fu()
		return
	if not chicken_cfg.is_empty():
		_attack_chicken()
		return
	if not spread_cfg.is_empty():
		_attack_spread()
		return
	if shoots != "":
		_mark_attack()
		atk_cd = interval
		arena.spawn_projectile(position, target.position, team, dmg, 0.0, shoots,
			get_instance_id(), "bolt", false, self, 950.0, target, shoot_payload)
		return
	var dist: float = arena.tiles_between(position, target.position)
	atk_cd = interval + cooldown_per_tile * dist
	if absf(target.position.x - position.x) > 1.0:
		facing = signf(target.position.x - position.x)
	var hit_dmg := dmg
	if not roll_cfg.is_empty() and roll_level > 0:
		hit_dmg = dmg * (1.0 + float(roll_cfg["damage_bonus"]) * float(roll_level))
		roll_level = 0
		roll_timer = 0.0
		speed = ground_speed
	if kind == "dragon" and flying:
		arena.dragon_breath(target.position, 1.8, hit_dmg, team)
		return
	_mark_attack()
	if splash > 0.0:
		arena.reserve_damage(get_instance_id(), target, hit_dmg)
		arena.spawn_projectile(position, target.position, team, hit_dmg, splash, kind, get_instance_id())
	else:
		if target.has_method("take_damage"):
			arena.reserve_damage(get_instance_id(), target, hit_dmg)
			target.take_damage(hit_dmg, position, self)
			arena.release_reservation(get_instance_id())
	if not dodge_cfg.is_empty() and not dodging:
		swipes += 1
		if swipes >= int(dodge_cfg["after_hits"]):
			_begin_dodge()


## Burn tint walks red → orange → yellow across its ticks; the tick that ends
## the burn flashes white.
static func burn_color(ticks: int, max_ticks: int) -> Color:
	if max_ticks <= 1:
		return Color(1, 1, 1)
	if ticks >= max_ticks - 1:
		return Color(1.0, 1.0, 1.0)
	var f := clampf(float(ticks) / float(max_ticks - 1), 0.0, 1.0)
	var red := Color(0.95, 0.18, 0.12)
	var orange := Color(1.0, 0.55, 0.12)
	var yellow := Color(1.0, 0.92, 0.3)
	return red.lerp(orange, f * 2.0) if f < 0.5 else orange.lerp(yellow, (f - 0.5) * 2.0)


## Penny's fade: she vanishes (invincible + untargetable), backs off half a tile
## and steps a quarter circle around whoever she was hitting. The first strafe
## turns toward the outside of the board; after that she keeps turning the same
## way, so the fight drifts rather than doubling back.
func _begin_dodge() -> void:
	if target == null or not is_instance_valid(target):
		return
	swipes = 0
	dodging = true
	untargetable = true
	invincible = true
	dodge_t = 0.0
	atk_cd = 0.0
	dodge_center = target.position
	dodge_start_r = position.distance_to(dodge_center)
	dodge_radius = dodge_start_r + float(dodge_cfg["back"]) * arena.TILE
	dodge_angle0 = (position - dodge_center).angle()
	if not dodge_picked:
		dodge_picked = true
		var sweep := deg_to_rad(float(dodge_cfg["sweep_deg"]))
		var outer: Vector2 = arena.board_rect().get_center()
		var plus: Vector2 = dodge_center + Vector2(cos(dodge_angle0 + sweep), sin(dodge_angle0 + sweep)) * dodge_radius
		var minus: Vector2 = dodge_center + Vector2(cos(dodge_angle0 - sweep), sin(dodge_angle0 - sweep)) * dodge_radius
		dodge_sign = 1.0 if plus.distance_to(outer) > minus.distance_to(outer) else -1.0


func _tick_dodge(delta: float) -> void:
	var total: float = maxf(0.1, float(dodge_cfg["time"]))
	dodge_t += delta
	if target != null and is_instance_valid(target) and not target.dead:
		dodge_center = target.position
	var back_time: float = total * 0.3
	if dodge_t <= back_time:
		var f: float = dodge_t / back_time
		var r: float = lerpf(dodge_start_r, dodge_radius, ease(f, 0.4))
		position = dodge_center + Vector2(cos(dodge_angle0), sin(dodge_angle0)) * r
	else:
		var f: float = clampf((dodge_t - back_time) / (total - back_time), 0.0, 1.0)
		var ang: float = dodge_angle0 + dodge_sign * deg_to_rad(float(dodge_cfg["sweep_deg"])) * ease(f, 0.6)
		position = dodge_center + Vector2(cos(ang), sin(ang)) * dodge_radius
		var dir := position - dodge_center
		if absf(dir.x) > 1.0:
			facing = signf(dir.x)
	if dodge_t >= total:
		dodging = false
		untargetable = false
		invincible = false
		atk_cd = 0.0


## Primal Aphid: a shotgun cone, five pellets spread across cone_deg, each flying
## its own full length whether or not anything is in front of it. The pellets
## carry further than the aphid's own 2 tile stance, so they reach into a lane it
## never has to enter.
func _attack_spread() -> void:
	if target == null:
		return
	_mark_attack()
	atk_cd = interval
	var dir: Vector2 = target.position - position
	if dir.length() < 1.0:
		dir = Vector2(facing, 0.0)
	var base_angle := dir.angle()
	var n: int = maxi(1, int(spread_cfg["count"]))
	var half := deg_to_rad(float(spread_cfg["cone_deg"])) * 0.5
	var reach_px: float = float(spread_cfg["reach"]) * arena.TILE
	for i in n:
		var f := 0.0
		if n > 1:
			f = (float(i) / float(n - 1)) * 2.0 - 1.0
		var ang: float = base_angle + half * f
		var to: Vector2 = position + Vector2(cos(ang), sin(ang)) * reach_px
		arena.spawn_projectile(position, to, team, float(spread_cfg["dmg"]), 0.0, "aphid",
			get_instance_id(), "bolt", false, self, float(spread_cfg["speed"]), null,
			{"first_hit": true})


## Hot Chicken's ground phase: peck fireballs. Three hits on one target and it
## takes off — the ram below does the rest.
func _attack_chicken() -> void:
	if target == null or atk_cd > 0.0:
		return
	_mark_attack()
	atk_cd = interval
	var id: int = target.get_instance_id()
	if id == chicken_target:
		chicken_hits += 1
	else:
		chicken_target = id
		chicken_hits = 1
	arena.spawn_projectile(position, target.position, team, dmg, 0.0, "chicken",
		get_instance_id(), "bolt", false, self, float(chicken_cfg["fire_speed"]), target,
		{"burn": burn_per_hit})
	if chicken_hits >= int(chicken_cfg["hits_to_fly"]):
		airborne = true
		flying = true
		reach = float(chicken_cfg["burst_reach"])
		atk_cd = 0.0


## Hot Chicken's air phase: fly into the target and burst, killing itself.
func _burst() -> void:
	if dead:
		return
	arena.spawn_splash_burst(position, float(kamikaze_cfg["radius"]), float(kamikaze_cfg["dmg"]),
		team, Color(1.0, 0.62, 0.25))
	_die()


func _attack_fu() -> void:
	var gap: float = arena.gap_between(position, target.position, radius_t, float(target.get_radius_t()))
	var dist: float = arena.tiles_between(position, target.position)
	if absf(target.position.x - position.x) > 0.6:
		facing = signf(target.position.x - position.x)
	var target_airborne: bool = target.get("flying") == true
	if gap <= float(boom_cfg["melee_range"]) and not target_airborne:
		# melee combo: quick jabs ending in a kick that re-opens throwing range
		_mark_attack()
		atk_cd = float(boom_cfg["melee_interval"])
		if target.has_method("take_damage"):
			target.take_damage(float(boom_cfg["melee_dmg"]), position)
		combo_hits += 1
		if combo_hits >= int(boom_cfg["combo_hits"]):
			combo_hits = 0
			_kick()
		return
	if has_projectile or throw_cd > 0.0:
		return
	has_projectile = true
	throw_dist = dist
	_mark_attack()
	atk_cd = 999.0
	var speed_px: float = float(boom_cfg["throw_speed_tiles"]) * arena.TILE
	arena.spawn_projectile(position, target.position, team, dmg, 0.0, "boomerang",
		get_instance_id(), "return", false, self, speed_px, target)


## Nearest enemy whose gap to this unit's *edge* is inside range_t. Edge to edge
## on purpose: a ranged attacker the hedgehog has walked up on still counts.
func _enemy_within(range_t: float) -> Node:
	var best: Node = null
	var best_d := INF
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = arena.gap_between(position, e.position, radius_t, float(e.get_radius_t()))
		if d <= range_t and d < best_d:
			best = e
			best_d = d
	return best


## The hedgehog's reach attack: ball up, quills out at everything inside thorn
## reach, and a short shove — short enough that nothing leaves the thorns, which
## is where the reflection happens. It never opens up again on its own; that is
## the uncurl above, and it only happens when the thorns can reach nothing.
func _curl() -> void:
	curled = true
	state = S.IDLE
	target = null
	atk_cd = 0.0
	var burst := float(curl_cfg["burst_dmg"])
	var tr := float(curl_cfg["thorn_range"])
	var push := float(curl_cfg["push"])
	for e in arena.enemy_entities(team).duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		var gap: float = arena.gap_between(position, e.position, radius_t, float(e.get_radius_t()))
		if gap > tr:
			continue
		if e.has_method("take_damage"):
			e.take_damage(burst, position, self)
		if e.has_method("apply_impulse"):
			# never shove a unit out of thorn reach
			var shove: float = minf(push, maxf(tr - gap - 0.1, 0.0))
			if shove > 0.02:
				var d: Vector2 = e.position - position
				if d.length() < 0.01:
					d = Vector2(facing, 1.0)
				e.apply_impulse(d.normalized(), shove, float(curl_cfg["push_time"]))


func _mark_attack() -> void:
	if target == null or not is_instance_valid(target):
		return
	attack_dir = (target.position - position)
	if attack_dir.length() > 0.01:
		attack_dir = attack_dir.normalized()
	else:
		attack_dir = Vector2.RIGHT
	attack_stretch = ATTACK_STRETCH


func _kick() -> void:
	if target == null or not is_instance_valid(target):
		return
	var dir: Vector2 = target.position - position
	if dir.length() < 0.01:
		dir = Vector2(facing, 0.0)
	dir = dir.normalized()
	if target.has_method("take_damage"):
		target.take_damage(float(boom_cfg["kick_dmg"]), position)
	if target.has_method("apply_impulse"):
		target.apply_impulse(dir, float(boom_cfg["kick_push"]), 0.25)
	apply_impulse(-dir, float(boom_cfg["self_push"]), 0.28)


func _take_off() -> void:
	flying = true
	speed = ground_speed * 1.9
	reach = 2.6
	target = null
	atk_cd = 0.6
	arena.banner_flash("The chains break — the dragon takes to the skies!")


func _target_valid(t: Node) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	if t.get("dead") == true:
		return false
	if int(t.get("team")) == team:
		return false
	if t.get("flying") == true and not hits_air:
		return false
	return true


func _tick_summon(delta: float) -> void:
	summon_cd = maxf(0.0, summon_cd - delta)
	if summon_cd > 0.0:
		return
	var rng_t := float(summon_cfg["range"])
	var near := false
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		if arena.tiles_between(position, e.position) <= rng_t:
			near = true
			break
	if not near:
		return
	summon_cd = float(summon_cfg["cooldown"])
	var kind_s := String(summon_cfg["unit"])
	var closest: Node = null
	var best := INF
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		var d2: float = arena.tiles_between(position, e.position)
		if d2 <= rng_t and d2 < best:
			best = d2
			closest = e
	var dir := Vector2(-1.0 if team == 0 else 1.0, 0.0)
	if closest != null:
		var raw: Vector2 = closest.position - position
		if raw.length() > 0.001:
			var step := TAU / 16.0
			var snapped := roundf(raw.angle() / step) * step
			dir = Vector2(cos(snapped), sin(snapped))
	var at: Vector2 = position + dir * 1.3 * float(arena.TILE)
	arena.spawn_troop(kind_s, team, at, true)
	arena.shake(2.0)


func _acquire() -> Node:
	if targets_weakest:
		var weakest: Node = null
		var worst_hp := INF
		for e in arena.enemy_entities(team):
			if not is_instance_valid(e) or e.dead:
				continue
			if e.get("flying") == true and not hits_air:
				continue
			if arena.is_doomed(e):
				continue
			if buildings_only and not e.is_building():
				continue
			if troops_only and (e.is_building() or e.is_tower()):
				continue
			if phase2 and not (e.is_building() or e.is_tower()):
				continue
			var dw: float = arena.tiles_between(position, e.position)
			if dw > aggro:
				continue
			var ehp := float(e.get("hp"))
			if ehp < worst_hp:
				worst_hp = ehp
				weakest = e
		return weakest
	var best: Node = null
	var best_d := INF
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		if e.get("flying") == true and not hits_air:
			continue
		if arena.is_doomed(e):
			continue
		if buildings_only and not e.is_building():
			continue
		if troops_only and (e.is_building() or e.is_tower()):
			continue
		if phase2 and not (e.is_building() or e.is_tower()):
			continue
		if kind == "dragon" and flying and not e.is_building():
			continue
		var d: float = arena.tiles_between(position, e.position)
		if not e.is_tower():
			var limit: float = aggro
			if e.is_building():
				limit = maxf(aggro, 7.5)
			if d > limit:
				continue
		if d < best_d - 0.0001:
			best = e
			best_d = d
		elif absf(d - best_d) <= 0.0001 and best != null and e.get_instance_id() < best.get_instance_id():
			best = e
	return best


func take_damage(amount: float, from: Vector2, attacker: Node = null) -> void:
	if dead or amount <= 0.0 or invincible:
		return
	var taken := amount
	if curled and not curl_cfg.is_empty():
		taken *= float(curl_cfg["damage_mult"])
	last_from = from
	if attacker != null:
		last_attacker = attacker
	hp -= taken
	flash = 0.5
	hurt_frames = 2
	if arena.show_damage():
		var tint := Color(1.0, 0.45, 0.45) if hp <= 0.0 else (Color(1.0, 0.85, 0.5) if taken >= 20.0 else Color(0.95, 0.95, 1.0))
		arena.spawn_damage_text(position + Vector2(0.0, -radius_t * arena.TILE - 8.0), taken, tint)
	# quills: anything that hits the ball from inside thorn reach gets poked, so
	# a ranged attacker that has been closed on is punished exactly like a melee
	# one. The guard stops two hedgehogs poking each other forever.
	if curled and not curl_cfg.is_empty() and arena.damage_guard == 0:
		var src_node: Node = attacker
		var src_pos := from
		if src_node != null and is_instance_valid(src_node):
			src_pos = src_node.position
		var src_r := 0.0
		if src_node != null and src_node.has_method("get_radius_t"):
			src_r = float(src_node.get_radius_t())
		if arena.gap_between(position, src_pos, radius_t, src_r) <= float(curl_cfg["thorn_range"]):
			if src_node != null and is_instance_valid(src_node) and src_node.has_method("take_damage"):
				arena.damage_guard += 1
				src_node.take_damage(float(curl_cfg["thorn_dmg"]), position, self)
				arena.damage_guard = maxi(0, arena.damage_guard - 1)
	if kind == "alchemist" and not phase2 and hp > 0.0 and hp <= max_hp * 0.5:
		_enter_phase2()
	if hp <= 0.0:
		_die()


func hit_by_hero(amount: float, stun_seconds: float) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.8
	hurt_frames = 6
	if kind == "dragon":
		flying = false
		speed = ground_speed
		reach = ground_reach
		stunned = stun_seconds
		target = null
		state = S.STUNNED
		atk_cd = 1.0
	if hp <= 0.0:
		_die()


func _enter_phase2() -> void:
	phase2 = true
	team = 1 - team
	speed *= 2.4
	aggro = 99.0
	atk_cd = 0.0
	target = null
	arena.banner_flash("%s turns on its caster!" % DDCard.pretty("alchemist"))


func _explode() -> void:
	arena.spawn_splash_burst(position, 2.0, 100.0, team, Color(0.55, 0.95, 0.4))
	_die()


func _die() -> void:
	if dead:
		return
	dead = true
	# death blast (snowman): damage + slow around the corpse
	var da: Dictionary = DDCard.get_card(kind).get("death_aoe", {})
	if not da.is_empty():
		arena.death_aoe(position, float(da["radius"]), float(da["dmg"]),
			float(da["slow"]), float(da["slow_time"]), team)
	# zombies raise whatever they kill, on their own side — buildings are not
	# people, they do not get back up
	if kind != "zombie" and not is_building() and last_attacker != null and is_instance_valid(last_attacker):
		if String(last_attacker.get("kind")) == "zombie":
			var risen = arena.spawn_troop("zombie", int(last_attacker.team), position, true)
			if risen != null and is_instance_valid(risen):
				risen.deploy_timer = 0.0
			arena.banner_flash("Another one rises...")
	if kind == "idol":
		var src := last_from
		if last_attacker != null and is_instance_valid(last_attacker):
			src = last_attacker.position
		var dir := Vector2(0, -1)
		if src != Vector2.INF:
			dir = src - position
			if dir.length() < 0.01:
				dir = Vector2(0, -1)
			dir = dir.normalized()
		arena.spawn_boulder(position, dir, team)
	# mini confetti in the card's accent and the owner's colour
	arena.spawn_unit_confetti(position, kind, team, radius_t)
	arena.unregister(self)
	queue_free()


func _draw() -> void:
	var px: float = radius_t * arena.TILE
	var lift := 0.0
	if flying:
		lift = 18.0 + sin(clock * 2.2) * 3.0
		draw_set_transform(Vector2(0, px * 0.55), 0.0, Vector2(1.0, 0.42))
		draw_circle(Vector2.ZERO, px * 0.95, Color(0.05, 0.06, 0.1, 0.32))
	# squash & stretch: drop-in, landing squash, attack lunge
	var sx := 1.0
	var sy := 1.0
	var drop := 0.0
	if deploy_timer > 0.0:
		var e := DEPLOY_DELAY - deploy_timer
		if e < FALL_TIME:
			var ff := e / FALL_TIME
			sy = lerpf(2.6, 1.0, ff)
			sx = lerpf(0.32, 1.0, ff)
			drop = -92.0 * (1.0 - ff * ff)
		else:
			var f2 := clampf((e - FALL_TIME) / SQUASH_TIME, 0.0, 1.0)
			var b := sin(f2 * PI) * 0.32
			sy = 1.0 - b
			sx = 1.0 + b * 0.7
	elif attack_stretch > 0.0:
		var a := attack_stretch / ATTACK_STRETCH
		if absf(attack_dir.x) >= absf(attack_dir.y):
			sx = 1.0 + 0.2 * a
			sy = 1.0 - 0.1 * a
		else:
			sy = 1.0 + 0.2 * a
			sx = 1.0 - 0.1 * a
	draw_set_transform(Vector2(0, -lift + drop), 0.0, Vector2(sx, sy))
	# every unit is outlined in a darker shade of its own team's colour
	var ink: Color = arena.team_ink(int(team))
	if kind == "hedgehog":
		DDArt.hedgehog(self, px, facing, clock, curled, ink)
	elif kind == "hawk":
		DDArt.bird(self, px, facing, clock, bird_lead, ink)
	elif kind == "dragon":
		DDArt.dragon(self, px, facing, clock, flying, 0.0, ink)
	else:
		DDArt.creature(self, kind, px, facing, clock, 0.0, phase2, ink, flying)
	if status == Status.SLOW:
		draw_circle(Vector2.ZERO, px * 1.15, Color(0.18, 0.32, 0.85, 0.45))
		draw_arc(Vector2.ZERO, px * 1.15, 0.0, TAU, 20, Color(0.35, 0.55, 1.0, 0.6), 2.0, true)
	elif status == Status.BURN:
		var c := burn_color(burn_ticks, burn_max_ticks)
		var pulse := 0.2 + 0.5 * burn_pulse
		draw_circle(Vector2.ZERO, px * (1.08 + 0.18 * burn_pulse), Color(c.r, c.g, c.b, pulse))
		draw_arc(Vector2.ZERO, px * (1.08 + 0.18 * burn_pulse), 0.0, TAU, 20,
			Color(c.r, c.g, c.b, 0.5 + 0.4 * burn_pulse), 2.0, true)
	if hurt_frames > 0:
		draw_circle(Vector2.ZERO, px * 1.0, Color(1.0, 0.55, 0.72, 0.62))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not roll_cfg.is_empty() and roll_level > 0:
		var lines := roll_level + 1
		for i in lines:
			var y := -px * 0.55 + float(i) * px * 0.55
			var length := px * (1.2 + 0.45 * float(i))
			var col := Color(1, 1, 1, 0.45) if roll_level == 1 else Color(1, 0.85, 0.55, 0.6)
			draw_line(Vector2(-facing * px * 0.9, y), Vector2(-facing * (px * 0.9 + length), y), col, 2.0, true)
		if roll_level >= 2:
			draw_arc(Vector2.ZERO, px * 1.25, 0.0, TAU, 24, Color(1.0, 0.8, 0.45, 0.35), 2.0, true)
	if stunned > 0.0:
		for i in 3:
			var a := clock * 4.0 + float(i) * TAU / 3.0
			draw_circle(Vector2(cos(a), sin(a)) * px * 0.9 + Vector2(0, -px - 16.0 - lift), 3.0, Color(1.0, 0.9, 0.35))
	if hp < max_hp:
		var w: float = px * 2.2
		var y2: float = -px - 10.0 - lift
		draw_rect(Rect2(-w * 0.5, y2, w, 5.0), Color(0.08, 0.07, 0.1, 0.85), true)
		var frac := clampf(hp / max_hp, 0.0, 1.0)
		var col2 := Color(0.45, 0.9, 0.55) if team == 0 else Color(0.95, 0.45, 0.45)
		draw_rect(Rect2(-w * 0.5 + 1.0, y2 + 1.0, (w - 2.0) * frac, 3.0), col2, true)
